shader_type canvas_item;
render_mode unshaded;

uniform vec2 canvas_size = vec2(640.0, 360.0);
uniform float scroll_offset = 0.0;

void fragment() {
	vec2 pixels = UV * canvas_size + vec2(scroll_offset, 0.0);
	vec2 tile_uv = pixels / vec2(textureSize(TEXTURE, 0));
	COLOR = texture(TEXTURE, tile_uv);
}
