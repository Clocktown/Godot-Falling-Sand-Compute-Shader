extends Node

#region Editor Exports
@export var textureRect: SandTextureRect
@export var width := 800:
	set(value):
		width = value
		textureDirty = true
@export var height := 600:
	set(value):
		height = value
		textureDirty = true
#endregion
#region Low-Level Rendering
# Push Constants have to be multiple of 16 Bytes!
const PUSH_CONSTANT_SIZE := 16
# Preloading the shader file
const SHADER_FILE := preload("res://sand.glsl") as RDShaderFile

# Low-Level Rendering API handles
var rd: RenderingDevice
var sandShader: RID
var sandTexture: RID
var uniformSet: RID
var sandPipeline: RID
#endregion
#region Script Variables
var elapsed: float = 0
var textureDirty: bool = false
var timestampJustQueued: bool = true
#endregion

func _ready() -> void:
	# Same RenderingDevice as the one that renders the nodes so we can share data
	rd = RenderingServer.get_rendering_device()
		
	# Create Shader
	var shaderSpirv: RDShaderSPIRV = SHADER_FILE.get_spirv()
	sandShader = rd.shader_create_from_spirv(shaderSpirv)
	
	# Creates a new texture and uniform set and assigns texture to textureRect
	_recreate_texture()
	
	# Compute pipeline so we can dispatch compute commands
	sandPipeline = rd.compute_pipeline_create(sandShader)

# Using physics process due to it executing a stable number of times per second
func _physics_process(delta: float) -> void:
	if textureDirty:
		print("texture dirty")
		call_deferred("_recreate_texture")
		textureDirty = false
	# Push Constants are ideal for data that changes every frame
	var mousePos := textureRect.get_mouse_texel()
	var pc := PackedByteArray()
	pc.resize(PUSH_CONSTANT_SIZE) 
	pc.encode_s32(0, 0)
	pc.encode_float(4, elapsed)
	pc.encode_s32(8, mousePos.x)
	pc.encode_s32(12, mousePos.y)
	var pc2 := PackedByteArray()
	pc2.resize(PUSH_CONSTANT_SIZE) 
	pc2.encode_s32(0, 1)
	pc2.encode_float(4, elapsed + 0.5 * delta)
	pc2.encode_s32(8, mousePos.x)
	pc2.encode_s32(12, mousePos.y)
	
	@warning_ignore("integer_division")
	var groupsX := (((width + 1) / 2) + 7) / 8
	@warning_ignore("integer_division")
	var groupsY := (((height + 1) / 2) + 7) / 8
	# Visual Profiler and compute shader dispatches work on a frame by frame basis
	# Since we are using _physics_process, multiple compute lists can pile up
	# Hence, the capturing of timestamps has to be done only once per frame; see _process for remaining logic
	_handle_timestamps_from_physics_process()
	var sandComputeList := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(sandComputeList, sandPipeline)
	rd.compute_list_bind_uniform_set(sandComputeList, uniformSet, 0)
	rd.compute_list_set_push_constant(sandComputeList, pc, pc.size())
	rd.compute_list_dispatch(sandComputeList, groupsX, groupsY, 1)
	rd.compute_list_add_barrier(sandComputeList)
	rd.compute_list_set_push_constant(sandComputeList, pc2, pc2.size())
	rd.compute_list_dispatch(sandComputeList, groupsX, groupsY, 1)
	rd.compute_list_end()
	elapsed += delta
	
func _process(_delta: float):
	# Handle timestamp capturing
	_handle_timestamps_from_process()
	
func _exit_tree():
	rd.free_rid(sandPipeline)
	rd.free_rid(uniformSet)
	rd.free_rid(sandTexture)
	rd.free_rid(sandShader)

func _recreate_texture():
	textureDirty = false
	if Engine.is_editor_hint():
		return
	if uniformSet.is_valid():
		rd.free_rid(uniformSet)
	if sandTexture.is_valid():
		rd.free_rid(sandTexture)
	# Create a new texture in a specific format
	var sandTextureFormat := RDTextureFormat.new()
	sandTextureFormat.format = RenderingDevice.DATA_FORMAT_R8G8_UNORM
	sandTextureFormat.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	sandTextureFormat.width = width
	sandTextureFormat.height = height
		# Sampling Bit allows usage as Texture (i.e. Texture2DRD or a sampler2D in the Compute Shader)
		# Storage Bit allows usage as Image (i.e. image2D)
	sandTextureFormat.usage_bits = \
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | \
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	sandTexture = rd.texture_create(sandTextureFormat, RDTextureView.new())
	
	# This uniform never changes, no need to keep it alive
	var sandTextureUniform := RDUniform.new()
	sandTextureUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	sandTextureUniform.binding = 0
	sandTextureUniform.add_id(sandTexture)
	# Uniform set is typically used for stuff that doesn't change frame-by-frame
	uniformSet = rd.uniform_set_create([sandTextureUniform], sandShader, 0)
	
	# Wrap the texture RID and pass it to the TextureRect
	var sandTextureWrapper := Texture2DRD.new();
	sandTextureWrapper.texture_rd_rid = sandTexture
	textureRect.texture = sandTextureWrapper

func _handle_timestamps_from_process():
	if OS.has_feature("editor"):
		if timestampJustQueued:
			rd.capture_timestamp("> Compute")
			rd.capture_timestamp("Compute Sand")
			timestampJustQueued = false
		if not timestampJustQueued:
			rd.capture_timestamp("< Compute")
			timestampJustQueued = true

func _handle_timestamps_from_physics_process():
	if OS.has_feature("editor"):
		if timestampJustQueued:
			rd.capture_timestamp("> Compute")
			rd.capture_timestamp("Compute Sand")
			timestampJustQueued = false
