shader_type canvas_item;

// 历史回溯行的悬停高亮 —— 高亮「两条横线中间那一整块卡片」，整块铺满、不圆角不内缩。
//
// 思路：**底子保持暗**（游戏是夜色调，亮面板一定不搭），靠"流动的光"来做亮点：
//   1. 底板 base_*        — 均匀的半透明深紫蓝，只负责把这一格从背景里垫出来，不做明暗结构
//   2. 流光 aurora_*      — 两条反向流动的窄光带（蓝 ↔ 紫随时间缓慢漂移），斜着扫过这一格
//   3. 飘雪 spark_*       — 稀疏亮点缓慢飘落 + 呼吸闪烁（呼应"雪"的主题）
//   4. 扫描线 scan_*      — 细横线缓慢上行，全息投影屏质感（默认关）
// 每层一个强度旋钮（0 = 关），可以在检查器里自由配比。全部程序化，不用任何素材。
//
// 三个必须知道的点：
//   1. UV 是 0~1，按像素算的密度（扫描线间距、雪点格子）要用 rect_size，
//      由 log_line.gd 在 resized 时写进来（每行一份材质，不能共享，否则多行互相覆盖）
//   2. 输出 alpha 必须乘 COLOR.a —— 脚本 tween 的是节点 modulate.a，
//      直接覆盖 COLOR 会把 modulate 丢掉、淡入淡出就没了
//   3. 时间动画只在悬停（节点可见）时跑，静止时整块隐藏，不花性能

uniform vec2 rect_size = vec2(1821.0, 150.0);

uniform vec4 base_color : source_color = vec4(0.227, 0.251, 0.439, 0.35);
uniform vec4 aurora_color_a : source_color = vec4(0.42, 0.60, 0.98, 1.0);
uniform vec4 aurora_color_b : source_color = vec4(0.70, 0.52, 0.98, 1.0);
uniform vec4 spark_color : source_color = vec4(0.88, 0.94, 1.0, 1.0);

uniform float edge_feather_x = 56.0;  // 左右两端的羽化宽度（像素）：0 = 硬切。
                                      // 它会吃掉两端各这么多宽度，靠 log_line 的左右出血补回来
                                      // （回想页的滚动区左右留了余量专门给这段羽化用）
uniform float edge_feather_y = 0.0;   // 上下两条边默认不羽化（边要齐），羽化宽度按像素给
uniform float aurora_strength = 0.22;
uniform float aurora_speed = 0.055;
uniform float aurora_width = 0.05;   // 光带的宽度（斜向归一化坐标，越小越像"一道光"）
uniform float aurora_hue_speed = 0.22;
uniform float spark_strength = 0.18;
uniform float spark_speed = 0.045;
uniform float spark_scale = 26.0;
uniform float scan_strength = 0.0;
uniform float scan_speed = 0.08;
uniform float scan_gap = 7.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 一条斜向光带：沿 x + y*0.35 方向滑动，两侧 smoothstep 柔化
float light_ribbon(vec2 uv, float offset, float t, float width) {
	float slant = uv.x + uv.y * 0.35;
	return 1.0 - smoothstep(0.0, width, abs(slant - fract(t + offset)));
}

// 稀疏亮点：按格子散列，位置随机漂移 + 各自频率闪烁
float specks(vec2 uv, float t) {
	vec2 p = uv * vec2(rect_size.x / max(rect_size.y, 1.0), 1.0) * spark_scale;
	p.y -= t * spark_scale * 0.35;            // 整体缓慢下落
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float r = hash21(cell);
	vec2 center = vec2(hash21(cell + 1.7), hash21(cell + 5.3)) * 0.6 + 0.2;
	float twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 2.4 + r * 31.4));
	return smoothstep(0.055, 0.0, length(f - center)) * step(0.80, r) * twinkle;
}

void fragment() {
	float fade = COLOR.a;

	vec2 px = UV * rect_size;
	vec3 rgb = base_color.rgb;
	float alpha = base_color.a;

	// 流光：两条反向的窄光带；颜色随时间在蓝紫之间漂移
	float t = TIME;
	float r1 = light_ribbon(UV, 0.0, t * aurora_speed, aurora_width);
	float r2 = light_ribbon(UV, 0.55, -t * aurora_speed * 0.7, aurora_width * 0.7);
	float aur = clamp((r1 + r2 * 0.8) * aurora_strength, 0.0, 1.0);
	float hue = 0.5 + 0.5 * sin(t * aurora_hue_speed);
	vec3 aurora_rgb = mix(aurora_color_a.rgb, aurora_color_b.rgb, clamp(hue + r1 * 0.35, 0.0, 1.0));
	rgb += aurora_rgb * aur * 0.55;
	alpha = min(1.0, alpha + aur * 0.22);

	// 飘雪
	float sp = specks(UV, t * (spark_speed * 20.0)) * spark_strength;
	rgb += spark_color.rgb * sp;
	alpha = min(1.0, alpha + sp * 0.6);

	// 扫描线：每 scan_gap 像素一条亮线，缓慢上行
	float line_coord = (px.y + t * scan_speed * 60.0) / scan_gap;
	float lines = pow(0.5 + 0.5 * sin(line_coord * TAU), 8.0);
	float sc = lines * scan_strength;
	rgb += spark_color.rgb * sc * 0.4;
	alpha = min(1.0, alpha + sc * 0.3);

	// 边缘羽化：整块（含光带、雪点）在靠近边界时平滑淡出，不要硬切的矩形边
	float feather = smoothstep(0.0, max(edge_feather_x, 0.001), min(px.x, rect_size.x - px.x))
		* smoothstep(0.0, max(edge_feather_y, 0.001), min(px.y, rect_size.y - px.y));
	alpha *= feather;

	COLOR = vec4(rgb, clamp(alpha, 0.0, 1.0) * fade);
}
