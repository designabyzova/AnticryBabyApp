#!/usr/bin/env python3
"""
Generate Classical Music Variations
Creates piano, string, and orchestral-style pieces
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

# Musical notes frequencies (equal temperament)
NOTE_FREQS = {
    'C3': 130.81, 'D3': 146.83, 'E3': 164.81, 'F3': 174.61, 'G3': 196.00, 'A3': 220.00, 'B3': 246.94,
    'C4': 261.63, 'D4': 293.66, 'E4': 329.63, 'F4': 349.23, 'G4': 392.00, 'A4': 440.00, 'B4': 493.88,
    'C5': 523.25, 'D5': 587.33, 'E5': 659.25, 'F5': 698.46, 'G5': 783.99, 'A5': 880.00, 'B5': 987.77,
}

# Classic lullaby melodies
TWINKLE_MELODY = [
    ('C4', 0.5), ('C4', 0.5), ('G4', 0.5), ('G4', 0.5), ('A4', 0.5), ('A4', 0.5), ('G4', 1.0),
    ('F4', 0.5), ('F4', 0.5), ('E4', 0.5), ('E4', 0.5), ('D4', 0.5), ('D4', 0.5), ('C4', 1.0),
    ('G4', 0.5), ('G4', 0.5), ('F4', 0.5), ('F4', 0.5), ('E4', 0.5), ('E4', 0.5), ('D4', 1.0),
    ('G4', 0.5), ('G4', 0.5), ('F4', 0.5), ('F4', 0.5), ('E4', 0.5), ('E4', 0.5), ('D4', 1.0),
    ('C4', 0.5), ('C4', 0.5), ('G4', 0.5), ('G4', 0.5), ('A4', 0.5), ('A4', 0.5), ('G4', 1.0),
    ('F4', 0.5), ('F4', 0.5), ('E4', 0.5), ('E4', 0.5), ('D4', 0.5), ('D4', 0.5), ('C4', 1.0),
]

BRAHMS_MELODY = [
    ('G4', 0.75), ('E4', 0.25), ('E4', 0.5), ('G4', 0.75), ('E4', 0.25), ('E4', 0.5),
    ('G4', 0.5), ('C5', 0.5), ('B4', 0.5), ('A4', 0.5), ('G4', 1.0),
    ('F4', 0.75), ('D4', 0.25), ('D4', 0.5), ('F4', 0.75), ('D4', 0.25), ('D4', 0.5),
    ('F4', 0.5), ('B4', 0.5), ('A4', 0.5), ('G4', 0.5), ('F4', 1.0),
]

CLAIR_DE_LUNE_INTRO = [
    ('D4', 1.0), ('F4', 0.5), ('A4', 0.5), ('D5', 1.0),
    ('C5', 0.5), ('A4', 0.5), ('F4', 0.5), ('D4', 0.5),
    ('E4', 1.0), ('G4', 0.5), ('B4', 0.5), ('E5', 1.0),
    ('D5', 0.5), ('B4', 0.5), ('G4', 0.5), ('E4', 0.5),
]

CANON_BASS = [
    ('D3', 2.0), ('A3', 2.0), ('B3', 2.0), ('F3', 2.0),
    ('G3', 2.0), ('D3', 2.0), ('G3', 2.0), ('A3', 2.0),
]

def generate_piano_note(freq, duration, velocity=0.7, sample_rate=SAMPLE_RATE):
    """Generate a piano-like note"""
    samples = []
    num_samples = int(duration * sample_rate)

    for i in range(num_samples):
        t = i / sample_rate
        phase = i / num_samples

        # Piano envelope: quick attack, decay, sustain, release
        if t < 0.01:
            env = t / 0.01
        elif t < 0.1:
            env = 1.0 - 0.3 * (t - 0.01) / 0.09
        elif t < duration - 0.1:
            env = 0.7
        else:
            env = 0.7 * (duration - t) / 0.1

        env *= velocity

        # Piano harmonics
        value = 0
        harmonics = [1.0, 0.5, 0.25, 0.15, 0.1, 0.08, 0.05, 0.03]
        for h, amp in enumerate(harmonics, 1):
            # Slight inharmonicity (characteristic of piano strings)
            h_freq = freq * h * (1 + 0.0002 * h * h)
            # Higher harmonics decay faster
            h_decay = math.exp(-phase * h * 2)
            value += amp * h_decay * math.sin(2 * math.pi * h_freq * t)

        samples.append(env * value)

    return samples

def generate_string_note(freq, duration, velocity=0.5, sample_rate=SAMPLE_RATE):
    """Generate a violin/cello-like sustained note"""
    samples = []
    num_samples = int(duration * sample_rate)

    for i in range(num_samples):
        t = i / sample_rate

        # String envelope: slow attack, sustain, slow release
        attack = min(1.0, t / 0.3)
        release = min(1.0, (duration - t) / 0.5)
        env = attack * release * velocity

        # Vibrato
        vibrato = 1 + 0.01 * math.sin(2 * math.pi * 5.5 * t)

        # String harmonics (odd harmonics stronger)
        value = 0
        for h in range(1, 10):
            amp = 0.5 ** (h - 1) if h % 2 == 1 else 0.3 ** h
            value += amp * math.sin(2 * math.pi * freq * h * vibrato * t)

        samples.append(env * value)

    return samples

def generate_melody_track(melody, generator_func, tempo_bpm=60, volume=0.3, sample_rate=SAMPLE_RATE):
    """Generate a track from a melody definition"""
    beat_duration = 60.0 / tempo_bpm
    total_duration = sum(dur for _, dur in melody) * beat_duration + 2  # +2 for fade out

    samples = [0] * int(total_duration * sample_rate)

    position = 0
    for note, duration in melody:
        if note in NOTE_FREQS:
            freq = NOTE_FREQS[note]
            note_duration = duration * beat_duration
            note_samples = generator_func(freq, note_duration, volume, sample_rate)

            start_idx = int(position * sample_rate)
            for j, s in enumerate(note_samples):
                if start_idx + j < len(samples):
                    samples[start_idx + j] += s

        position += duration * beat_duration

    return samples

def generate_piano_with_bass(melody, bass_notes, tempo_bpm=60, volume=0.3, sample_rate=SAMPLE_RATE):
    """Generate piano melody with bass accompaniment"""
    beat_duration = 60.0 / tempo_bpm
    melody_duration = sum(dur for _, dur in melody) * beat_duration

    # Repeat melody to fill duration
    total_duration = max(melody_duration, 60) + 2
    samples = [0] * int(total_duration * sample_rate)

    # Generate melody (repeating)
    position = 0
    while position < total_duration - 2:
        for note, duration in melody:
            if note in NOTE_FREQS and position < total_duration - 2:
                freq = NOTE_FREQS[note]
                note_duration = duration * beat_duration
                note_samples = generate_piano_note(freq, note_duration, volume, sample_rate)

                start_idx = int(position * sample_rate)
                for j, s in enumerate(note_samples):
                    if start_idx + j < len(samples):
                        samples[start_idx + j] += s

            position += duration * beat_duration

    # Add bass (repeating)
    bass_position = 0
    while bass_position < total_duration - 2:
        for note, duration in bass_notes:
            if note in NOTE_FREQS and bass_position < total_duration - 2:
                freq = NOTE_FREQS[note]
                note_duration = duration * beat_duration
                bass_samples = generate_piano_note(freq, note_duration, volume * 0.6, sample_rate)

                start_idx = int(bass_position * sample_rate)
                for j, s in enumerate(bass_samples):
                    if start_idx + j < len(samples):
                        samples[start_idx + j] += s

            bass_position += duration * beat_duration

    return samples

def generate_string_quartet_piece(duration=120, volume=0.25, sample_rate=SAMPLE_RATE):
    """Generate a simple string quartet-style piece"""
    samples = [0] * int(duration * sample_rate)

    # Chord progression (Am - F - C - G)
    chords = [
        [('A3', 'C4', 'E4', 'A4')],
        [('F3', 'A3', 'C4', 'F4')],
        [('C3', 'E3', 'G3', 'C4')],
        [('G3', 'B3', 'D4', 'G4')],
    ]

    chord_duration = 4.0  # seconds per chord
    position = 0
    chord_idx = 0

    while position < duration - 2:
        chord = chords[chord_idx % len(chords)][0]

        for i, note in enumerate(chord):
            if note in NOTE_FREQS:
                freq = NOTE_FREQS[note]
                # Stagger entries for more natural sound
                entry_delay = i * 0.1
                note_samples = generate_string_note(freq, chord_duration - entry_delay, volume / len(chord), sample_rate)

                start_idx = int((position + entry_delay) * sample_rate)
                for j, s in enumerate(note_samples):
                    if start_idx + j < len(samples):
                        samples[start_idx + j] += s

        position += chord_duration
        chord_idx += 1

    return samples

def generate_nocturne_style(duration=120, volume=0.25, sample_rate=SAMPLE_RATE):
    """Generate Chopin-esque nocturne pattern"""
    samples = [0] * int(duration * sample_rate)

    # Left hand pattern (broken chord)
    lh_pattern = ['C3', 'G3', 'E4', 'G3', 'C3', 'G3', 'E4', 'G3']

    # Right hand melody notes
    rh_notes = ['G4', 'A4', 'B4', 'C5', 'B4', 'A4', 'G4', 'F4', 'E4', 'D4', 'C4']

    beat = 0.25  # quarter note in seconds at tempo
    pattern_duration = len(lh_pattern) * beat

    position = 0
    pattern_count = 0

    while position < duration - 2:
        # Left hand pattern
        for i, note in enumerate(lh_pattern):
            if note in NOTE_FREQS:
                freq = NOTE_FREQS[note]
                note_samples = generate_piano_note(freq, beat * 0.9, volume * 0.4, sample_rate)

                start_idx = int((position + i * beat) * sample_rate)
                for j, s in enumerate(note_samples):
                    if start_idx + j < len(samples):
                        samples[start_idx + j] += s

        # Right hand melody (slower)
        melody_note = rh_notes[pattern_count % len(rh_notes)]
        if melody_note in NOTE_FREQS:
            freq = NOTE_FREQS[melody_note]
            note_samples = generate_piano_note(freq, pattern_duration * 0.8, volume * 0.7, sample_rate)

            start_idx = int(position * sample_rate)
            for j, s in enumerate(note_samples):
                if start_idx + j < len(samples):
                    samples[start_idx + j] += s

        position += pattern_duration
        pattern_count += 1

    return samples

def generate_gymnopedie_style(duration=120, volume=0.25, sample_rate=SAMPLE_RATE):
    """Generate Satie-esque minimalist piece"""
    samples = [0] * int(duration * sample_rate)

    # Slow, sparse melody
    melody = [
        ('D4', 2.0), ('E4', 1.0), ('F4', 1.0), ('D4', 2.0), (None, 2.0),
        ('E4', 2.0), ('D4', 1.0), ('C4', 1.0), ('A3', 2.0), (None, 2.0),
        ('G4', 2.0), ('F4', 1.0), ('E4', 1.0), ('D4', 2.0), (None, 2.0),
    ]

    # Simple bass
    bass = [('D3', 4.0), ('F3', 4.0), ('A3', 4.0), ('D3', 4.0)]

    beat = 0.5  # half note
    position = 0
    melody_idx = 0
    bass_idx = 0
    bass_position = 0

    while position < duration - 2:
        # Melody
        note, dur = melody[melody_idx % len(melody)]
        if note and note in NOTE_FREQS:
            freq = NOTE_FREQS[note]
            note_samples = generate_piano_note(freq, dur * beat * 0.9, volume * 0.7, sample_rate)

            start_idx = int(position * sample_rate)
            for j, s in enumerate(note_samples):
                if start_idx + j < len(samples):
                    samples[start_idx + j] += s

        position += dur * beat
        melody_idx += 1

        # Bass (every few beats)
        if position >= bass_position:
            bass_note, bass_dur = bass[bass_idx % len(bass)]
            if bass_note in NOTE_FREQS:
                freq = NOTE_FREQS[bass_note]
                bass_samples = generate_piano_note(freq, bass_dur * beat * 0.8, volume * 0.4, sample_rate)

                start_idx = int(bass_position * sample_rate)
                for j, s in enumerate(bass_samples):
                    if start_idx + j < len(samples):
                        samples[start_idx + j] += s

            bass_position += bass_dur * beat
            bass_idx += 1

    return samples

def apply_fade(samples, fade_in=0.5, fade_out=2.0, sample_rate=SAMPLE_RATE):
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
    samples = [int(s / max_val * 32767 * 0.85) for s in samples]

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
    print("CLASSICAL MUSIC GENERATOR")
    print("=" * 60)

    classical_dir = os.path.join(OUTPUT_DIR, "classical")
    lullabies_dir = os.path.join(OUTPUT_DIR, "lullabies")
    os.makedirs(classical_dir, exist_ok=True)
    os.makedirs(lullabies_dir, exist_ok=True)

    total = 0
    configs = [
        # Lullabies with piano
        ("twinkle_piano", lullabies_dir, lambda: generate_melody_track(TWINKLE_MELODY, generate_piano_note, 55), 15),
        ("brahms_piano", lullabies_dir, lambda: generate_melody_track(BRAHMS_MELODY, generate_piano_note, 50), 15),

        # Lullabies with strings
        ("twinkle_strings", lullabies_dir, lambda: generate_melody_track(TWINKLE_MELODY, generate_string_note, 50), 15),
        ("brahms_strings", lullabies_dir, lambda: generate_melody_track(BRAHMS_MELODY, generate_string_note, 45), 15),

        # Classical style pieces
        ("nocturne", classical_dir, generate_nocturne_style, 20),
        ("gymnopedie", classical_dir, generate_gymnopedie_style, 20),
        ("string_quartet", classical_dir, generate_string_quartet_piece, 20),

        # Clair de Lune style
        ("impressionist", classical_dir, lambda: generate_melody_track(CLAIR_DE_LUNE_INTRO * 4, generate_piano_note, 45), 15),
    ]

    for prefix, out_dir, gen_func, count in configs:
        print(f"\nGenerating {count} {prefix} tracks...")

        for i in range(count):
            filename = f"{prefix}_{i+1:03d}.wav"
            filepath = os.path.join(out_dir, filename)

            if os.path.exists(filepath) and os.path.getsize(filepath) > 10000:
                print(f"  [SKIP] {filename}")
                total += 1
                continue

            try:
                samples = gen_func()
                save_wav(samples, filepath)
                size_kb = os.path.getsize(filepath) / 1024
                print(f"  [OK] {filename} ({size_kb:.1f} KB)")
                total += 1

            except Exception as e:
                print(f"  [FAIL] {filename}: {e}")

    print(f"\n{'='*60}")
    print(f"Generated: {total} classical tracks")
    print("=" * 60)

if __name__ == "__main__":
    main()
