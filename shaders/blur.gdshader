shader_type canvas_item;

uniform vec2 center = vec2(0.5);
uniform float power: hint_range(-10.0, 10.0) = 2.0;
uniform float iterations: hint_range(1.0, 20.0);

void fragment() {
	vec2 uv = UV;
	vec2 dir = center - uv;
	vec2 blur = dir * power * 0.01;
	vec4 color = vec4(0.0);
	for (float i = 0.0; i < iterations; i++) {
		color += texture(TEXTURE, uv);
		uv += blur;
	}
	COLOR = color;
}