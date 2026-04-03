#!/usr/bin/env python3
"""Generate WAV preview files for all Sound Code melodies."""

import wave
import struct
import math
import os

SAMPLE_RATE = 44100
AMPLITUDE = 0.5

def sine_tone(freq, duration_ms):
    """Generate sine wave samples for a given frequency and duration."""
    n_samples = int(SAMPLE_RATE * duration_ms / 1000)
    samples = []
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        # Apply fade in/out to avoid clicks (5ms)
        fade_samples = int(SAMPLE_RATE * 0.005)
        envelope = 1.0
        if i < fade_samples:
            envelope = i / fade_samples
        elif i > n_samples - fade_samples:
            envelope = (n_samples - i) / fade_samples
        if freq > 0:
            sample = AMPLITUDE * envelope * math.sin(2 * math.pi * freq * t)
        else:
            sample = 0.0
        samples.append(sample)
    return samples

def silence(duration_ms):
    """Generate silence."""
    n_samples = int(SAMPLE_RATE * duration_ms / 1000)
    return [0.0] * n_samples

def write_wav(filename, samples):
    """Write samples to a WAV file."""
    with wave.open(filename, 'w') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        for s in samples:
            s = max(-1.0, min(1.0, s))
            f.writeframes(struct.pack('<h', int(s * 32767)))

# ============================================================
#  MELODY DEFINITIONS (matching play_sound.sh)
# ============================================================

MELODIES = {
    "ode_to_joy": {
        "desc": "Beethoven - Oda do radosci (pelna fraza)",
        "freqs": [330,330,349,392, 392,349,330,294, 262,262,294,330, 330,294,294],
        "durs":  [180]*15,
        "gaps":  [50]*15,
        "last_dur": 300,
    },
    "nhl_goal_horn": {
        "desc": "Goal Horn - syrena + fanfara",
        "freqs": [150,150,150, 392,494,587,784],
        "durs":  [400,400,400, 150,150,150,350],
        "gaps":  [100,100,200, 30,30,30,0],
        "last_dur": 500,
    },
    "nhl_charge": {
        "desc": "Klasyczne organowe Charge!",
        "freqs": [392,523,659,784, 659,784],
        "durs":  [150,150,150,400, 150,500],
        "gaps":  [30,30,30,150, 30,0],
        "last_dur": 600,
    },
    "nhl_hat_trick": {
        "desc": "Hat Trick - 3x klakson + fanfara",
        "freqs": [175,175,175, 523,659,784,1047,784,1047],
        "durs":  [250,250,250, 120,120,120,200,120,400],
        "gaps":  [80,80,200, 30,30,30,30,30,0],
        "last_dur": 500,
    },
    "nhl_power_play": {
        "desc": "Power Play - energetyczny motyw",
        "freqs": [330,392,494,659, 330,392,494,659,784],
        "durs":  [100,100,100,200, 100,100,100,200,350],
        "gaps":  [20,20,20,80, 20,20,20,80,0],
        "last_dur": 450,
    },
    "nhl_overtime": {
        "desc": "Overtime - dramatyczny build-up",
        "freqs": [262,294,330,392, 523,659,784,1047],
        "durs":  [250,250,250,300, 150,150,150,500],
        "gaps":  [50,50,50,100, 30,30,30,0],
        "last_dur": 600,
    },
    "nhl_organ_lets_go": {
        "desc": "Organowe Let's Go! z trybun",
        "freqs": [523,523,523,659,784, 523,523,523,659,784],
        "durs":  [150,150,100,100,300, 150,150,100,100,300],
        "gaps":  [30,30,20,20,150, 30,30,20,20,0],
        "last_dur": 400,
    },
}

def generate_melody(name, melody):
    samples = []
    freqs = melody["freqs"]
    durs = melody["durs"]
    gaps = melody["gaps"]
    last_dur = melody["last_dur"]
    n = len(freqs)

    for i in range(n):
        dur = last_dur if i == n - 1 else durs[i]
        samples.extend(sine_tone(freqs[i], dur))
        if i < n - 1 and gaps[i] > 0:
            samples.extend(silence(gaps[i]))

    os.makedirs("preview", exist_ok=True)
    filename = f"preview/{name}.wav"
    write_wav(filename, samples)
    # Calculate duration
    total_ms = sum(durs[:-1]) + last_dur + sum(gaps[:-1])
    print(f"  {filename:40s} ({total_ms:4d}ms) - {melody['desc']}")

if __name__ == "__main__":
    print("Generating melody previews...\n")
    for name, melody in MELODIES.items():
        generate_melody(name, melody)
    print(f"\nDone! Files in ./preview/")
