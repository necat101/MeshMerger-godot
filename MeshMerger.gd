# MeshMerger.gd
# A tool script to merge descendant MeshInstance3D nodes into this parent MeshInstance3D.
# Handles multiple materials by creating separate surfaces in the merged mesh.
# Also handles child meshes that themselves contain multiple surfaces.
# Attach this script to an empty MeshInstance3D node.
# Make the meshes you want to merge children/descendants of this node.
# Consider merging meshes in your modeling software before import for optimal results.
# For static level collision, using Godot's "Mesh -> Create Trimesh Static Body"
# on the original imported scene is often preferred over this script's collision handling.

@tool # Use @tool annotation for Godot 4+ to run in the editor
extends MeshInstance3D
class_name MeshMerger

# --- Exposed Variables ---

# The resulting merged mesh resource (read-only in inspector)
var result_mesh: ArrayMesh = null

# Optional: Path to a Node3D where copied collision shapes should be parented.
@export var collision_parent_path: NodePath
var collision_parent: Node = null # Initialize as null

# Button in the Inspector to trigger the merge process.
@export var btn_merge_meshes: bool = false: set = merge_meshes
# Button in the Inspector to clear the merged mesh and copied collisions.
@export var btn_clean_meshes: bool = false: set = clean_meshes

# Toggle visibility of the original child MeshInstance nodes in the editor.
@export var toggle_children_visibility: bool = true: set = set_toggle_children_visibility
# If true, the original child MeshInstance nodes will be deleted when the game runs.
@export var delete_child_meshes_on_play: bool = false: set = set_delete_child_meshes_on_play


func _enter_tree():
	# Attempt to get collision_parent when node enters tree in editor
	if Engine.is_editor_hint() and collision_parent_path:
		collision_parent = get_node_or_null(collision_parent_path)


# --- Merge Logic ---

# Triggered when the "Btn Merge Meshes" checkbox is clicked in the Inspector.
func merge_meshes(value):
	# Only run this logic in the Godot editor, not in the running game.
	if not Engine.is_editor_hint():
		return
	# Reset the button state visually
	btn_merge_meshes = false

	print("Starting mesh merge (Multi-Material & Multi-Surface)...")

	# Clear previous merge result if any
	if result_mesh:
		result_mesh.clear_surfaces()
		print("Cleared previous result mesh.")
	result_mesh = ArrayMesh.new() # Initialize the result mesh

	# Ensure collision_parent is up-to-date
	if collision_parent_path:
		collision_parent = get_node_or_null(collision_parent_path) # Re-fetch node
		if collision_parent:
			print("Found collision parent: ", collision_parent.name)
			clean_collisions() # Clean existing collisions before generating new ones
		else:
			print("WARNING: Collision parent path set, but node not found: ", collision_parent_path)

	# Dictionary to hold SurfaceTool instances, keyed by Material
	var material_surfaces: Dictionary = {}
	var merged_something = false

	# Call the recursive function to find and process all MeshInstance3D descendants
	merged_something = process_node_recursive(self, material_surfaces)

	if not merged_something:
		print("No descendant MeshInstance3D nodes found or processed.")
		self.mesh = null # Ensure mesh is cleared if nothing was merged
		material_surfaces.clear() # Clear the dictionary
		return

	# Commit surfaces from each SurfaceTool in the dictionary
	print("Committing merged surfaces...")
	var surface_index = 0
	for material in material_surfaces:
		var surface_tool: SurfaceTool = material_surfaces[material]
		print("Committing surface for material: ", material)
		surface_tool.index() # Ensure indices are generated if not already
		var mesh_data = surface_tool.commit_to_arrays() # Get data as arrays
		if mesh_data.is_empty():
			print("WARNING: Surface data is empty for material: ", material)
			continue

		# Add the committed surface data to the result ArrayMesh
		result_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_data)
		# Assign the correct material to the newly added surface
		if material: # Don't assign null material explicitly unless necessary
			result_mesh.surface_set_material(surface_index, material)
		surface_index += 1

	material_surfaces.clear() # Clean up the dictionary

	if result_mesh.get_surface_count() == 0:
		print("ERROR: Failed to commit any surfaces to the merged mesh.")
		self.mesh = null
		return

	# Assign the resulting multi-surface mesh to this node
	self.mesh = result_mesh
	# No need for material_override as materials are set per-surface
	self.material_override = null

	# Hide the original children after merging
	set_toggle_children_visibility(false)
	print("Mesh merge complete. Original children hidden.")


