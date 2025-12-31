#!/usr/bin/env python3
"""
Generate EXTRA Audio Tracks - More baby sounds and variations
Creates additional synthesized audio to reach 500+ target
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

def generate_pink_noise(duration, volume=0.3, sample_rate=SAMPLE_RATE):
    """Generate pink noise (1/f noise) - very soothing for babies"""
    samples = []
    num_samples = int(duration * sample_rate)

    # Pink noise algorithm using multiple octaves
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0

    for i in range(num_samples):
        white = random.random() * 2 - 1

        b0 = 0.99886 * b0 + white * 0.0555179
        b1 = 0.99332 * b1 + white * 0.0750759
        b2 = 0.96900 * b2 + white * 0.1538520
        b3 = 0.86650 * b3 + white * 0.3104856
        b4 = 0.55000 * b4 + white * 0.5329522
        b5 = -0.7616 * b5 - white * 0.0168980

        pink = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362
        b6 = white * 0.115926

        samples.append(pink * volume * 0.11)

    return samples

def generate_brown_noise(duration, volume=0.3, sample_rate=SAMPLE_RATE):
    """Generate brown noise (random walk) - deep rumble"""
    samples = []
    num_samples = int(duration * sample_rate)

    last = 0.0
    for i in range(num_samples):
        white = random.random() * 2 - 1
        last = (last + 0.02 * white) / 1.02
        samples.append(last * volume * 3.5)

    return samples

def generate_binaural_beat(duration, base_freq=200, beat_freq=4, volume=0.25, sample_rate=SAMPLE_RATE):
    """Generate binaural beats for relaxation"""
    left_samples = []
    right_samples = []
    num_samples = int(duration * sample_rate)

    for i in range(num_samples):
        t = i / sample_rate

        # Envelope
        env = min(1.0, t / 3.0) * min(1.0, (duration - t) / 3.0)

        left = env * volume * math.sin(2 * math.pi * base_freq * t)
        right = env * volume * math.sin(2 * math.pi * (base_freq + beat_freq) * t)

        left_samples.append(left)
        right_samples.append(right)

    return left_samples, right_samples

def generate_underwater(duration, volume=0.25, sample_rate=SAMPLE_RATE):
    """Generate underwater/womb-like sounds"""
    samples = []
    num_samples = int(duration * sample_rate)

    for i in range(num_samples):
        t = i / sample_rate

        # Low frequency rumble
        rumble = 0.4 * math.sin(2 * math.pi * 30 * t + 0.5 * math.sin(2 * math.pi * 0.1 * t))

        # Filtered noise
        noise = (random.random() * 2 - 1) * 0.15

        # Occasional bubble sounds
        bubble = 0
        if random.random() < 0.001:
            bubble = 0.3 * math.sin(2 * math.pi * (200 + random.random() * 100) * t)

        # Slow modulation
        mod = 0.8 + 0.2 * math.sin(2 * math.pi * 0.05 * t)

        samples.append((rumble + noise + bubble) * mod * volume)

    return samples

def generate_car_engine(duration, rpm=2000, volume=0.2, sample_rate=SAMPLE_RATE):
    """Generate car engine/road noise - familiar for babies who sleep in cars"""
    samples = []
    num_samples = int(duration * sample_rate)

    base_freq = rpm / 60  # Convert RPM to Hz

    for i in range(num_samples):
        t = i / sample_rate

        # Engine harmonics
        engine = 0
        for harmonic in range(1, 6):
            engine += (0.5 ** harmonic) * math.sin(2 * math.pi * base_freq * harmonic * t)

        # Road noise (filtered white noise)
        road = (random.random() * 2 - 1) * 0.3

        # Low frequency rumble
        rumble = 0.2 * math.sin(2 * math.pi * 20 * t)

        samples.append((engine * 0.3 + road + rumble) * volume)

    return samples

def generate_washing_machine(duration, volume=0.25, sample_rate=SAMPLE_RATE):
    """Generate washing machine sounds"""
    samples = []
    num_samples = int(duration * sample_rate)

    cycle_freq = 0.8  # Slow rotation

    for i in range(num_samples):
        t = i / sample_rate

        # Rotation sound
        rotation = math.sin(2 * math.pi * cycle_freq * t)

        # Motor hum
        motor = 0.3 * math.sin(2 * math.pi * 50 * t)

        # Water slosh
        slosh = 0.2 * math.sin(2 * math.pi * 2 * t) * math.sin(2 * math.pi * 0.3 * t)

        # Gentle rumble
        rumble = (random.random() * 2 - 1) * 0.15

        samples.append((rotation * 0.2 + motor + slosh + rumble) * volume)

    return samples

def generate_dryer(duration, volume=0.25, sample_rate=SAMPLE_RATE):
    """Generate clothes dryer sounds"""
    samples = []
    num_samples = int(duration * sample_rate)

    for i in range(num_samples):
        t = i / sample_rate

        # Tumbling rhythm
        tumble_freq = 0.5
        tumble = 0.3 * abs(math.sin(2 * math.pi * tumble_freq * t))

        # Motor drone
        motor = 0.4 * math.sin(2 * math.pi * 60 * t) + 0.2 * math.sin(2 * math.pi * 120 * t)

        # Air whoosh
        whoosh = (random.random() * 2 - 1) * 0.2 * (0.5 + 0.5 * math.sin(2 * math.pi * tumble_freq * t))

        samples.append((tumble + motor + whoosh) * volume)

    return samples

def generate_hair_dryer(duration, volume=0.3, sample_rate=SAMPLE_RATE):
    """Generate hair dryer white noise"""
    samples = []
    num_samples = int(duration * sample_rate)

    for i in range(num_samples):
        t = i / sample_rate

        # Fan noise (white noise)
        fan = random.random() * 2 - 1

        # Motor whine
        motor = 0.1 * math.sin(2 * math.pi * 400 * t)

        # Low frequency component
        low = 0.15 * math.sin(2 * math.pi * 80 * t)

        samples.append((fan * 0.6 + motor + low) * volume)

    return samples

def generate_air_conditioner(duration, volume=0.25, sample_rate=SAMPLE_RATE):
    """Generate AC/HVAC sounds"""
    samples = []
    num_samples = int(duration * sample_rate)

    for i in range(num_samples):
        t = i / sample_rate

        # Fan noise
        fan = random.random() * 2 - 1

        # Compressor hum
        compressor = 0.2 * math.sin(2 * math.pi * 60 * t)

        # Duct resonance
        duct = 0.1 * math.sin(2 * math.pi * 150 * t)

        # Slow modulation
        mod = 0.95 + 0.05 * math.sin(2 * math.pi * 0.02 * t)

        samples.append((fan * 0.5 + compressor + duct) * mod * volume)

    return samples

def generate_stream(duration, volume=0.25, sample_rate=SAMPLE_RATE):
    """Generate babbling brook/stream sounds"""
    samples = []
    num_samples = int(duration * sample_rate)

    for i in range(num_samples):
        t = i / sample_rate

        # Water flow (filtered noise)
        flow = random.random() * 2 - 1

        # Trickling sounds
        trickle = 0.3 * math.sin(2 * math.pi * (300 + 50 * math.sin(2 * math.pi * 0.5 * t)) * t)

        # Gurgle modulation
        gurgle = 0.7 + 0.3 * math.sin(2 * math.pi * 0.3 * t)

        samples.append((flow * 0.4 + trickle) * gurgle * volume)

    return samples

def generate_thunder_rain(duration, volume=0.3, sample_rate=SAMPLE_RATE):
    """Generate rain with distant thunder"""
    samples = []
    num_samples = int(duration * sample_rate)

    # Pre-calculate thunder positions
    thunder_times = []
    t = 10
    while t < duration - 10:
        thunder_times.append(t)
        t += random.uniform(15, 40)

    for i in range(num_samples):
        t = i / sample_rate

        # Rain (filtered noise)
        rain = random.random() * 2 - 1
        rain_filtered = rain * 0.4

        # Check for thunder
        thunder = 0
        for thunder_time in thunder_times:
            dt = t - thunder_time
            if 0 < dt < 5:
                # Thunder envelope
                thunder_env = math.exp(-dt * 0.5) * (1 - math.exp(-dt * 10))
                thunder += thunder_env * 0.5 * math.sin(2 * math.pi * (30 + 20 * random.random()) * t)

        samples.append((rain_filtered + thunder) * volume)

    return samples

def generate_fireplace(duration, volume=0.25, sample_rate=SAMPLE_RATE):
    """Generate fireplace crackling sounds"""
    samples = []
    num_samples = int(duration * sample_rate)

    for i in range(num_samples):
        t = i / sample_rate

        # Base fire sound
        fire = (random.random() * 2 - 1) * 0.3

        # Low rumble
        rumble = 0.2 * math.sin(2 * math.pi * 50 * t)

        # Occasional crackle
        crackle = 0
        if random.random() < 0.002:
            crackle = random.random() * 0.5

        samples.append((fire + rumble + crackle) * volume)

    return samples

def generate_clock_tick(duration, bpm=60, volume=0.15, sample_rate=SAMPLE_RATE):
    """Generate gentle clock ticking"""
    samples = [0] * int(duration * sample_rate)
    num_samples = len(samples)

    tick_interval = 60 / bpm
    tick_samples = int(tick_interval * sample_rate)

    i = 0
    is_tick = True
    while i < num_samples:
        # Tick or tock
        freq = 2000 if is_tick else 1500
        tick_duration = 0.02
        tick_len = int(tick_duration * sample_rate)

        for j in range(tick_len):
            if i + j < num_samples:
                env = math.exp(-j / (tick_len * 0.2))
                samples[i + j] = env * volume * math.sin(2 * math.pi * freq * j / sample_rate)

        i += tick_samples
        is_tick = not is_tick

    return samples

def generate_purring(duration, volume=0.2, sample_rate=SAMPLE_RATE):
    """Generate cat purring sound"""
    samples = []
    num_samples = int(duration * sample_rate)

    purr_freq = 25  # Cats purr at 25-50 Hz

    for i in range(num_samples):
        t = i / sample_rate

        # Main purr vibration
        purr = math.sin(2 * math.pi * purr_freq * t)

        # Harmonics
        purr += 0.5 * math.sin(2 * math.pi * purr_freq * 2 * t)
        purr += 0.25 * math.sin(2 * math.pi * purr_freq * 3 * t)

        # Breathing modulation
        breath = 0.7 + 0.3 * math.sin(2 * math.pi * 0.25 * t)

        # Slight noise
        noise = random.random() * 0.05

        samples.append((purr * 0.3 + noise) * breath * volume)

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

def save_wav_stereo(left, right, filename, sample_rate=SAMPLE_RATE):
    """Save stereo WAV with different left/right channels"""
    Path(filename).parent.mkdir(parents=True, exist_ok=True)
    left = apply_fade(left.copy())
    right = apply_fade(right.copy())

    max_left = max(abs(min(left)), abs(max(left)), 0.001)
    max_right = max(abs(min(right)), abs(max(right)), 0.001)
    max_val = max(max_left, max_right)

    left = [int(s / max_val * 32767 * 0.9) for s in left]
    right = [int(s / max_val * 32767 * 0.9) for s in right]

    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(CHANNELS)
        wav_file.setsampwidth(SAMPLE_WIDTH)
        wav_file.setframerate(sample_rate)

        for l, r in zip(left, right):
            packed = struct.pack('<hh', l, r)
            wav_file.writeframes(packed)

    return filename

def main():
    print("=" * 60)
    print("EXTRA SOUNDS GENERATOR")
    print("=" * 60)

    track_configs = [
        # More white noise variations (30 tracks)
        (generate_pink_noise, 120, "whitenoise", 15, "pink_noise"),
        (generate_brown_noise, 120, "whitenoise", 15, "brown_noise"),

        # Household sounds (50 tracks) - babies love these!
        (generate_car_engine, 120, "whitenoise", 10, "car_engine"),
        (generate_washing_machine, 120, "whitenoise", 10, "washing"),
        (generate_dryer, 120, "whitenoise", 10, "dryer"),
        (generate_hair_dryer, 120, "whitenoise", 10, "hairdryer"),
        (generate_air_conditioner, 120, "whitenoise", 10, "ac"),

        # Nature sounds (40 tracks)
        (generate_stream, 120, "nature", 15, "stream"),
        (generate_thunder_rain, 120, "nature", 15, "thunder_rain"),
        (generate_fireplace, 120, "nature", 10, "fireplace"),

        # Ambient (40 tracks)
        (generate_underwater, 120, "ambient", 15, "underwater"),
        (generate_purring, 120, "ambient", 15, "purring"),
        (generate_clock_tick, 120, "ambient", 10, "clock"),
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
                if "car_engine" in prefix:
                    samples = gen_func(duration, rpm=1500 + random.randint(0, 1500))
                elif "clock" in prefix:
                    samples = gen_func(duration, bpm=50 + random.randint(0, 30))
                else:
                    samples = gen_func(duration)

                save_wav(samples, filepath)
                size_kb = os.path.getsize(filepath) / 1024
                print(f"  [OK] {filename} ({size_kb:.1f} KB)")
                total += 1

            except Exception as e:
                print(f"  [FAIL] {filename}: {e}")

    # Generate binaural beats (special stereo)
    print("\nGenerating binaural beats...")
    binaural_dir = os.path.join(OUTPUT_DIR, "ambient")
    os.makedirs(binaural_dir, exist_ok=True)

    beat_configs = [
        (200, 2, "delta"),    # Delta waves - deep sleep
        (200, 4, "theta"),    # Theta waves - relaxation
        (200, 8, "alpha"),    # Alpha waves - calm alertness
    ]

    for base, beat, name in beat_configs:
        for i in range(5):
            filename = f"binaural_{name}_{i+1:03d}.wav"
            filepath = os.path.join(binaural_dir, filename)

            if os.path.exists(filepath) and os.path.getsize(filepath) > 10000:
                print(f"  [SKIP] {filename}")
                total += 1
                continue

            try:
                left, right = generate_binaural_beat(120, base + i * 10, beat)
                save_wav_stereo(left, right, filepath)
                size_kb = os.path.getsize(filepath) / 1024
                print(f"  [OK] {filename} ({size_kb:.1f} KB)")
                total += 1
            except Exception as e:
                print(f"  [FAIL] {filename}: {e}")

    print(f"\n{'='*60}")
    print(f"Generated: {total} extra sound tracks")
    print("=" * 60)

if __name__ == "__main__":
    main()
