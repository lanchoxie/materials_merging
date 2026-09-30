extends RefCounted
## v0.25 island day/night: a slow, mostly-daylight cycle driven by the wall clock (cosmetic only,
## never saved). sample(t) blends keyframes for t in [0, 1): dawn → long day → dusk → mild night.

const LENGTH_SECONDS = 960.0
## [t, sun pitch°, sun colour, sun energy, ambient colour, ambient energy, sky colour, sea deep, sea shallow, night]
const KEYS = [
	[0.00, -12.0, "ffc9a4", 0.45, "c9b7d6", 0.34, "2a3450", "1d3f58", "5a8fa0", 0.55],
	[0.08, -30.0, "ffdcb0", 0.66, "c4d8d4", 0.37, "3b5a6a", "1b4458", "4f9aa0", 0.15],
	[0.18, -53.0, "fff1d9", 0.78, "b4ded3", 0.38, "152e37", "184556", "4f9e9f", 0.0],
	[0.58, -53.0, "fff1d9", 0.78, "b4ded3", 0.38, "152e37", "184556", "4f9e9f", 0.0],
	[0.68, -24.0, "ffc6b0", 0.58, "d0c4d4", 0.37, "3a3448", "2a3a62", "5f86b8", 0.2],
	[0.76, -10.0, "a9b8ff", 0.34, "8ea0cf", 0.32, "0f1830", "0f2a44", "2f5d7c", 1.0],
	[0.92, -10.0, "a9b8ff", 0.34, "8ea0cf", 0.32, "0f1830", "0f2a44", "2f5d7c", 1.0],
	[1.00, -12.0, "ffc9a4", 0.45, "c9b7d6", 0.34, "2a3450", "1d3f58", "5a8fa0", 0.55],
]

static func phase_at(unix_seconds: float) -> float:
	return fposmod(unix_seconds, LENGTH_SECONDS) / LENGTH_SECONDS

static func sample(t: float) -> Dictionary:
	t = fposmod(t, 1.0)
	var i := 0
	while i < KEYS.size() - 2 and t >= float(KEYS[i + 1][0]): i += 1
	var a: Array = KEYS[i]
	var b: Array = KEYS[i + 1]
	var k := smoothstep(0.0, 1.0, (t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])))
	return {
		"sun_pitch": lerpf(a[1], b[1], k), "sun_color": Color(a[2]).lerp(Color(b[2]), k), "sun_energy": lerpf(a[3], b[3], k),
		"ambient_color": Color(a[4]).lerp(Color(b[4]), k), "ambient_energy": lerpf(a[5], b[5], k),
		"sky": Color(a[6]).lerp(Color(b[6]), k), "sea_deep": Color(a[7]).lerp(Color(b[7]), k),
		"sea_shallow": Color(a[8]).lerp(Color(b[8]), k), "night": lerpf(a[9], b[9], k),
		"sun_yaw": sun_yaw(t),
	}

## Shadows sweep across the island during the day; the moon walks back at night.
static func sun_yaw(t: float) -> float:
	const DUSK = 0.72
	return lerpf(-80.0, 20.0, t / DUSK) if t < DUSK else lerpf(20.0, -80.0, (t - DUSK) / (1.0 - DUSK))

static func label(t: float) -> String:
	t = fposmod(t, 1.0)
	return "清晨" if t < 0.14 else "白天" if t < 0.62 else "黄昏" if t < 0.72 else "夜晚" if t < 0.95 else "黎明"
