"""Synthesize Atom Atelier's sound bank into assets/audio/*.wav.

Everything is generated from code (additive / noise synthesis), so the sounds are deterministic,
license-free and can be re-tuned by editing this file:  python dev/gen_audio.py
Loops carry a WAV 'smpl' chunk so Godot's importer detects the loop points.
"""
import os
import struct
import numpy as np

SR = 44100
AMB_SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(20260929)


def t_axis(seconds, sr=SR):
	return np.arange(int(seconds * sr)) / sr


def env(n, attack=0.004, decay=0.2, sr=SR):
	"""Exponential decay envelope with a short linear attack."""
	t = np.arange(n) / sr
	e = np.exp(-t / max(decay, 1e-4))
	a = int(attack * sr)
	if a > 0:
		e[:a] *= np.linspace(0.0, 1.0, a)
	return e


def tone(freq, seconds, partials=((1, 1.0),), decay=0.3, attack=0.003, sr=SR):
	t = t_axis(seconds, sr)
	out = np.zeros_like(t)
	for ratio, amp in partials:
		# Higher partials die faster, like struck bars and bells.
		out += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * ratio / max(decay * 6, 1e-3))
	return out * env(len(t), attack, decay, sr)


MARIMBA = ((1, 1.0), (4.0, 0.35), (9.2, 0.08))
BELL = ((1, 1.0), (2.76, 0.5), (5.4, 0.25), (8.93, 0.12))
GLASS = ((1, 1.0), (2.32, 0.4), (4.25, 0.2), (6.63, 0.08))


def note(n):
	"""MIDI note number to Hz."""
	return 440.0 * 2 ** ((n - 69) / 12)


def place(buf, sig, at, sr=SR):
	i = int(at * sr)
	end = min(len(buf), i + len(sig))
	buf[i:end] += sig[: end - i]


def spectral_noise(seconds, lo, hi, sr=SR, tilt=0.0):
	"""Band-limited noise via FFT shaping. The result is circular, so it loops seamlessly."""
	n = int(seconds * sr)
	spec = np.fft.rfft(rng.standard_normal(n))
	f = np.fft.rfftfreq(n, 1 / sr)
	shape = ((f >= lo) & (f <= hi)).astype(float)
	# Soft edges instead of a brick wall.
	shape = np.convolve(shape, np.hanning(64) / np.hanning(64).sum(), mode="same")
	if tilt:
		shape *= (np.maximum(f, 20) / 1000.0) ** tilt
	out = np.fft.irfft(spec * shape, n)
	return out / (np.max(np.abs(out)) + 1e-9)


def sweep(f0, f1, seconds, decay=0.2, sr=SR):
	t = t_axis(seconds, sr)
	freq = f0 * (f1 / f0) ** (t / seconds)
	phase = 2 * np.pi * np.cumsum(freq) / sr
	return np.sin(phase) * env(len(t), 0.002, decay, sr)


def reverb(sig, seconds=0.6, mix=0.25, sr=SR):
	"""Cheap convolution reverb with a decaying noise impulse."""
	n = int(seconds * sr)
	ir = rng.standard_normal(n) * np.exp(-np.arange(n) / (sr * seconds / 5))
	ir /= np.sqrt(np.sum(ir ** 2))
	size = len(sig) + n
	wet = np.fft.irfft(np.fft.rfft(sig, size) * np.fft.rfft(ir, size), size)
	dry = np.concatenate([sig, np.zeros(n)])
	return dry * (1 - mix) + wet * mix


def normalize(sig, peak=0.85):
	return sig / (np.max(np.abs(sig)) + 1e-9) * peak


def fade_tail(sig, seconds=0.02, sr=SR):
	n = min(len(sig), int(seconds * sr))
	sig[-n:] *= np.linspace(1, 0, n)
	return sig


