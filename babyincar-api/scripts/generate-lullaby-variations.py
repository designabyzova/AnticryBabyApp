#!/usr/bin/env python3
"""
Generate Lullaby Variations
Creates many variations of popular lullaby melodies
"""

import wave
import struct
import math
import os
import random
from pathlib import Path

OUTPUT_DIR = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio"
SAMPLE_RATE = 44100
CHANNELS = 2
SAMPLE_WIDTH = 2

# Note frequencies
NOTES = {
    'C3': 130.81, 'D3': 146.83, 'E3': 164.81, 'F3': 174.61, 'G3': 196.00, 'A3': 220.00, 'B3': 246.94,
    'C4': 261.63, 'D4': 293.66, 'E4': 329.63, 'F4': 349.23, 'G4': 392.00, 'A4': 440.00, 'B4': 493.88,
    'C5': 523.25, 'D5': 587.33, 'E5': 659.25, 'F5': 698.46, 'G5': 783.99, 'A5': 880.00, 'B5': 987.77,
    'R': 0  # Rest
}

# Famous lullabies
LULLABIES = {
    'twinkle': [
        ('C4', 0.5), ('C4', 0.5), ('G4', 0.5), ('G4', 0.5), ('A4', 0.5), ('A4', 0.5), ('G4', 1.0),
        ('F4', 0.5), ('F4', 0.5), ('E4', 0.5), ('E4', 0.5), ('D4', 0.5), ('D4', 0.5), ('C4', 1.0),
        ('G4', 0.5), ('G4', 0.5), ('F4', 0.5), ('F4', 0.5), ('E4', 0.5), ('E4', 0.5), ('D4', 1.0),
        ('G4', 0.5), ('G4', 0.5), ('F4', 0.5), ('F4', 0.5), ('E4', 0.5), ('E4', 0.5), ('D4', 1.0),
        ('C4', 0.5), ('C4', 0.5), ('G4', 0.5), ('G4', 0.5), ('A4', 0.5), ('A4', 0.5), ('G4', 1.0),
        ('F4', 0.5), ('F4', 0.5), ('E4', 0.5), ('E4', 0.5), ('D4', 0.5), ('D4', 0.5), ('C4', 1.0),
    ],
    'brahms': [
        ('G4', 0.5), ('E4', 0.5), ('G4', 0.5), ('E4', 0.5), ('G4', 0.5), ('C5', 0.5), ('B4', 0.5), ('A4', 0.5),
        ('G4', 0.5), ('F4', 0.5), ('A4', 0.5), ('G4', 0.5), ('F4', 0.5), ('E4', 0.5), ('D4', 1.0),
        ('E4', 0.5), ('C4', 0.5), ('E4', 0.5), ('C4', 0.5), ('E4', 0.5), ('A4', 0.5), ('G4', 0.5), ('F4', 0.5),
        ('E4', 0.5), ('D4', 0.5), ('F4', 0.5), ('E4', 0.5), ('D4', 0.5), ('C4', 1.0), ('R', 0.5),
    ],
    'hush_baby': [
        ('E4', 0.5), ('G4', 0.5), ('G4', 0.5), ('A4', 0.5), ('G4', 0.5), ('R', 0.25), ('E4', 0.5),
        ('E4', 0.5), ('D4', 0.5), ('D4', 0.5), ('D4', 0.5), ('E4', 0.5), ('D4', 0.75),
        ('D4', 0.5), ('E4', 0.5), ('G4', 0.5), ('A4', 0.5), ('G4', 0.5), ('R', 0.25), ('E4', 0.5),
        ('D4', 0.5), ('D4', 0.5), ('E4', 0.5), ('D4', 0.5), ('C4', 1.0),
    ],
    'rockabye': [
        ('E4', 0.75), ('D4', 0.25), ('C4', 0.5), ('G3', 0.5), ('A3', 0.5), ('B3', 0.5), ('C4', 1.0),
        ('D4', 0.75), ('E4', 0.25), ('F4', 0.5), ('E4', 0.5), ('D4', 0.5), ('C4', 0.5), ('B3', 1.0),
        ('E4', 0.75), ('D4', 0.25), ('C4', 0.5), ('G3', 0.5), ('A3', 0.5), ('B3', 0.5), ('C4', 1.0),
    ],
    'mary_lamb': [
        ('E4', 0.5), ('D4', 0.5), ('C4', 0.5), ('D4', 0.5), ('E4', 0.5), ('E4', 0.5), ('E4', 1.0),
        ('D4', 0.5), ('D4', 0.5), ('D4', 1.0), ('E4', 0.5), ('G4', 0.5), ('G4', 1.0),
        ('E4', 0.5), ('D4', 0.5), ('C4', 0.5), ('D4', 0.5), ('E4', 0.5), ('E4', 0.5), ('E4', 0.5), ('E4', 0.5),
        ('D4', 0.5), ('D4', 0.5), ('E4', 0.5), ('D4', 0.5), ('C4', 1.0),
    ],
    'star_light': [
        ('G4', 0.5), ('G4', 0.5), ('A4', 0.5), ('G4', 0.5), ('G4', 0.5), ('E4', 0.5), ('R', 0.5),
        ('G4', 0.5), ('G4', 0.5), ('A4', 0.5), ('G4', 0.5), ('G4', 0.5), ('E4', 1.0),
        ('D4', 0.5), ('D4', 0.5), ('E4', 0.5), ('D4', 0.5), ('C4', 0.5), ('D4', 0.5), ('E4', 1.0),
    ],
    'are_you_sleeping': [
        ('C4', 0.5), ('D4', 0.5), ('E4', 0.5), ('C4', 0.5), ('C4', 0.5), ('D4', 0.5), ('E4', 0.5), ('C4', 0.5),
        ('E4', 0.5), ('F4', 0.5), ('G4', 1.0), ('E4', 0.5), ('F4', 0.5), ('G4', 1.0),
        ('G4', 0.25), ('A4', 0.25), ('G4', 0.25), ('F4', 0.25), ('E4', 0.5), ('C4', 0.5),
        ('G4', 0.25), ('A4', 0.25), ('G4', 0.25), ('F4', 0.25), ('E4', 0.5), ('C4', 0.5),
        ('C4', 0.5), ('G3', 0.5), ('C4', 1.0), ('C4', 0.5), ('G3', 0.5), ('C4', 1.0),
    ],
    'londonderry': [
        ('G4', 0.5), ('A4', 0.25), ('B4', 0.25), ('C5', 0.5), ('D5', 0.5), ('E5', 0.25), ('D5', 0.25),
        ('C5', 0.5), ('A4', 0.5), ('G4', 0.5), ('E4', 0.5), ('D4', 0.5), ('E4', 0.5), ('G4', 1.0),
        ('G4', 0.5), ('A4', 0.25), ('B4', 0.25), ('C5', 0.5), ('D5', 0.5), ('E5', 0.5), ('D5', 0.5),
        ('C5', 1.0), ('R', 0.5),
    ]
}

