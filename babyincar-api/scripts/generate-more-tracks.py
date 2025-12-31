#!/usr/bin/env python3
"""
Generate MORE Audio Tracks - Extended variations
Creates additional synthesized audio with different parameters
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

def generate_sine_wave(frequency, duration, volume=0.3, sample_rate=SAMPLE_RATE):
    samples = []
    num_samples = int(duration * sample_rate)
    for i in range(num_samples):
        t = i / sample_rate
        value = volume * math.sin(2 * math.pi * frequency * t)
        samples.append(value)
    return samples

def generate_chord(frequencies, duration, volume=0.2, sample_rate=SAMPLE_RATE):
    """Generate a chord from multiple frequencies"""
    samples = [0] * int(duration * sample_rate)
    for freq in frequencies:
        wave = generate_sine_wave(freq, duration, volume / len(frequencies), sample_rate)
        for i, v in enumerate(wave):
            samples[i] += v
    return samples

def generate_soft_pad(duration, root_freq=220, volume=0.2, sample_rate=SAMPLE_RATE):
    """Generate a soft synthesizer pad sound"""
    samples = []
    num_samples = int(duration * sample_rate)

    # Slow LFO for tremolo
    lfo_freq = 0.5

    for i in range(num_samples):
        t = i / sample_rate

        # Slow attack/release envelope
        env = min(1.0, t / 3.0) * min(1.0, (duration - t) / 3.0)

        # LFO modulation
        lfo = 0.8 + 0.2 * math.sin(2 * math.pi * lfo_freq * t)

        # Multiple harmonics with slow detuning
        value = 0
        for harmonic in range(1, 5):
            detune = 1 + 0.002 * math.sin(2 * math.pi * 0.1 * harmonic * t)
            freq = root_freq * harmonic * detune
            value += (0.5 ** harmonic) * math.sin(2 * math.pi * freq * t)

        samples.append(env * lfo * volume * value)

    return samples

def generate_dreamy_arp(duration, volume=0.2, sample_rate=SAMPLE_RATE):
    """Generate dreamy arpeggio pattern"""
    samples = [0] * int(duration * sample_rate)
    num_samples = len(samples)

    # C major 7 arpeggio
    notes = [262, 330, 392, 494, 523, 659]
    note_duration = 0.8
    note_samples = int(note_duration * sample_rate)
    gap = int(0.4 * sample_rate)

    i = 0
    note_idx = 0
    direction = 1

    while i < num_samples:
        freq = notes[note_idx]

        for j in range(note_samples):
            if i + j < num_samples:
                phase = j / note_samples
                # Soft attack, long decay
                env = (1 - math.exp(-phase * 20)) * math.exp(-phase * 2)

                # Soft bell-like tone
                value = env * volume * (
                    0.5 * math.sin(2 * math.pi * freq * j / sample_rate) +
                    0.25 * math.sin(2 * math.pi * freq * 2 * j / sample_rate) +
                    0.15 * math.sin(2 * math.pi * freq * 3 * j / sample_rate)
                )
                samples[i + j] += value

        i += note_samples + gap

        # Change direction at ends
        note_idx += direction
        if note_idx >= len(notes) - 1:
            direction = -1
        elif note_idx <= 0:
            direction = 1

    return samples

def generate_gentle_bells(duration, volume=0.15, sample_rate=SAMPLE_RATE):
    """Generate gentle bell chime sounds"""
    samples = [0] * int(duration * sample_rate)
    num_samples = len(samples)

    # Bell frequencies (pentatonic)
    bells = [523, 659, 784, 988, 1047]

    # Random bell chimes
    num_chimes = int(duration / 2)
    chime_positions = sorted(random.sample(range(0, num_samples - sample_rate), num_chimes))

    for pos in chime_positions:
        freq = random.choice(bells)
        chime_duration = 1.5 + random.random()
        chime_samples = int(chime_duration * sample_rate)

        for j in range(chime_samples):
            if pos + j < num_samples:
                phase = j / chime_samples
                # Bell envelope
                env = math.exp(-phase * 3) * (1 - math.exp(-phase * 50))

                # Bell harmonics
                value = env * volume * (
                    0.4 * math.sin(2 * math.pi * freq * j / sample_rate) +
                    0.3 * math.sin(2 * math.pi * freq * 2.0 * j / sample_rate) +
                    0.2 * math.sin(2 * math.pi * freq * 2.4 * j / sample_rate) +
                    0.1 * math.sin(2 * math.pi * freq * 3.0 * j / sample_rate)
                )
                samples[pos + j] += value

    return samples

def generate_ambient_drone(duration, base_freq=55, volume=0.2, sample_rate=SAMPLE_RATE):
    """Generate ambient drone/meditation sound"""
    samples = []
    num_samples = int(duration * sample_rate)

    # Multiple layers with slow modulation
    for i in range(num_samples):
        t = i / sample_rate

        # Very slow envelope
        env = min(1.0, t / 5.0) * min(1.0, (duration - t) / 5.0)

        # Multiple detuned oscillators
        value = 0
        for layer in range(4):
            freq = base_freq * (1 + layer) * (1 + 0.01 * math.sin(2 * math.pi * 0.05 * (layer + 1) * t))
            value += 0.25 * math.sin(2 * math.pi * freq * t)

        # Add subtle noise
        value += 0.05 * (random.random() * 2 - 1)

        samples.append(env * volume * value)

    return samples

def generate_soft_guitar(duration, volume=0.2, sample_rate=SAMPLE_RATE):
    """Generate soft guitar-like strums"""
    samples = [0] * int(duration * sample_rate)
    num_samples = len(samples)

    # Guitar chord frequencies (G major, C major, D major)
    chords = [
        [196, 247, 294, 392],  # G
        [262, 330, 392, 523],  # C
        [294, 370, 440, 587],  # D
        [220, 277, 330, 440],  # Am
    ]

    strum_interval = 2.0  # seconds
    strum_samples = int(strum_interval * sample_rate)

    i = 0
    chord_idx = 0

    while i < num_samples:
        chord = chords[chord_idx % len(chords)]

        # Strum each note with slight delay
        for string_idx, freq in enumerate(chord):
            string_delay = int(string_idx * 0.02 * sample_rate)
            note_duration = 1.5
            note_samples = int(note_duration * sample_rate)

            for j in range(note_samples):
                pos = i + string_delay + j
                if pos < num_samples:
                    phase = j / note_samples
                    # Plucked string envelope
                    env = math.exp(-phase * 3) * (1 - math.exp(-phase * 100))

                    # Guitar harmonics
                    value = env * volume / len(chord) * (
                        0.5 * math.sin(2 * math.pi * freq * j / sample_rate) +
                        0.3 * math.sin(2 * math.pi * freq * 2 * j / sample_rate) +
                        0.15 * math.sin(2 * math.pi * freq * 3 * j / sample_rate) +
                        0.05 * math.sin(2 * math.pi * freq * 4 * j / sample_rate)
                    )
                    samples[pos] += value

        i += strum_samples
        chord_idx += 1

    return samples

def generate_harp_glissando(duration, volume=0.15, sample_rate=SAMPLE_RATE):
    """Generate harp glissando sound"""
    samples = [0] * int(duration * sample_rate)
    num_samples = len(samples)

    # Harp notes (pentatonic scale across octaves)
    notes = []
    base_notes = [262, 294, 330, 392, 440]  # C D E G A
    for octave in range(3):
        for note in base_notes:
            notes.append(note * (2 ** octave))

    gliss_interval = 4.0  # seconds between glissandos
    note_gap = 0.08  # seconds between notes

    t = 0
    while t < duration:
        # Ascending or descending
        note_list = notes if random.random() > 0.5 else notes[::-1]

        for note_idx, freq in enumerate(note_list[:12]):  # Use 12 notes
            note_start = int((t + note_idx * note_gap) * sample_rate)
            note_duration = 0.8
            note_samples = int(note_duration * sample_rate)

            for j in range(note_samples):
                pos = note_start + j
                if pos < num_samples:
                    phase = j / note_samples
                    env = math.exp(-phase * 4) * (1 - math.exp(-phase * 80))

                    value = env * volume * (
                        0.5 * math.sin(2 * math.pi * freq * j / sample_rate) +
                        0.3 * math.sin(2 * math.pi * freq * 2 * j / sample_rate) +
                        0.15 * math.sin(2 * math.pi * freq * 3 * j / sample_rate)
                    )
                    samples[pos] += value

        t += gliss_interval

    return samples

def generate_ethereal_choir(duration, volume=0.15, sample_rate=SAMPLE_RATE):
    """Generate ethereal choir-like pad"""
    samples = []
    num_samples = int(duration * sample_rate)

    # Choir vowel formants (simplified)
    base_freq = 220  # A3

    for i in range(num_samples):
        t = i / sample_rate

        # Slow envelope
        env = min(1.0, t / 4.0) * min(1.0, (duration - t) / 4.0)

        # Vibrato
        vibrato = 1 + 0.02 * math.sin(2 * math.pi * 5 * t)

        # Multiple voices with slight detuning
        value = 0
        for voice in range(4):
            detune = 1 + 0.01 * (voice - 1.5)
            voice_freq = base_freq * vibrato * detune

            # Formant-like filtering (simplified)
            for harmonic in range(1, 8):
                harmonic_amp = math.exp(-harmonic * 0.3) * (1 + 0.3 * math.sin(harmonic * 0.5))
                value += harmonic_amp * 0.1 * math.sin(2 * math.pi * voice_freq * harmonic * t)

        samples.append(env * volume * value)

    return samples

def generate_crystal_bowls(duration, volume=0.2, sample_rate=SAMPLE_RATE):
    """Generate crystal singing bowl sounds"""
    samples = [0] * int(duration * sample_rate)
    num_samples = len(samples)

    # Bowl frequencies (based on chakra bowls)
    bowls = [256, 288, 320, 341, 384, 427, 480]

    strike_interval = 6.0  # seconds
    t = 0

    while t < duration:
        freq = random.choice(bowls)
        strike_pos = int(t * sample_rate)
        sustain_duration = 5.0
        sustain_samples = int(sustain_duration * sample_rate)

        for j in range(sustain_samples):
            pos = strike_pos + j
            if pos < num_samples:
                phase = j / sustain_samples
                # Long decay with slight wobble
                env = math.exp(-phase * 0.5) * (0.9 + 0.1 * math.sin(2 * math.pi * 3 * phase))

                # Pure tone with subtle harmonics
                value = env * volume * (
                    0.7 * math.sin(2 * math.pi * freq * j / sample_rate) +
                    0.2 * math.sin(2 * math.pi * freq * 2 * j / sample_rate) +
                    0.1 * math.sin(2 * math.pi * freq * 3 * j / sample_rate)
                )
                samples[pos] += value

        t += strike_interval

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
    print("EXTENDED AUDIO GENERATOR")
    print("=" * 60)

    # More varied track types
    track_configs = [
        # Meditation/Ambient (60 tracks)
        (generate_soft_pad, 120, "ambient", 20, "soft_pad"),
        (generate_ambient_drone, 120, "ambient", 20, "drone"),
        (generate_ethereal_choir, 120, "ambient", 20, "choir"),

        # Musical (60 tracks)
        (generate_dreamy_arp, 120, "lullabies", 15, "dreamy_arp"),
        (generate_gentle_bells, 120, "lullabies", 15, "bells"),
        (generate_soft_guitar, 120, "lullabies", 15, "soft_guitar"),
        (generate_harp_glissando, 120, "lullabies", 15, "harp"),

        # Meditation bowls (40 tracks)
        (generate_crystal_bowls, 120, "ambient", 20, "crystal_bowl"),
    ]

    total = 0

    for gen_func, duration, category, count, prefix in track_configs:
        print(f"\nGenerating {count} {prefix} tracks...")
        cat_dir = os.path.join(OUTPUT_DIR, category)
        os.makedirs(cat_dir, exist_ok=True)

        for i in range(count):
            filename = f"{prefix}_{i+1:03d}.wav"
            filepath = os.path.join(cat_dir, filename)

            if os.path.exists(filepath) and os.path.getsize(filepath) > 10000:
                print(f"  [SKIP] {filename}")
                total += 1
                continue

            try:
                # Variations
                if "pad" in prefix:
                    samples = gen_func(duration, root_freq=110 + random.randint(0, 220))
                elif "drone" in prefix:
                    samples = gen_func(duration, base_freq=55 + random.randint(0, 55))
                else:
                    samples = gen_func(duration)

                save_wav(samples, filepath)
                size_kb = os.path.getsize(filepath) / 1024
                print(f"  [OK] {filename} ({size_kb:.1f} KB)")
                total += 1

            except Exception as e:
                print(f"  [FAIL] {filename}: {e}")

    print(f"\n{'='*60}")
    print(f"Generated: {total} extended tracks")
    print("=" * 60)

if __name__ == "__main__":
    main()
