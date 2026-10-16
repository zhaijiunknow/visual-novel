shader_type canvas_item;

// 历史回溯行的悬停高亮 —— 高亮「两条横线中间那一整块卡片」，整块铺满、不圆角不内缩。
//
// 样式往游戏名上靠：**无言初雪**（雪）× **奇迹书**（金色、书页）
//   1. 底板 base_*        — 很淡的紫蓝，只把这一格从背景里垫出来，不做明暗结构
//   2. 初雪 flake_*       — 直接用美术那朵六角雪花（botton_set_click.tres），
//                           在格子里随机摆放/旋转/缩放，缓慢飘落；外加程序化的细雪尘
//   3. 奇迹金 gold_*      — 一小部分雪花/雪粒是暖金色（取自背景里"Miracle."手写笔迹的颜色）
//   4. 霜花 frost_*       — 左右两端羽化的那一段里长出结晶颗粒，像初雪落在卡片边上
//   5. 流光 aurora_*      — 一道斜向柔光，颜色在**冷蓝（初雪）**和**暖金（奇迹）**之间缓慢漂移
//   6. 书页线 north_*     — 极淡的横线，像书页格线（默认关）
//
// 三个必须知道的点：
//   1. UV 是 0~1，按像素算的密度/形状要用 rect_size，由 log_line.gd 在 resized 时写进来
//      （每行一份材质，不能共享，否则多行互相覆盖）
//   2. 输出 alpha 必须乘 COLOR.a —— 脚本 tween 的是节点 modulate.a，
//      直接覆盖 COLOR 会把 modulate 丢掉、淡入淡出就没了
//   3. 时间动画只在悬停（节点可见）时跑，静止时整块隐藏，不花性能

uniform vec2 rect_size = vec2(1821.0, 150.0);

// 雪花素材：用它的图集 + 区域来采（采样器传的是图集本身，
// AtlasTexture 交给 shader 是拿不到区域信息的，所以 region 得手动传）
uniform sampler2D flake_tex : filter_linear, repeat_disable;
uniform vec2 flake_atlas_size = vec2(2560.0, 2048.0);
uniform vec4 flake_region = vec4(1352.0, 1970.0, 73.0, 76.0);  // botton_set_click.tres 的 region

uniform vec4 base_color : source_color = vec4(0.227, 0.251, 0.439, 0.35);
uniform vec4 snow_color : source_color = vec4(0.88, 0.94, 1.0, 1.0);       // 初雪：冷蓝白
uniform vec4 miracle_gold : source_color = vec4(0.89, 0.82, 0.70, 1.0);   // 奇迹：暖香槟金
uniform vec4 aurora_color_a : source_color = vec4(0.42, 0.60, 0.98, 1.0); // 流光 冷端
uniform vec4 aurora_color_b : source_color = vec4(0.89, 0.82, 0.70, 1.0); // 流光 暖端

uniform float edge_feather_x = 56.0;  // 左右两端的羽化宽度（像素）：0 = 硬切。
                                      // 它会吃掉两端各这么多宽度，靠 log_line 的左右出血补回来
uniform float edge_feather_y = 0.0;   // 上下不羽化（边要齐）

uniform float aurora_strength = 0.22;
uniform float aurora_speed = 0.055;
uniform float aurora_width = 0.05;
uniform float aurora_hue_speed = 0.22;

uniform float flake_strength = 0.6;   // 六角雪花（要小而稀，像初雪不是贴纸）
uniform float flake_scale = 110.0;    // 雪花格子的边长（像素）：越大雪花越稀
uniform float flake_speed = 0.5;      // 飘落速度
uniform float dust_strength = 0.18;   // 细雪尘
uniform float dust_scale = 34.0;
uniform float gold_amount = 1.0;      // 金色微粒的比例（0 = 全白，1 = 默认的一小部分）
uniform float frost_strength = 0.45;  // 两端霜花
uniform float north_strength = 0.0;   // 书页横线（默认关）
uniform float north_gap = 26.0;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 从图集里采那朵雪花。uv 是雪花自己那格里的坐标（0~1，超出即无）
float flake_sample(vec2 uv) {
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		return 0.0;
	}
	// 往里收一点，避免线性过滤把图集里邻居的像素带进来
	vec2 safe_uv = clamp(uv, vec2(0.02), vec2(0.98));
	vec2 atlas_uv = (flake_region.xy + safe_uv * flake_region.zw) / flake_atlas_size;
	return texture(flake_tex, atlas_uv).a;
}

