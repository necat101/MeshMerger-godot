# Godot MeshMerger Tool

**Version:** 1.0 (for Godot 4.x)  
**Author:** (necat101)
**Discord:** netcat7

A Godot Engine tool script (`MeshMerger.gd`) designed to merge descendant `MeshInstance3D` nodes into a single parent `MeshInstance3D`. This tool is particularly useful for optimizing scenes by reducing the number of draw calls. It intelligently handles multiple materials by creating separate surfaces in the merged mesh and also processes child meshes that themselves contain multiple surfaces.

## Overview

When working with complex 3D scenes in Godot, having many individual `MeshInstance3D` nodes can impact performance due to increased draw calls. This `MeshMerger` script provides an in-editor solution to combine multiple meshes into one, which can lead to significant performance improvements, especially for static geometry.

The script is attached to an empty `MeshInstance3D` node, which then becomes the parent and the recipient of the merged mesh. All `MeshInstance3D` nodes that are children or descendants of this parent node will be considered for merging.

## Features

* **Merge Multiple Meshes:** Combines all descendant `MeshInstance3D` nodes into the parent `MeshInstance3D` where the script is attached.
* **Multi-Material Handling:** Correctly preserves different materials by creating separate surfaces in the resulting `ArrayMesh`.
* **Multi-Surface Support:** Handles child meshes that already have multiple surfaces (e.g., imported models with different material assignments).
* **In-Editor Operation:** All merging operations are performed directly within the Godot editor using `@tool` script functionality.
* **Collision Shape Copying (Optional):** Can copy `CollisionShape3D` nodes from the original meshes to a designated parent node. This is useful for maintaining collision for the merged object.
* **Visibility Toggle:** Allows easy toggling of the visibility of the original child meshes in the editor.
* **Runtime Child Deletion (Optional):** Can automatically delete the original child meshes when the game starts to save memory.
* **Inspector Controls:** Provides simple buttons and toggles in the Inspector for merging, cleaning, and managing child visibility.

## How to Use

1.  **Add the Script:**
    * Create an empty `MeshInstance3D` node in your scene. This node will become the parent and will hold the final merged mesh.
    * Attach the `MeshMerger.gd` script to this `MeshInstance3D` node.

2.  **Arrange Hierarchy:**
    * Make all the `MeshInstance3D` nodes you want to merge children or descendants of the `MeshInstance3D` node with the `MeshMerger.gd` script.
    * **Example Hierarchy:**
        ```
        - MyMergedObject (MeshInstance3D with MeshMerger.gd)
            - MeshPart1 (MeshInstance3D)
            - MeshPart2 (MeshInstance3D)
            - GroupOfMeshes (Node3D)
                - MeshPart3 (MeshInstance3D)
                - MeshPart4 (MeshInstance3D)
        ```

3.  **Configure in Inspector:**
    * Select the `MeshInstance3D` node with the `MeshMerger.gd` script.
    * In the Inspector panel, you will find the script's properties.

4.  **Merge Meshes:**
    * Click the `Btn Merge Meshes` checkbox in the Inspector.
    * The script will process all descendant `MeshInstance3D` nodes, merge their geometry and materials, and assign the resulting `ArrayMesh` to the parent `MeshInstance3D`.
    * The original child meshes will be hidden by default after merging (this can be controlled).

5.  **Collision Handling (Optional):**
    * If you want to copy collision shapes:
        * Create an empty `Node3D` (or `StaticBody3D`, etc.) in your scene to act as the parent for the copied collision shapes.
        * In the `MeshMerger` script's Inspector properties, set the `Collision Parent Path` by selecting this newly created node.
        * When you merge meshes, any `CollisionShape3D` found under `StaticBody3D` children of the processed `MeshInstance3D` nodes will be duplicated and re-parented to your specified `Collision Parent`.

6.  **Clean Up (If Needed):**
    * Click the `Btn Clean Meshes` checkbox to remove the merged mesh from the parent, clear any copied collision shapes (if a `Collision Parent Path` is set), and make the original child meshes visible again.

## Inspector Properties

* **`Result Mesh` (Read-Only):** Displays the `ArrayMesh` resource created after merging. You cannot edit this directly.
* **`Collision Parent Path` (NodePath):**
    * Optional. Assign a `NodePath` to a `Node3D` in your scene.
    * If set, when meshes are merged, `CollisionShape3D`s from the original meshes (specifically those parented under `StaticBody3D`s) will be duplicated and added as children to this node.
* **`Btn Merge Meshes` (bool - Button):**
    * Click this checkbox to trigger the mesh merging process. It will automatically uncheck itself.
* **`Btn Clean Meshes` (bool - Button):**
    * Click this checkbox to clear the currently merged mesh, remove copied collision shapes, and make original children visible. It will automatically uncheck itself.
* **`Toggle Children Visibility` (bool):**
    * Controls the visibility of the original child `MeshInstance3D` nodes in the editor.
    * Default: `true` (children are visible before merging, hidden after).
    * You can use this to show/hide the original parts without affecting the merged result.
* **`Delete Child Meshes On Play` (bool):**
    * If `true`, the original child `MeshInstance3D` nodes will be queued for deletion (`queue_free()`) when the game starts (`_ready()` function).
    * This is useful for reducing node count and memory usage in the running game, as the merged mesh is self-contained.
    * Default: `false`.

## Collision Handling Details

* The script looks for a specific hierarchy to copy collision shapes:
    ```
    - OriginalMeshInstance3D
        - StaticBody3D
            - CollisionShape3D
    ```
* Only `CollisionShape3D` nodes found under a `StaticBody3D` child of a processed `MeshInstance3D` will be considered.
* The `global_transform` and `shape` of the `CollisionShape3D` are duplicated.
* **Important:** For static level collision, Godot's built-in "Mesh -> Create Trimesh Static Body" option (applied to the original imported scene or individual meshes *before* using this merger) is often a more robust and preferred method. This script's collision handling is a utility for convenience but may not cover all complex collision scenarios or types as effectively as Godot's dedicated tools.

## Important Notes & Considerations

* **Run in Editor Only:** The merging logic is designed to run exclusively in the Godot editor (`Engine.is_editor_hint()`). It will not attempt to merge meshes during gameplay.
* **Transformations:** Mesh data is transformed relative to the `MeshMerger` node's global transform. This means the merged mesh will appear correctly positioned based on the original positions of its constituent parts relative to the merger node.
* **Performance:** While merging meshes reduces draw calls, merging extremely complex or very numerous meshes can take time in the editor.
* **Undo/Redo:** The script itself does not implement custom undo/redo for the merge operation. Use Godot's scene undo/redo cautiously. Cleaning and re-merging is often the safest way to revert.
* **Pre-Merge Optimization:** For optimal results, consider merging meshes in your 3D modeling software (e.g., Blender) before importing them into Godot. This often gives more control and can lead to better-optimized geometry.
* **Static Geometry:** This tool is best suited for static geometry that doesn't need to be moved independently after merging.
* **Material Uniqueness:** The script uses the `Material` resource itself as the key for grouping surfaces. If you have multiple visually identical materials that are separate resources, they will result in separate surfaces. For true optimization, ensure identical materials are actually the *same* material resource.

## Potential Future Improvements

* Support for `Skeleton3D` and skinned meshes (currently not supported).
* More sophisticated options for collision generation (e.g., creating convex or trimesh collision shapes directly from the merged mesh).
* Option to merge into a `MultiMeshInstance3D` for certain use cases.
* Progress bar for very large merge operations.