def generate_piano_tone(freq, duration, volume=0.3, sample_rate=SAMPLE_RATE):
    """Generate a piano-like tone"""
    samples = []
    num_samples = int(duration * sample_rate)

    for i in range(num_samples):
        t = i / sample_rate
        phase = i / num_samples

        # Piano envelope
        attack = min(1.0, t / 0.01)
        decay = math.exp(-phase * 3)
        env = attack * decay

        # Piano harmonics
        value = 0
        value += 0.5 * math.sin(2 * math.pi * freq * t)
        value += 0.3 * math.sin(2 * math.pi * freq * 2 * t) * math.exp(-phase * 4)
        value += 0.15 * math.sin(2 * math.pi * freq * 3 * t) * math.exp(-phase * 5)
        value += 0.08 * math.sin(2 * math.pi * freq * 4 * t) * math.exp(-phase * 6)
        value += 0.04 * math.sin(2 * math.pi * freq * 5 * t) * math.exp(-phase * 7)

        samples.append(env * volume * value)

    return samples

def generate_music_box_tone(freq, duration, volume=0.25, sample_rate=SAMPLE_RATE):
    """Generate a music box tone"""
    samples = []
    num_samples = int(duration * sample_rate)

    for i in range(num_samples):
        t = i / sample_rate
        phase = i / num_samples

        # Music box envelope - quick attack, long decay
        env = math.exp(-phase * 2) * (1 - math.exp(-t * 100))

        # Bright metallic harmonics
        value = 0
        value += 0.4 * math.sin(2 * math.pi * freq * t)
        value += 0.35 * math.sin(2 * math.pi * freq * 2 * t)
        value += 0.2 * math.sin(2 * math.pi * freq * 3 * t)
        value += 0.15 * math.sin(2 * math.pi * freq * 4 * t)
        value += 0.1 * math.sin(2 * math.pi * freq * 5 * t)

        samples.append(env * volume * value)

    return samples

