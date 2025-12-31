#!/usr/bin/env python3
"""
Generate Audio Tracks for Baby in Car App
Creates synthesized audio using Python's built-in capabilities
No external dependencies required - uses wave and struct modules
"""

import wave
import struct
import math
import os
import random
from pathlib import Path

OUTPUT_DIR = "/Users/aabyzovext/Projects/AI bussines ideas/AnticryBabyApp/BabyInCarApp/BabyInCarApp/Resources/Audio"

# Audio parameters
SAMPLE_RATE = 44100
CHANNELS = 2  # Stereo
SAMPLE_WIDTH = 2  # 16-bit

def generate_sine_wave(frequency, duration, volume=0.3, sample_rate=SAMPLE_RATE):
    """Generate a sine wave"""
    samples = []
    num_samples = int(duration * sample_rate)
    for i in range(num_samples):
        t = i / sample_rate
        value = volume * math.sin(2 * math.pi * frequency * t)
        samples.append(value)
    return samples

def generate_white_noise(duration, volume=0.1, sample_rate=SAMPLE_RATE):
    """Generate white noise"""
    samples = []
    num_samples = int(duration * sample_rate)
    for _ in range(num_samples):
        value = volume * (random.random() * 2 - 1)
        samples.append(value)
    return samples

def generate_pink_noise(duration, volume=0.1, sample_rate=SAMPLE_RATE):
    """Generate pink noise using Voss-McCartney algorithm"""
    samples = []
    num_samples = int(duration * sample_rate)

    # Pink noise state
    b0, b1, b2, b3, b4, b5, b6 = 0, 0, 0, 0, 0, 0, 0

    for _ in range(num_samples):
        white = random.random() * 2 - 1
        b0 = 0.99886 * b0 + white * 0.0555179
        b1 = 0.99332 * b1 + white * 0.0750759
        b2 = 0.96900 * b2 + white * 0.1538520
        b3 = 0.86650 * b3 + white * 0.3104856
        b4 = 0.55000 * b4 + white * 0.5329522
        b5 = -0.7616 * b5 - white * 0.0168980
        pink = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11
        b6 = white * 0.115926
        samples.append(volume * pink)

    return samples

def generate_brown_noise(duration, volume=0.15, sample_rate=SAMPLE_RATE):
    """Generate brown/red noise"""
    samples = []
    num_samples = int(duration * sample_rate)
    last = 0

    for _ in range(num_samples):
        white = random.random() * 2 - 1
        last = (last + (0.02 * white)) / 1.02
        samples.append(volume * last * 3.5)

    return samples

def generate_heartbeat(duration, bpm=60, volume=0.4, sample_rate=SAMPLE_RATE):
    """Generate heartbeat sound"""
    samples = []
    num_samples = int(duration * sample_rate)
    beat_interval = sample_rate * 60 / bpm

    for i in range(num_samples):
        beat_phase = (i % beat_interval) / beat_interval

        # Two-beat pattern (lub-dub)
        if beat_phase < 0.1:
            # First beat (lub)
            env = math.sin(beat_phase * math.pi / 0.1)
            freq = 40 + 20 * (1 - beat_phase / 0.1)
            value = env * volume * math.sin(2 * math.pi * freq * i / sample_rate)
        elif beat_phase < 0.15:
            value = 0
        elif beat_phase < 0.25:
            # Second beat (dub)
            local_phase = (beat_phase - 0.15) / 0.1
            env = math.sin(local_phase * math.pi)
            freq = 35 + 15 * (1 - local_phase)
            value = env * volume * 0.7 * math.sin(2 * math.pi * freq * i / sample_rate)
        else:
            value = 0

        samples.append(value)

    return samples

