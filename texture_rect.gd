extends TextureRect
class_name SandTextureRect

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	
func get_texture_draw_rect() -> Rect2:
	var texSize = texture.get_size()
	var rectSize = size
	var actualScale = min(rectSize.x / texSize.x, rectSize.y / texSize.y)
	var drawSize = texSize * actualScale
	var offset = (rectSize - drawSize) * 0.5
	return Rect2(offset, drawSize)
	
func get_mouse_uv() -> Vector2:
	var mouse = get_local_mouse_position()
	var drawRect = get_texture_draw_rect()
	var uv = (mouse - drawRect.position) / drawRect.size
	return uv
	
func get_mouse_texel() -> Vector2i:
	var uv = get_mouse_uv()
	var tex_size = texture.get_size()
	return Vector2i(uv * tex_size)