def write_wav(name, sig, sr=SR, loop=False, peak=0.85):
	os.makedirs(OUT, exist_ok=True)
	sig = normalize(sig, peak)
	if not loop:
		sig = fade_tail(sig)
	data = (np.clip(sig, -1, 1) * 32767).astype("<i2").tobytes()
	chunks = [b"fmt " + struct.pack("<IHHIIHH", 16, 1, 1, sr, sr * 2, 2, 16), b"data" + struct.pack("<I", len(data)) + data]
	if loop:
		frames = len(sig)
		# smpl chunk: 9 header fields + 1 loop (cue id, type 0=forward, start, end, fraction, count 0=infinite)
		smpl = struct.pack("<9I", 0, 0, int(1e9 / sr), 60, 0, 0, 0, 1, 0) + struct.pack("<6I", 0, 0, 0, frames - 1, 0, 0)
		chunks.append(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
	body = b"WAVE" + b"".join(chunks)
	with open(os.path.join(OUT, name + ".wav"), "wb") as f:
		f.write(b"RIFF" + struct.pack("<I", len(body)) + body)
	return name


# ---------------------------------------------------------------- one-shots

def s_tap():
	return tone(note(88), 0.12, GLASS, decay=0.05) + 0.3 * tone(note(76), 0.12, ((1, 1),), decay=0.03)


def s_coin():
	b = np.zeros(int(0.35 * SR))
	place(b, tone(note(83), 0.3, BELL, decay=0.08), 0)
	place(b, tone(note(88), 0.3, BELL, decay=0.12), 0.06)
	return b


def s_harvest():
	b = np.zeros(int(0.6 * SR))
	for i, n in enumerate([72, 76, 79, 84]):
		place(b, tone(note(n), 0.4, MARIMBA, decay=0.12), i * 0.055)
	return reverb(b, 0.4, 0.18)


def s_sell():
	b = np.zeros(int(0.9 * SR))
	for i, n in enumerate([79, 83, 86, 91]):
		place(b, tone(note(n), 0.5, BELL, decay=0.15), i * 0.07)
	sparkle = spectral_noise(0.5, 6000, 12000) * env(int(0.5 * SR), 0.01, 0.12) * 0.25
	place(b, sparkle, 0.2)
	return reverb(b, 0.6, 0.22)


def s_build():
	thump = sweep(160, 55, 0.3, decay=0.09)
	click = spectral_noise(0.05, 800, 5000) * env(int(0.05 * SR), 0.001, 0.012) * 0.6
	b = np.zeros(int(0.45 * SR))
	place(b, thump, 0)
	place(b, click, 0)
	place(b, tone(note(67), 0.3, MARIMBA, decay=0.1) * 0.5, 0.09)
	return b


def s_upgrade():
	b = np.zeros(int(1.3 * SR))
	place(b, sweep(300, 1400, 0.45, decay=0.3) * 0.35, 0)
	for n in [72, 76, 79]:
		place(b, tone(note(n), 0.9, BELL, decay=0.35) * 0.6, 0.38)
	place(b, tone(note(84), 0.9, BELL, decay=0.4), 0.46)
	return reverb(b, 0.8, 0.3)


def s_perfect():
	b = np.zeros(int(1.8 * SR))
	for i, n in enumerate([72, 76, 79, 84, 88]):
		place(b, tone(note(n), 1.2, BELL, decay=0.45) * 0.7, i * 0.045)
	shimmer = spectral_noise(1.0, 5000, 14000) * env(int(1.0 * SR), 0.05, 0.3) * 0.18
	place(b, shimmer, 0.1)
	return reverb(b, 1.0, 0.35)


def s_error():
	b = np.zeros(int(0.35 * SR))
	for i, n in enumerate([58, 55]):
		sig = tone(note(n), 0.18, ((1, 1), (3, 0.3), (5, 0.15)), decay=0.07)
		place(b, sig, i * 0.1)
	return b


def s_ui():
	return tone(note(84), 0.05, GLASS, decay=0.012) * 0.8


def s_whoosh():
	n = int(0.5 * SR)
	noise = spectral_noise(0.5, 300, 4000)
	shape = np.sin(np.linspace(0, np.pi, n)) ** 2
	return noise * shape


def s_discovery():
	b = np.zeros(int(2.4 * SR))
	seq = [(67, 0), (72, 0.12), (76, 0.24), (79, 0.36), (84, 0.6)]
	for n, at in seq:
		place(b, tone(note(n), 1.2, MARIMBA, decay=0.25), at)
		place(b, tone(note(n + 12), 1.2, BELL, decay=0.3) * 0.3, at)
	for n in [72, 76, 79, 84]:
		place(b, tone(note(n), 1.6, BELL, decay=0.6) * 0.4, 0.6)
	return reverb(b, 1.2, 0.35)


def s_chop():
	b = np.zeros(int(0.3 * SR))
	knock = spectral_noise(0.12, 300, 2500) * env(int(0.12 * SR), 0.001, 0.025)
	body = tone(140, 0.2, ((1, 1), (2.3, 0.4)), decay=0.05)
	place(b, knock, 0)
	place(b, body * 0.8, 0)
	return b


def s_dig():
	n = int(0.35 * SR)
	grit = spectral_noise(0.35, 150, 3000, tilt=-0.5)
	grains = (rng.random(n) < 0.004).astype(float)
	grains = np.convolve(grains, np.hanning(200), mode="same")
	return grit * env(n, 0.01, 0.1) * (0.5 + grains)


def s_step():
	n = int(0.12 * SR)
	return spectral_noise(0.12, 80, 900) * env(n, 0.002, 0.03) + sweep(90, 50, 0.12, decay=0.03) * 0.6


def s_pop():
	return sweep(400, 1300, 0.09, decay=0.035)


def s_tick():
	return tone(note(96), 0.04, GLASS, decay=0.008)


def s_hit():
	b = np.zeros(int(0.3 * SR))
	place(b, spectral_noise(0.15, 200, 3000) * env(int(0.15 * SR), 0.001, 0.03), 0)
	place(b, sweep(220, 70, 0.2, decay=0.06), 0)
	return b


def s_open():
	b = np.zeros(int(0.5 * SR))
	place(b, sweep(500, 1100, 0.18, decay=0.1) * 0.4, 0)
	place(b, tone(note(79), 0.35, GLASS, decay=0.1), 0.08)
	return b


def s_close():
	b = np.zeros(int(0.4 * SR))
	place(b, sweep(900, 450, 0.15, decay=0.08) * 0.4, 0)
	place(b, tone(note(72), 0.3, GLASS, decay=0.08), 0.05)
	return b


# ---------------------------------------------------------------- ambience loops

def amb_island(seconds=24.0):
	"""Warm pad over a slow chord cycle with soft wind; circular so it loops cleanly."""
	sr = AMB_SR
	t = t_axis(seconds, sr)
	out = np.zeros_like(t)
	chords = [[48, 55, 64, 71], [45, 52, 60, 67], [41, 48, 57, 64], [43, 50, 59, 66]]
	seg = seconds / len(chords)
	for i, chord in enumerate(chords):
		# Raised-cosine window centered on each chord; windows wrap around the loop.
		center = (i + 0.5) * seg
		d = (t - center + seconds / 2) % seconds - seconds / 2
		w = np.where(np.abs(d) < seg, 0.5 + 0.5 * np.cos(np.pi * d / seg), 0.0)
		for n in chord:
			f = note(n)
			# Detuned pair gives a slow chorus; integer cycles per loop keep it seamless.
			for detune in (-0.12, 0.12):
				cycles = round((f + detune) * seconds)
				out += w * np.sin(2 * np.pi * cycles * t / seconds) * 0.12
	wind = spectral_noise(seconds, 200, 1200, sr) * (0.5 + 0.5 * np.sin(2 * np.pi * 2 * t / seconds)) * 0.08
	return out + wind


def amb_river(seconds=20.0):
	sr = AMB_SR
	t = t_axis(seconds, sr)
	water = spectral_noise(seconds, 150, 2500, sr, tilt=-0.6)
	burble = spectral_noise(seconds, 800, 4000, sr) * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * t / seconds)) * 0.3
	out = water * 0.55 + burble * 0.35
	leaves = spectral_noise(seconds, 2000, 8000, sr) * (0.5 + 0.5 * np.sin(2 * np.pi * 3 * t / seconds + 1)) * 0.12
	out += leaves
	# Birds: short chirps with fast pitch wiggles, placed away from the loop seam.
	for at in rng.uniform(1.0, seconds - 1.5, 9):
		dur = rng.uniform(0.08, 0.2)
		for k in range(int(rng.integers(2, 5))):
			tt = t_axis(dur, sr)
			f0 = rng.uniform(2600, 4200)
			f = f0 * (1 + 0.25 * np.sin(2 * np.pi * rng.uniform(18, 35) * tt))
			chirp = np.sin(2 * np.pi * np.cumsum(f) / sr) * np.sin(np.pi * tt / dur) ** 2 * 0.25
			place(out, chirp, at + k * (dur + 0.05), sr)
	return out


SOUNDS = {
	"tap": s_tap, "coin": s_coin, "harvest": s_harvest, "sell": s_sell, "build": s_build,
	"upgrade": s_upgrade, "perfect": s_perfect, "error": s_error, "ui": s_ui, "whoosh": s_whoosh,
	"discovery": s_discovery, "chop": s_chop, "dig": s_dig, "step": s_step, "pop": s_pop,
	"tick": s_tick, "hit": s_hit, "open": s_open, "close": s_close,
}


def main():
	for name, fn in SOUNDS.items():
		write_wav(name, fn())
	write_wav("amb_island", amb_island(), AMB_SR, loop=True, peak=0.5)
	write_wav("amb_river", amb_river(), AMB_SR, loop=True, peak=0.5)
	total = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT) if f.endswith(".wav"))
	print(f"wrote {len(SOUNDS) + 2} sounds to {os.path.normpath(OUT)} ({total / 1e6:.2f} MB)")


if __name__ == "__main__":
	main()