def generate_rain(duration, intensity=0.5, volume=0.2, sample_rate=SAMPLE_RATE):
    """Generate rain sound"""
    samples = []
    num_samples = int(duration * sample_rate)

    # Base noise
    base_noise = generate_pink_noise(duration, volume * 0.5, sample_rate)

    # Add raindrop sounds
    drops_per_second = int(50 * intensity)
    drop_positions = sorted(random.sample(range(num_samples), min(drops_per_second * int(duration), num_samples // 100)))

    for i in range(num_samples):
        value = base_noise[i]

        # Add occasional drops
        for drop_pos in drop_positions:
            if drop_pos <= i < drop_pos + 500:
                drop_phase = (i - drop_pos) / 500
                drop_env = math.exp(-drop_phase * 10)
                drop_freq = 2000 + random.random() * 1000
                value += drop_env * volume * 0.3 * math.sin(2 * math.pi * drop_freq * i / sample_rate)

        samples.append(max(-1, min(1, value)))

    return samples

def generate_ocean_waves(duration, volume=0.3, sample_rate=SAMPLE_RATE):
    """Generate ocean wave sounds"""
    samples = []
    num_samples = int(duration * sample_rate)
    wave_period = sample_rate * 8  # 8 second waves

    for i in range(num_samples):
        # Wave envelope
        wave_phase = (i % wave_period) / wave_period
        envelope = 0.3 + 0.7 * (0.5 + 0.5 * math.sin(2 * math.pi * wave_phase - math.pi/2))

        # Pink noise base
        white = random.random() * 2 - 1

        # Low frequency modulation
        low_mod = 0.5 + 0.5 * math.sin(2 * math.pi * 0.1 * i / sample_rate)

        value = envelope * volume * white * low_mod
        samples.append(value)

    return samples

def generate_wind(duration, volume=0.2, sample_rate=SAMPLE_RATE):
    """Generate wind sound"""
    samples = []
    num_samples = int(duration * sample_rate)

    # Low-pass filtered noise with slow modulation
    last = 0
    alpha = 0.01  # Low-pass filter coefficient

    for i in range(num_samples):
        # Slow intensity modulation
        mod = 0.5 + 0.5 * math.sin(2 * math.pi * 0.05 * i / sample_rate)
        mod *= 0.7 + 0.3 * math.sin(2 * math.pi * 0.02 * i / sample_rate)

        white = random.random() * 2 - 1
        last = alpha * white + (1 - alpha) * last

        samples.append(volume * mod * last * 10)

    return samples

def generate_crickets(duration, volume=0.15, sample_rate=SAMPLE_RATE):
    """Generate cricket sounds"""
    samples = [0] * int(duration * sample_rate)
    num_samples = len(samples)

    # Multiple crickets at different frequencies
    num_crickets = 5
    for c in range(num_crickets):
        freq = 4000 + random.random() * 2000
        chirp_rate = 3 + random.random() * 2  # chirps per second
        chirp_duration = 0.05 + random.random() * 0.05

        chirp_samples = int(chirp_duration * sample_rate)
        chirp_interval = int(sample_rate / chirp_rate)

        i = random.randint(0, chirp_interval)
        while i < num_samples:
            # Generate chirp
            for j in range(chirp_samples):
                if i + j < num_samples:
                    env = math.sin(math.pi * j / chirp_samples)
                    samples[i + j] += env * volume / num_crickets * math.sin(2 * math.pi * freq * j / sample_rate)

            i += chirp_interval + random.randint(-100, 100)

    return samples

def generate_birds(duration, volume=0.2, sample_rate=SAMPLE_RATE):
    """Generate bird chirping sounds"""
    samples = [0] * int(duration * sample_rate)
    num_samples = len(samples)

    # Multiple birds
    num_birds = 4
    for b in range(num_birds):
        base_freq = 2000 + random.random() * 2000
        calls_per_minute = 10 + random.random() * 20
        call_interval = int(sample_rate * 60 / calls_per_minute)

        i = random.randint(0, call_interval)
        while i < num_samples:
            # Generate bird call (frequency sweep)
            call_duration = 0.1 + random.random() * 0.2
            call_samples = int(call_duration * sample_rate)

            for j in range(call_samples):
                if i + j < num_samples:
                    phase = j / call_samples
                    env = math.sin(math.pi * phase)
                    # Frequency sweep
                    freq = base_freq * (1 + 0.5 * math.sin(phase * math.pi * 3))
                    samples[i + j] += env * volume / num_birds * math.sin(2 * math.pi * freq * j / sample_rate)

            i += call_interval + random.randint(-call_interval//4, call_interval//4)

    return samples

def generate_music_box(duration, volume=0.25, sample_rate=SAMPLE_RATE):
    """Generate music box melody"""
    samples = [0] * int(duration * sample_rate)
    num_samples = len(samples)

    # Simple pentatonic melody notes (frequencies)
    notes = [262, 294, 330, 392, 440, 523, 587, 659]  # C major pentatonic + octave

    note_duration = 0.5  # seconds
    note_samples = int(note_duration * sample_rate)

    i = 0
    while i < num_samples:
        freq = random.choice(notes)

        for j in range(note_samples):
            if i + j < num_samples:
                # Bell-like envelope (quick attack, slow decay)
                phase = j / note_samples
                env = math.exp(-phase * 4) * (1 - math.exp(-phase * 50))

                # Harmonics for bell sound
                value = env * volume * (
                    0.5 * math.sin(2 * math.pi * freq * j / sample_rate) +
                    0.3 * math.sin(2 * math.pi * freq * 2 * j / sample_rate) +
                    0.15 * math.sin(2 * math.pi * freq * 3 * j / sample_rate) +
                    0.05 * math.sin(2 * math.pi * freq * 4 * j / sample_rate)
                )
                samples[i + j] += value

        i += note_samples + random.randint(0, note_samples // 2)

    return samples

def generate_lullaby(duration, volume=0.25, sample_rate=SAMPLE_RATE):
    """Generate simple lullaby melody"""
    samples = [0] * int(duration * sample_rate)
    num_samples = len(samples)

    # Lullaby melody (Twinkle Twinkle pattern)
    melody = [
        (262, 0.5), (262, 0.5), (392, 0.5), (392, 0.5),
        (440, 0.5), (440, 0.5), (392, 1.0),
        (349, 0.5), (349, 0.5), (330, 0.5), (330, 0.5),
        (294, 0.5), (294, 0.5), (262, 1.0),
    ]

    i = 0
    melody_idx = 0

    while i < num_samples:
        freq, dur = melody[melody_idx % len(melody)]
        note_samples = int(dur * sample_rate)

        for j in range(note_samples):
            if i + j < num_samples:
                phase = j / note_samples
                # Soft envelope
                env = math.sin(math.pi * phase) ** 0.5

                # Soft piano-like sound
                value = env * volume * (
                    0.6 * math.sin(2 * math.pi * freq * j / sample_rate) +
                    0.25 * math.sin(2 * math.pi * freq * 2 * j / sample_rate) +
                    0.1 * math.sin(2 * math.pi * freq * 3 * j / sample_rate) +
                    0.05 * math.sin(2 * math.pi * freq * 4 * j / sample_rate)
                )
                samples[i + j] += value

        i += note_samples
        melody_idx += 1

    return samples

def generate_shushing(duration, volume=0.3, sample_rate=SAMPLE_RATE):
    """Generate shushing sound"""
    samples = []
    num_samples = int(duration * sample_rate)
    shush_period = sample_rate * 2  # 2 second cycle

    for i in range(num_samples):
        phase = (i % shush_period) / shush_period

        # Shush envelope
        if phase < 0.4:
            env = math.sin(phase / 0.4 * math.pi / 2)
        elif phase < 0.6:
            env = 1.0
        else:
            env = math.cos((phase - 0.6) / 0.4 * math.pi / 2)

        # Filtered noise
        white = random.random() * 2 - 1
        samples.append(env * volume * white)

    return samples

def generate_womb(duration, volume=0.35, sample_rate=SAMPLE_RATE):
    """Generate womb sounds (low rumble + heartbeat + muffled sounds)"""
    samples = []
    num_samples = int(duration * sample_rate)

    # Get heartbeat
    heartbeat = generate_heartbeat(duration, bpm=72, volume=0.3, sample_rate=sample_rate)

    # Brown noise for rumble
    rumble = generate_brown_noise(duration, volume=0.4, sample_rate=sample_rate)

    for i in range(num_samples):
        # Low frequency modulation (breathing-like)
        breath_mod = 0.8 + 0.2 * math.sin(2 * math.pi * 0.15 * i / sample_rate)

        value = (heartbeat[i] + rumble[i] * breath_mod) * volume
        samples.append(max(-1, min(1, value)))

    return samples

def generate_fan(duration, volume=0.25, sample_rate=SAMPLE_RATE):
    """Generate electric fan sound"""
    samples = []
    num_samples = int(duration * sample_rate)

    # Pink noise with periodic modulation (fan blade rhythm)
    blade_freq = 25  # Hz (fan rotation speed)

    for i in range(num_samples):
        # Base noise
        white = random.random() * 2 - 1

        # Blade modulation
        blade_mod = 0.9 + 0.1 * math.sin(2 * math.pi * blade_freq * i / sample_rate)

        # Low-pass filter
        samples.append(volume * blade_mod * white)

    # Apply simple low-pass
    filtered = []
    alpha = 0.1
    last = 0
    for s in samples:
        last = alpha * s + (1 - alpha) * last
        filtered.append(last * 5)

    return filtered

def generate_vacuum(duration, volume=0.3, sample_rate=SAMPLE_RATE):
    """Generate vacuum cleaner sound"""
    samples = []
    num_samples = int(duration * sample_rate)
    motor_freq = 50  # Hz

    for i in range(num_samples):
        # Motor hum
        motor = 0.3 * math.sin(2 * math.pi * motor_freq * i / sample_rate)
        motor += 0.15 * math.sin(2 * math.pi * motor_freq * 2 * i / sample_rate)

        # Noise component
        noise = (random.random() * 2 - 1) * 0.5

        # Combine
        samples.append(volume * (motor + noise))

    return samples

def apply_fade(samples, fade_in_seconds=0.5, fade_out_seconds=1.0, sample_rate=SAMPLE_RATE):
    """Apply fade in and fade out to samples"""
    fade_in_samples = int(fade_in_seconds * sample_rate)
    fade_out_samples = int(fade_out_seconds * sample_rate)

    for i in range(min(fade_in_samples, len(samples))):
        samples[i] *= i / fade_in_samples

    for i in range(min(fade_out_samples, len(samples))):
        idx = len(samples) - 1 - i
        if idx >= 0:
            samples[idx] *= i / fade_out_samples

    return samples

def save_wav(samples, filename, sample_rate=SAMPLE_RATE):
    """Save samples as WAV file"""
    # Ensure directory exists
    Path(filename).parent.mkdir(parents=True, exist_ok=True)

    # Apply fade
    samples = apply_fade(samples.copy())

    # Convert to 16-bit integers
    max_val = max(abs(min(samples)), abs(max(samples)), 0.001)
    samples = [int(s / max_val * 32767 * 0.9) for s in samples]

    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(CHANNELS)
        wav_file.setsampwidth(SAMPLE_WIDTH)
        wav_file.setframerate(sample_rate)

        for sample in samples:
            # Stereo: write same sample to both channels
            packed = struct.pack('<hh', sample, sample)
            wav_file.writeframes(packed)

    return filename

def main():
    print("=" * 60)
    print("BABY IN CAR - AUDIO GENERATOR")
    print("=" * 60)
    print("")

    # Track configurations: (generator_func, duration_seconds, category, count, name_prefix)
    track_configs = [
        # White/Pink/Brown Noise variations (50 tracks)
        (generate_white_noise, 120, "whitenoise", 15, "white_noise"),
        (generate_pink_noise, 120, "whitenoise", 15, "pink_noise"),
        (generate_brown_noise, 120, "whitenoise", 15, "brown_noise"),

        # Nature sounds (80 tracks)
        (generate_rain, 120, "nature", 20, "rain"),
        (generate_ocean_waves, 120, "nature", 20, "ocean"),
        (generate_wind, 120, "nature", 15, "wind"),
        (generate_crickets, 120, "nature", 15, "crickets"),
        (generate_birds, 120, "nature", 10, "birds"),

        # Baby-specific (80 tracks)
        (generate_heartbeat, 120, "ambient", 20, "heartbeat"),
        (generate_shushing, 120, "ambient", 20, "shushing"),
        (generate_womb, 120, "ambient", 20, "womb"),
        (generate_fan, 120, "ambient", 10, "fan"),
        (generate_vacuum, 120, "ambient", 10, "vacuum"),

        # Music (90 tracks)
        (generate_music_box, 90, "lullabies", 30, "music_box"),
        (generate_lullaby, 90, "lullabies", 30, "lullaby_melody"),
    ]

    total_generated = 0

    for gen_func, duration, category, count, prefix in track_configs:
        print(f"\nGenerating {count} {prefix} tracks...")
        category_dir = os.path.join(OUTPUT_DIR, category)
        os.makedirs(category_dir, exist_ok=True)

        for i in range(count):
            filename = f"{prefix}_{i+1:03d}.wav"
            filepath = os.path.join(category_dir, filename)

            # Skip if exists
            if os.path.exists(filepath) and os.path.getsize(filepath) > 10000:
                print(f"  [SKIP] {filename}")
                total_generated += 1
                continue

            try:
                # Generate with slight variations
                if gen_func == generate_rain:
                    samples = gen_func(duration, intensity=0.3 + random.random() * 0.5)
                elif gen_func == generate_heartbeat:
                    samples = gen_func(duration, bpm=55 + random.randint(0, 25))
                else:
                    samples = gen_func(duration)

                save_wav(samples, filepath)
                size_kb = os.path.getsize(filepath) / 1024
                print(f"  [OK] {filename} ({size_kb:.1f} KB)")
                total_generated += 1

            except Exception as e:
                print(f"  [FAIL] {filename}: {e}")

    print("\n" + "=" * 60)
    print(f"GENERATED: {total_generated} tracks")
    print("=" * 60)

    # Count total files
    total_files = sum(1 for _ in Path(OUTPUT_DIR).rglob("*.wav")) + sum(1 for _ in Path(OUTPUT_DIR).rglob("*.mp3"))
    print(f"Total audio files in library: {total_files}")

if __name__ == "__main__":
    main()