# --- Recursive Processing Function ---
# Finds MeshInstance3D nodes recursively and appends their data (from ALL surfaces)
# to the correct SurfaceTool based on material.
# Returns true if at least one mesh surface was processed.
func process_node_recursive(node: Node, material_surfaces: Dictionary) -> bool:
	var processed_any = false
	for child in node.get_children():
		# Skip the node containing this script itself
		if child == self:
			continue

		if child is MeshInstance3D:
			var child_mesh_instance: MeshInstance3D = child
			var child_mesh: Mesh = child_mesh_instance.mesh

			if child_mesh and child_mesh.get_surface_count() > 0:
				# --- Loop through ALL surfaces within this mesh ---
				for surface_idx in range(child_mesh.get_surface_count()):
					# Get the active material for the CURRENT surface index
					var mat = child_mesh_instance.get_active_material(surface_idx)

					print("Processing mesh: ", child_mesh_instance.get_path(), " Surface: ", surface_idx, " with material: ", mat)

					# Get or create the SurfaceTool for this material
					var surface_tool: SurfaceTool
					if not material_surfaces.has(mat):
						print("Creating new SurfaceTool for material: ", mat)
						surface_tool = SurfaceTool.new()
						surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
						material_surfaces[mat] = surface_tool
					else:
						surface_tool = material_surfaces[mat]

					# Calculate the transform relative to the node this script is on (self)
					var relative_transform = self.global_transform.affine_inverse() * child_mesh_instance.global_transform
					# Append mesh data FROM THE CURRENT SURFACE INDEX to the correct SurfaceTool
					surface_tool.append_from(child_mesh, surface_idx, relative_transform)
					processed_any = true # Mark true if any surface is processed

				# Generate collision shapes (usually done once per MeshInstance, not per surface)
				# Consider if this should be outside the surface loop if needed
				generate_collisions(child_mesh_instance)

			elif child_mesh:
				print("Skipping mesh with no surfaces: ", child_mesh_instance.name)
			else:
				print("Skipping child with no mesh: ", child_mesh_instance.name)

		# Recurse into children of this child, even if it wasn't a MeshInstance itself
		if child.get_child_count() > 0:
			if process_node_recursive(child, material_surfaces):
				processed_any = true # Mark as processed if any descendant was processed

	return processed_any


# --- Clean Logic ---

# Triggered when the "Btn Clean Meshes" checkbox is clicked in the Inspector.
func clean_meshes(value):
	# Only run this logic in the Godot editor
	if not Engine.is_editor_hint():
		return
	# Reset the button state visually
	btn_clean_meshes = false

	print("Cleaning merged mesh and collisions...")
	# Remove the mesh from this node
	self.mesh = null
	result_mesh = null
	# No single material override to clear

	# Clean any generated collision shapes
	# Ensure collision_parent is up-to-date
	if collision_parent_path:
		collision_parent = get_node_or_null(collision_parent_path) # Re-fetch node
	clean_collisions() # Call clean even if path was null, in case parent reference exists

	# Make original children visible again
	set_toggle_children_visibility(true)
	print("Clean complete. Original children visible.")


# --- Helper Functions ---

# Copies collision shapes from children of the processed node.
# Assumes a structure like: MeshInstance -> StaticBody -> CollisionShape
# For static levels, prefer "Mesh -> Create Trimesh Static Body".
func generate_collisions(node: MeshInstance3D):
	# Only proceed if a valid collision parent node is set and exists in the tree
	if not collision_parent or not is_instance_valid(collision_parent):
		return
	if not collision_parent.is_inside_tree():
		print("WARNING: Collision parent is not inside the tree. Cannot add children.")
		return

	# Look for StaticBody children of the MeshInstance
	for child in node.get_children():
		if child is StaticBody3D:
			var static_body: StaticBody3D = child
			# Look for CollisionShape children of the StaticBody
			for grandchild in static_body.get_children():
				if grandchild is CollisionShape3D:
					var original_col_shape: CollisionShape3D = grandchild

					if not original_col_shape.shape:
						print("WARNING: Skipping collision shape with null shape resource.")
						continue

					var new_col := CollisionShape3D.new()
					new_col.global_transform = original_col_shape.global_transform
					new_col.shape = original_col_shape.shape.duplicate(true)

					collision_parent.add_child.call_deferred(new_col)

					var edited_root = get_tree().edited_scene_root
					if edited_root:
						new_col.owner = edited_root
						print("Copied collision shape to: ", collision_parent.name)
					else:
						print("WARNING: Could not get edited_scene_root. Owner not set for new collision shape.")


# Removes all children from the designated collision parent node.
func clean_collisions():
	if not collision_parent or not is_instance_valid(collision_parent):
		return

	if collision_parent.get_child_count() > 0:
		print("Cleaning collisions from: ", collision_parent.name)
		for i in range(collision_parent.get_child_count() - 1, -1, -1):
			var child = collision_parent.get_child(i)
			if is_instance_valid(child):
				print("Removing collision child: ", child.name)
				collision_parent.remove_child.call_deferred(child)
				child.queue_free()


# --- Setters for Exported Variables ---

func set_toggle_children_visibility(value):
	toggle_children_visibility = value
	for node in get_children():
		node.visible = value

func set_delete_child_meshes_on_play(value):
	delete_child_meshes_on_play = value


# --- Runtime Logic ---

func _ready():
	if delete_child_meshes_on_play and not Engine.is_editor_hint():
		print("Deleting original child meshes at runtime...")
		for node in get_children():
			if node is Node3D:
				print("Queueing free child instance root: ", node.name)
				node.queue_free()
				break
