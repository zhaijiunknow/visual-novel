shader_type canvas_item;

// ── 时间参数（在 Logo 的材质里直接改，不用碰动画）──
// 光带位置由 TIME 推出来，不再靠 AnimationPlayer 打关键帧。
uniform float period : hint_range(0.1, 30.0) = 8.0;         // 一整轮的时长（含尾部停顿）
uniform float sweep_time : hint_range(0.05, 5.0) = 0.733;   // 一次扫光花多久（x 从 0 到 1）
uniform float sweep_period : hint_range(0.05, 5.0) = 1.433; // 相邻两次扫光的间隔（含扫光本身）
uniform int sweep_count : hint_range(1, 8) = 2;             // 一轮里扫几次
// ── 外观 ──
uniform float size : hint_range(0.0, 1.0) = 0.06;
uniform vec3 shine_color = vec3(1.0, 0.95, 0.72);
uniform float shine_strength : hint_range(0.0, 2.0) = 0.95;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.18;

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	// 一轮里的前 sweep_count 次依次扫过（每次 sweep_period 一个循环、其中前 sweep_time 从 0 到 1），
	// 之后停在末尾（x=1，即光带贴在右端），等下一轮
	float t = mod(TIME, period);
	float active = sweep_period * float(sweep_count);
	float x = 1.0;
	if (t < active) {
		x = min(mod(t, sweep_period) / sweep_time, 1.0);
	}

	vec2 uv = REGION_RECT.zw * vec2(x, 0.0) + REGION_RECT.xy;

	float diff = abs(UV.x - uv.x);
	float band = 1.0 - smoothstep(0.0, size, diff);
	float glow = band * band;
	col.rgb = mix(col.rgb, shine_color, glow * shine_strength);
	col.rgb += glow * glow_strength;

	COLOR = col;
}