def generate_glockenspiel_tone(freq, duration, volume=0.2, sample_rate=SAMPLE_RATE):
    """Generate a glockenspiel/chime tone"""
    samples = []
    num_samples = int(duration * sample_rate)

    for i in range(num_samples):
        t = i / sample_rate
        phase = i / num_samples

        # Bell-like envelope
        env = math.exp(-phase * 1.5) * (1 - math.exp(-t * 50))

        # Inharmonic bell partials
        value = 0
        value += 0.4 * math.sin(2 * math.pi * freq * t)
        value += 0.3 * math.sin(2 * math.pi * freq * 2.0 * t)
        value += 0.25 * math.sin(2 * math.pi * freq * 2.4 * t)
        value += 0.15 * math.sin(2 * math.pi * freq * 3.0 * t)
        value += 0.1 * math.sin(2 * math.pi * freq * 4.2 * t)

        samples.append(env * volume * value)

    return samples

def generate_harp_tone(freq, duration, volume=0.25, sample_rate=SAMPLE_RATE):
    """Generate a harp-like tone"""
    samples = []
    num_samples = int(duration * sample_rate)

    for i in range(num_samples):
        t = i / sample_rate
        phase = i / num_samples

        # Harp envelope - quick attack, medium decay
        env = math.exp(-phase * 2.5) * (1 - math.exp(-t * 80))

        # Harp harmonics
        value = 0
        value += 0.5 * math.sin(2 * math.pi * freq * t)
        value += 0.25 * math.sin(2 * math.pi * freq * 2 * t) * math.exp(-phase * 3)
        value += 0.12 * math.sin(2 * math.pi * freq * 3 * t) * math.exp(-phase * 4)
        value += 0.06 * math.sin(2 * math.pi * freq * 4 * t) * math.exp(-phase * 5)

        samples.append(env * volume * value)

    return samples

def generate_celesta_tone(freq, duration, volume=0.2, sample_rate=SAMPLE_RATE):
    """Generate a celesta tone (like in Dance of the Sugar Plum Fairy)"""
    samples = []
    num_samples = int(duration * sample_rate)

    for i in range(num_samples):
        t = i / sample_rate
        phase = i / num_samples

        # Celesta envelope
        env = math.exp(-phase * 2) * (1 - math.exp(-t * 60))

        # Slightly detuned oscillators for warmth
        value = 0
        value += 0.4 * math.sin(2 * math.pi * freq * t)
        value += 0.35 * math.sin(2 * math.pi * freq * 1.002 * t)
        value += 0.2 * math.sin(2 * math.pi * freq * 2 * t)
        value += 0.1 * math.sin(2 * math.pi * freq * 3 * t)

        samples.append(env * volume * value)

    return samples

