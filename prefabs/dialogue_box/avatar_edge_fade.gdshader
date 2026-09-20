// 头像左右边缘淡出：让对话框头像的左右裁切边不再生硬，融入背后的对话框背景。
// 基于 UV 在左右两端把 alpha 渐隐到 0；头像离屏渲染为透明底，淡出处会透出背景。
shader_type canvas_item;

// 左、右各自独立的淡出宽度（占头像纹理宽度比例，0~0.5），两侧可不一样
uniform float fade_width_left = 0.12;
uniform float fade_width_right = 0.12;

void fragment() {
	// 左端：UV.x 从 0 渐显到 fade_width_left；右端：1-UV.x 从 0 渐显到 fade_width_right
	float edge = smoothstep(0.0, fade_width_left, UV.x);
	edge *= smoothstep(0.0, fade_width_right, 1.0 - UV.x);
	// 注意：这里进来的 COLOR 已经是「贴图 × modulate」（Godot 4 的 canvas_item 就是这样），
	// 所以不要再 texture() 采样一遍去乘，那会把贴图乘两次、颜色被平方（头像会变暗变色）。
	// 只改 alpha：既保留左右边缘淡出，又让头像跟着对话框一起淡入淡出
	COLOR.a *= edge;
}
