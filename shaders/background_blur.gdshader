shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount : hint_range(0.0, 10.0) = 3.0;
uniform vec4 tint_color : source_color = vec4(0.0, 0.0, 0.0, 0.5);

void fragment() {
	vec2 pixel_size = 1.0 / vec2(textureSize(screen_texture, 0)) * blur_amount;

	// 13-tap 两遍模拟：先水平采样再用对角线补充，覆盖更大面积
	float w[7] = {0.1592, 0.1469, 0.1154, 0.0773, 0.0440, 0.0214, 0.0089};

	vec4 color = textureLod(screen_texture, SCREEN_UV, 0.0) * w[0];

	for (int i = 1; i < 7; i++) {
		float fi = float(i);
		// 水平
		color += textureLod(screen_texture, SCREEN_UV + vec2(pixel_size.x * fi, 0.0), 0.0) * w[i];
		color += textureLod(screen_texture, SCREEN_UV - vec2(pixel_size.x * fi, 0.0), 0.0) * w[i];
		// 垂直
		color += textureLod(screen_texture, SCREEN_UV + vec2(0.0, pixel_size.y * fi), 0.0) * w[i];
		color += textureLod(screen_texture, SCREEN_UV - vec2(0.0, pixel_size.y * fi), 0.0) * w[i];
		// 对角线（补充覆盖，让模糊更均匀柔和）
		vec2 diag = vec2(pixel_size.x * fi, pixel_size.y * fi) * 0.7071;
		color += textureLod(screen_texture, SCREEN_UV + diag, 0.0) * w[i] * 0.5;
		color += textureLod(screen_texture, SCREEN_UV - diag, 0.0) * w[i] * 0.5;
		color += textureLod(screen_texture, SCREEN_UV + vec2(diag.x, -diag.y), 0.0) * w[i] * 0.5;
		color += textureLod(screen_texture, SCREEN_UV + vec2(-diag.x, diag.y), 0.0) * w[i] * 0.5;
	}

	// 归一化（水平+垂直权重之和 + 对角线权重之和）
	float total = w[0];
	for (int i = 1; i < 7; i++) {
		total += w[i] * 4.0 + w[i] * 2.0;
	}
	color /= total;

	COLOR = mix(color, tint_color, tint_color.a);
}
