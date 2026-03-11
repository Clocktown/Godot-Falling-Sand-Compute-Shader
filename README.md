# Godot Compute-Shader Image to TextureRect Example
Many resources about how to use compute shaders in Godot 4.6 are insufficient if what you want to do is have compute shaders output/modify something on the GPU every frame (or physics frame) and have that same resource available to regular nodes or the main renderer.

For example, the heightmap example uses a local rendering device and *downloads the texture to the CPU* just to *reupload that texture to the GPU again*.

This is fine if it happens occasionally. It is not fine if we are talking about a simulation that modifies large images or particle data that we want to access in our normal rendering outside of the `RenderingDevice` API.

The project I have provided here contains a toy example that shows how to do this:
* Uses `RenderingServer.get_rendering_device()` so that Resources allocated can be accessed by nodes
* Uses `Texture2DRD` to bind a texture created on the `RenderingDevice` to a standard `TextureRect` node
* Has example code that handles a change in width/height of the simulation texture in a deferred manner
* Shows the correct Usage Bits for the texture such that Sampling (usage as texture via `Texture2DRD` or directly in a uniform `sampler2D`) and Image Load/Store are possible (Storage Bit)
* Shows how to use Push Constants for Shader data that changes frequently
* Shows how to use `image2D` to write to an image in a compute shader

This toy example queues a compute shader dispatch in `_physics_process` such that it executes a stable number of times per second, which is what you usually want for simulations. It would work the same way if you want to run it in `_process` instead. A push constant is set alternating between `0` and `1` which the shader reacts to by either outputting a horizontal or vertical gradient.

There is no `submit()` or `sync()` because this is done automatically behind the scenes for the main rendering device.
# Godot-Falling-Sand-Compute-Shader
