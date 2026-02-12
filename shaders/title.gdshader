shader_type canvas_item;

uniform float x : hint_range(0.0, 1.0) = 0.0;
uniform float size : hint_range(0.0, 1.0) = 0.03;
uniform float dark_alpha : hint_range(0.0, 1.0) = 0.7;
uniform float light_alpha : hint_range(0.0, 2.0) = 1.0;

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	
	vec2 uv = REGION_RECT.zw * vec2(x, 0.0) + REGION_RECT.xy;
	
	float diff = abs(UV.x - uv.x);
	float offset = diff / size;
	float alpha_diff = light_alpha - dark_alpha;
	col.a *= diff >= size ? dark_alpha : light_alpha - (offset * alpha_diff);

	COLOR = col;
}