def generate_melody(melody_notes, tone_generator, tempo_mult=1.0, transpose=0, volume=0.3):
    """Generate a melody from notes using specified tone generator"""
    samples = []

    for note, duration in melody_notes:
        duration = duration * tempo_mult

        if note == 'R' or note not in NOTES:
            # Rest
            samples.extend([0] * int(duration * SAMPLE_RATE))
        else:
            freq = NOTES[note]
            # Apply transposition
            freq = freq * (2 ** (transpose / 12))
            tone = tone_generator(freq, duration, volume)
            samples.extend(tone)
            # Small gap between notes
            samples.extend([0] * int(0.02 * SAMPLE_RATE))

    return samples

def apply_fade(samples, fade_in=0.5, fade_out=1.0, sample_rate=SAMPLE_RATE):
    fade_in_samples = int(fade_in * sample_rate)
    fade_out_samples = int(fade_out * sample_rate)

    for i in range(min(fade_in_samples, len(samples))):
        samples[i] *= i / fade_in_samples

    for i in range(min(fade_out_samples, len(samples))):
        idx = len(samples) - 1 - i
        if idx >= 0:
            samples[idx] *= i / fade_out_samples

    return samples

def save_wav(samples, filename, sample_rate=SAMPLE_RATE):
    Path(filename).parent.mkdir(parents=True, exist_ok=True)
    samples = apply_fade(samples.copy())
    max_val = max(abs(min(samples)), abs(max(samples)), 0.001)
    samples = [int(s / max_val * 32767 * 0.9) for s in samples]

    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(CHANNELS)
        wav_file.setsampwidth(SAMPLE_WIDTH)
        wav_file.setframerate(sample_rate)

        for sample in samples:
            packed = struct.pack('<hh', sample, sample)
            wav_file.writeframes(packed)

    return filename

def main():
    print("=" * 60)
    print("LULLABY VARIATIONS GENERATOR")
    print("=" * 60)

    lullabies_dir = os.path.join(OUTPUT_DIR, "lullabies")
    os.makedirs(lullabies_dir, exist_ok=True)

    # Instruments to use
    instruments = [
        ("piano", generate_piano_tone),
        ("musicbox", generate_music_box_tone),
        ("glock", generate_glockenspiel_tone),
        ("harp", generate_harp_tone),
        ("celesta", generate_celesta_tone),
    ]

    # Tempo variations (slower = more soothing)
    tempos = [
        ("slow", 1.4),
        ("medium", 1.2),
        ("normal", 1.0),
    ]

    # Transpose variations (lower = more soothing usually)
    transposes = [
        ("low", -5),
        ("mid", 0),
    ]

    total = 0

    for lullaby_name, melody in LULLABIES.items():
        print(f"\nGenerating {lullaby_name} variations...")

        for inst_name, tone_gen in instruments:
            for tempo_name, tempo_mult in tempos:
                for trans_name, transpose in transposes:
                    filename = f"{lullaby_name}_{inst_name}_{tempo_name}_{trans_name}.wav"
                    filepath = os.path.join(lullabies_dir, filename)

                    if os.path.exists(filepath) and os.path.getsize(filepath) > 10000:
                        print(f"  [SKIP] {filename}")
                        total += 1
                        continue

                    try:
                        # Generate melody multiple times for longer duration
                        samples = []
                        for _ in range(3):  # Repeat 3 times
                            samples.extend(generate_melody(melody, tone_gen, tempo_mult, transpose))
                            samples.extend([0] * int(0.5 * SAMPLE_RATE))  # Gap between repeats

                        save_wav(samples, filepath)
                        size_kb = os.path.getsize(filepath) / 1024
                        print(f"  [OK] {filename} ({size_kb:.1f} KB)")
                        total += 1

                    except Exception as e:
                        print(f"  [FAIL] {filename}: {e}")

    print(f"\n{'='*60}")
    print(f"Generated: {total} lullaby variations")
    print("=" * 60)

if __name__ == "__main__":
    main()
