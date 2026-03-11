# Godot Falling Sand Compute Shader
This was built using my compute shader example as a baseline, see: https://github.com/Clocktown/Godot-ComputeShader-Image-TextureRect-Example

The project features a simple falling sand implementation. No fancy shading. Display happens via a `TextureRect` and sand is continuously spawned at the mouse position. The bottom border acts as a wall, while left/right/top borders are the void and will drain sand. The `TextureRect` contains a script that calculates the texel position of the mouse cursor.

The magic happens inside of the `SandSimulator` node. You can change the resolution of the simulation using the width and height properties on the node, this can be done while running from the editor if you want.

`_physics_process` is used to queue up the compute shader dispatches. This allows framerate independent behaviour. Additionally, I have added code that enables profiling of the compute shaders using the visual profiler. This is done via `RenderingDevice.capture_timestamp(...)`, it just so happens that an (as far as I know undocumented) naming convention exists
that enables you to use this to add entries to the visual profiler, which I figured out by printing the names of existing timestamps. Because compute shaders run per frame, not per physics frame, the code has to use some bits of logic such that the timestamps neatly wrap around all scheduled compute shaders.

## How the actual simulation works
The simulation uses a 2-channel 8bit UNORM texture for data. The red channel stores whether sand is present or not (0/1). The green channel stores a mask, which I will explain later.

I parallelized the falling sand algorithm using the *Block Cellular Automaton* concept, specifically using the *Margolus neighborhood*. What this means is that the simulation grid (i.e., the texture) is divided into blocks of size 2x2.
Each block is independent of all other blocks. In other words, the falling sand rules are applied to each 2x2 in parallel, as if the outside world of each block does not exist. Of course, this would not work on its own, which is why
the mapping of grid cells to blocks is shifted by (1,1) every odd simulation step.

The nice thing about this is that the algorithm can be implemented using a bunch of bit logic and a simple switch-case. That is because the 2x2 block can be encoded into a 4-bit value, which is just some integer. There are only 16 possible values,
so coming up with a transition table is quite simple. The code thus has no need for branches, explicit checking which cells are empty etc., it is a simple integer-to-integer transition table. As this table handles the entire 2x2 block,
each compute shader thread calculates an entire 2x2 block by reading and writing the respective four pixels. No ping-pong buffering is needed and the amount of invocations are cut by a factor of four with no redundant neighborhood accesses between threads.

While this is very nice, it comes with obvious patterns and gaps in the falling sand. If you trace a few simple examples by hand, you will notice that there are cases where sand can fall twice in two consecutive steps and cases where it can only fall once,
depending on where the sand is positioned in the block.

This is where the mask comes in. The mask encodes whether the sand in a cell already fell in the last simulation step. If that is the case, the sand can't fall again in the current step. A bunch of bitwise operations can be used to cleverly calculate this
without the need for any if/else shenanigans. As a result, one "whole" simulation step now consists of two substeps (one where the blocks are shifted, and one where they are not). Sand can only fall by one cell in two substeps. This is why each `_physics_process` schedules two
compute shader dispatches, one for each substep.

The masking drastically improves the situation, but a pattern will still be visible for obvious reasons. The way to solve this is by introducing *randomness*. Basically, the transition table is modified such that there are multiple possible
transitions in some cases with an associated probability. One such possibility is to simply not apply any rule with a small chance, another possibility is to allow for sand to fall diagonally when it can fall straight.

## Performance
It is **blazingly** fast. The default resolution is only set to a low value because it looks nice and has pixel-art vibes. Try changing the `TextureRect` properties so it no longer fits the width and then increase the resolution of the simulation to, say, 4000x4000, and check the visual profiler. On my GPU,
this runs in 0.1-0.2ms per `_physics_process` (i.e. for two substeps). The entry in question is "Compute Sand".

Because it is so fast, it is very much feasible to run more than two substeps every physics step to speed up the simulation. My GPU can still handle setting the playback so 16x in the editor on a 4000x4000 simulation resolution and requires under one millisecond for the compute.

## Displaying the simulation
Due to how Godot internally handles a 2-channel texture displayed on a `TextureRect`, the presence of the mask messes with the visuals. Thus, a simple custom shader is attached to the `TextureRect` that only uses the red-channel for visuals. Empty texels will also display with transparency, which may be useful.
