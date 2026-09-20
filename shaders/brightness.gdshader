shader_type canvas_item;

// 提亮图片。两种手段可叠加，默认值都是「不变」，所以直接挂上去不会改动现有画面：
//   brightness        乘法提亮：整体变亮，高光更容易过曝（1.0 = 不变）
//   brightness_offset 加法提亮：主要抬暗部，画面会略微发灰（0.0 = 不变）
uniform float brightness : hint_range(0.0, 4.0) = 1.0;
uniform float brightness_offset : hint_range(-1.0, 1.0) = 0.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 rgb = tex.rgb * brightness + vec3(brightness_offset);
	// 乘上节点的 modulate / self_modulate，保留现有的淡入淡出和染色
	COLOR = vec4(rgb, tex.a) * COLOR;
}
