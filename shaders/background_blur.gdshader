shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 10.0) = 3.0;
uniform vec4 tint_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);

void fragment() {
	vec2 pixel_size = 1.0 / vec2(textureSize(screen_texture, 0));
	vec4 color = vec4(0.0);

	// 9-tap Gaussian blur
	float weights[5] = {0.227027, 0.1945946, 0.1216216, 0.054054, 0.016216};
	color += textureLod(screen_texture, SCREEN_UV, 0.0) * weights[0];
	for (int i = 1; i < 5; i++) {
		vec2 offset = pixel_size * float(i) * blur_amount;
		color += textureLod(screen_texture, SCREEN_UV + vec2(offset.x, 0.0), 0.0) * weights[i];
		color += textureLod(screen_texture, SCREEN_UV - vec2(offset.x, 0.0), 0.0) * weights[i];
		color += textureLod(screen_texture, SCREEN_UV + vec2(0.0, offset.y), 0.0) * weights[i];
		color += textureLod(screen_texture, SCREEN_UV - vec2(0.0, offset.y), 0.0) * weights[i];
	}

	// 混合半透明遮罩
	COLOR = mix(color, tint_color, tint_color.a);
}