void fragment() {
	float fade = COLOR.a;
	float t = TIME;

	vec2 px = UV * rect_size;
	vec3 rgb = base_color.rgb;
	float alpha = base_color.a;

	// ── 流光：冷蓝 ↔ 暖金缓慢漂移（初雪的光 / 奇迹的光）
	float r1 = 1.0 - smoothstep(0.0, aurora_width, abs((UV.x + UV.y * 0.35) - fract(t * aurora_speed)));
	float r2 = 1.0 - smoothstep(0.0, aurora_width * 0.7, abs((UV.x + UV.y * 0.35) - fract(-t * aurora_speed * 0.7 + 0.55)));
	float aur = clamp((r1 + r2 * 0.8) * aurora_strength, 0.0, 1.0);
	float hue = 0.5 + 0.5 * sin(t * aurora_hue_speed);
	vec3 aurora_rgb = mix(aurora_color_a.rgb, aurora_color_b.rgb, clamp(hue + r1 * 0.3, 0.0, 1.0));
	rgb += aurora_rgb * aur;
	alpha = min(1.0, alpha + aur * 0.25);

	// ── 初雪：雪花（粗格，用美术那朵，随机摆放/旋转/缩放 + 缓慢飘落）+ 雪尘（细格，各自闪烁）
	float gold_mask = 0.0;
	vec2 fp = vec2(px.x, px.y - t * flake_speed * 30.0) / flake_scale;
	vec2 fcell = floor(fp);
	float fseed = hash21(fcell);
	float has_flake = step(0.5, fseed);                      // 约一半的格子里有雪花
	vec2 fcenter = vec2(hash21(fcell + 3.1), hash21(fcell + 7.7)) * 0.6 + 0.2;
	float fsize = 0.08 + 0.06 * hash21(fcell + 11.3);         // 雪花占格子的比例 → 实际约 18~30px
	float frot = hash21(fcell + 5.5) * TAU + t * 0.25 * (fseed - 0.5);
	vec2 fq = (fract(fp) - fcenter) / fsize * 0.5 + 0.5;      // → 雪花自己那格里的 0~1
	fq = mat2(vec2(cos(frot), -sin(frot)), vec2(sin(frot), cos(frot))) * (fq - 0.5) + 0.5;
	// 靠近上下边缘时淡出：卡片上下不羽化是硬边，雪花撞上去会被切成半个，先化掉
	float vert_fade = smoothstep(0.0, 12.0, min(px.y, rect_size.y - px.y));
	float flake = flake_sample(fq) * has_flake * vert_fade;
	gold_mask = max(gold_mask, step(0.90, hash21(fcell + 23.0)) * has_flake * gold_amount);

	vec2 dp = vec2(px.x, px.y - t * 12.0) / dust_scale;
	vec2 dcell = floor(dp);
	float dseed = hash21(dcell);
	vec2 dcenter = vec2(hash21(dcell + 1.3), hash21(dcell + 9.1)) * 0.6 + 0.2;
	float dust = smoothstep(0.07, 0.0, length(fract(dp) - dcenter)) * step(0.74, dseed);
	dust *= 0.4 + 0.6 * (0.5 + 0.5 * sin(t * 2.0 + dseed * 30.0));
	gold_mask = max(gold_mask, step(0.90, hash21(dcell + 41.0)) * dust * gold_amount);

	float snow_amt = flake * flake_strength + dust * dust_strength;
	vec3 snow_rgb = mix(snow_color.rgb, miracle_gold.rgb, clamp(gold_mask, 0.0, 1.0));
	rgb += snow_rgb * snow_amt;
	alpha = min(1.0, alpha + snow_amt * 0.7);

	// ── 两端霜花：结晶只长在左右羽化那一段，像初雪落在卡片边上
	float d_end = min(px.x, rect_size.x - px.x);
	float end_mask = 1.0 - smoothstep(0.0, edge_feather_x * 1.3, d_end);
	vec2 cq = floor(px / 4.0);
	float crystal = hash21(cq) * 0.55 + hash21(cq * 1.7) * 0.45;
	float frost = smoothstep(0.60, 0.80, crystal) * end_mask * frost_strength;
	rgb += snow_color.rgb * frost * 0.6;
	alpha = min(1.0, alpha + frost * 0.4);

	// ── 书页横线（默认关）：极淡的等距横线，像书页格线
	float north_line = pow(0.5 + 0.5 * sin(px.y / north_gap * TAU), 10.0) * north_strength;
	rgb += miracle_gold.rgb * north_line * 0.25;
	alpha = min(1.0, alpha + north_line * 0.2);

	// ── 边缘羽化：左右两端平滑淡出（上下不羽化，边要齐）
	float feather = smoothstep(0.0, max(edge_feather_x, 0.001), min(px.x, rect_size.x - px.x))
		* smoothstep(0.0, max(edge_feather_y, 0.001), min(px.y, rect_size.y - px.y));
	alpha *= feather;

	COLOR = vec4(rgb, clamp(alpha, 0.0, 1.0) * fade);
}
