# Synthesizes original sound effects for Greyfall. No samples are used: every sound is built
# from sine harmonics and filtered noise, so the results are free to upload and use.
import sys, wave, subprocess, os
import numpy as np

SR = 44100
OUT = sys.argv[1]
rng = np.random.default_rng(7)

def envelope(n, attack, release, sustain_level=1.0):
    t = np.arange(n) / SR
    dur = n / SR
    env = np.ones(n) * sustain_level
    a = t < attack
    env[a] = (t[a] / attack) * sustain_level
    r = t > dur - release
    env[r] = sustain_level * np.clip((dur - t[r]) / release, 0, 1) ** 1.5
    return env

def shaped_noise(n, low, high):
    spec = np.fft.rfft(rng.standard_normal(n))
    freqs = np.fft.rfftfreq(n, 1 / SR)
    mask = np.exp(-0.5 * ((np.log(np.maximum(freqs, 1)) - np.log(np.sqrt(low * high))) / (np.log(high / low) / 2)) ** 2)
    return np.fft.irfft(spec * mask, n)

def formant_voice(dur, f0_start, f0_end, formants, breath=0.25, jitter=0.02, rough=0.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    glide = np.linspace(0, 1, n) ** 0.8
    f0 = f0_start + (f0_end - f0_start) * glide
    f0 *= 1 + 0.03 * np.sin(2 * np.pi * 5.2 * t) + jitter * np.convolve(rng.standard_normal(n), np.ones(800) / 800, "same")
    phase = 2 * np.pi * np.cumsum(f0) / SR
    voice = np.zeros(n)
    for h in range(1, 40):
        fh = f0 * h
        weight = sum(a * np.exp(-0.5 * ((fh - fc) / bw) ** 2) for fc, bw, a in formants) + 0.02 / h
        weight = np.where(fh < SR / 2 - 500, weight, 0)
        voice += weight * np.sin(h * phase + rng.uniform(0, 6.28))
    if rough > 0:  # subharmonic growl
        voice *= 1 + rough * np.sin(phase / 2)
    noise = shaped_noise(n, 300, 3000) * breath
    out = voice / (np.max(np.abs(voice)) + 1e-9) + noise / (np.max(np.abs(noise)) + 1e-9) * breath
    return np.tanh(out * 1.6)

def save(name, signal, peak_db=-4.0):
    signal = signal / (np.max(np.abs(signal)) + 1e-9) * 10 ** (peak_db / 20)
    data = (signal * 32767).astype(np.int16)
    wav = os.path.join(OUT, name + ".wav")
    with wave.open(wav, "wb") as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(SR); f.writeframes(data.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(wav)
    print(name, f"{len(signal) / SR:.2f}s")

# Vowel-like formants: (centre Hz, width Hz, gain). Low, closed vowels sound like moans.
UH = [(450, 140, 1.0), (900, 200, 0.5), (2400, 400, 0.12)]
OO = [(330, 110, 1.0), (750, 160, 0.35), (2300, 400, 0.08)]
AH = [(650, 170, 1.0), (1100, 220, 0.6), (2500, 400, 0.15)]

# Groans: slow, low and falling in pitch; soft attack so they never startle.
for i, (dur, a, b, fm, rough) in enumerate([(1.7, 104, 78, UH, 0.15), (2.1, 92, 70, OO, 0.25), (1.5, 118, 86, AH, 0.1)], 1):
    v = formant_voice(dur, a, b, fm, breath=0.35, rough=rough)
    v *= envelope(len(v), 0.35, 0.7, 0.9)
    save(f"zombie_groan_{i}", v, peak_db=-6.0)

# Attacks: shorter, higher snarl with more breath and a fast attack.
for i, (dur, a, b) in enumerate([(0.55, 165, 120), (0.65, 150, 105)], 1):
    v = formant_voice(dur, a, b, AH, breath=0.6, jitter=0.05, rough=0.4)
    v *= envelope(len(v), 0.03, 0.3)
    save(f"zombie_attack_{i}", v, peak_db=-5.0)

# Punch swing: a quick band of air that sweeps upward.
n = int(0.22 * SR)
t = np.arange(n) / SR
swoosh = np.zeros(n)
chunk = 512
for start in range(0, n, chunk):
    seg = min(chunk, n - start)
    centre = 500 + 2200 * (start / n)
    swoosh[start:start + seg] = shaped_noise(chunk * 4, centre * 0.6, centre * 1.6)[:seg]
swoosh *= np.sin(np.pi * t / t[-1]) ** 2
save("punch_swing", swoosh, peak_db=-9.0)

# Punch hit: a low body thump plus a short slap.
n = int(0.25 * SR)
t = np.arange(n) / SR
thump = np.sin(2 * np.pi * (95 * t - 70 * t * t)) * np.exp(-t * 22)
slap = shaped_noise(n, 900, 4000) * np.exp(-t * 90)
hit = thump * 1.0 + slap * 0.35 / (np.max(np.abs(slap)) + 1e-9)
save("punch_hit", hit, peak_db=-4.0)
