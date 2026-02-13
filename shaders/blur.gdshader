shader_type canvas_item;

uniform float iterations: hint_range(0.0, 1.0);

void fragment() {
	vec2 uv = UV;
	vec4 color = texture(TEXTURE, uv);
	color.rgb *= vec3(1.0 - iterations);
	COLOR = color;
}