import os
import math
import wave
import struct

SAMPLE_RATE = 44100

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)

def write_wav(filepath, samples, sample_rate=SAMPLE_RATE):
    # Clamp samples to [-1.0, 1.0] and convert to 16-bit PCM
    raw_data = bytearray()
    for s in samples:
        s_clamped = max(-1.0, min(1.0, s))
        val = int(s_clamped * 32767.0)
        raw_data.extend(struct.pack('<h', val))
    
    with wave.open(filepath, 'wb') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(sample_rate)
        wav_file.writeframes(raw_data)
    print(f"Generated {filepath} ({len(samples)/sample_rate:.2f}s, {len(raw_data)} bytes)")

def generate_sfx_correct():
    # Bronze Drum (Dong Son) + Regal Bronze Bell Chime
    # Duration: 1.2s
    duration = 1.25
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    
    # 1. Low bronze drum strike (membrane + bronze body modes)
    drum_f0 = 92.0
    # Bronze drum non-harmonic ratios
    drum_modes = [
        (1.0, 0.45, 12.0),
        (1.58, 0.25, 16.0),
        (2.13, 0.18, 20.0),
        (2.92, 0.12, 25.0),
        (3.50, 0.08, 30.0),
    ]
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        val = 0.0
        
        # Drum body
        for ratio, amp, decay in drum_modes:
            freq = drum_f0 * ratio
            env = math.exp(-decay * t)
            val += amp * env * math.sin(2 * math.pi * freq * t)
        
        # Initial strike transient (click)
        if t < 0.02:
            strike = (1.0 - t / 0.02) * (math.sin(2 * math.pi * 440 * t) * 0.3)
            val += strike
            
        # 2. Regal chime (Pentatonic G5 + D6 resonance)
        # Chime begins at t=0.03 for a layered triumph feel
        if t >= 0.02:
            tc = t - 0.02
            chime_env = math.exp(-3.5 * tc)
            chime_f1 = 783.99  # G5
            chime_f2 = 1174.66 # D6
            chime_f3 = 1567.98 # G6
            chime = (
                0.35 * math.sin(2 * math.pi * chime_f1 * tc) +
                0.20 * math.sin(2 * math.pi * chime_f2 * tc) +
                0.12 * math.sin(2 * math.pi * chime_f3 * tc)
            ) * chime_env
            val += chime
            
        samples[i] = val * 0.85
        
    return samples

def generate_sfx_wrong():
    # Soft, warm woodblock (mộc gõ) - two quiet wooden knocks
    duration = 0.35
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    
    def wood_tap(t, delay, pitch):
        if t < delay:
            return 0.0
        dt = t - delay
        env = math.exp(-38.0 * dt)
        # Hollow wood resonance: fundamental + fast decaying cavity resonance
        w = (
            0.6 * math.sin(2 * math.pi * pitch * dt) +
            0.3 * math.sin(2 * math.pi * (pitch * 2.15) * dt) +
            0.15 * math.sin(2 * math.pi * (pitch * 3.4) * dt)
        )
        return env * w
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        v = wood_tap(t, 0.0, 310.0) + wood_tap(t, 0.09, 230.0) * 0.75
        samples[i] = v * 0.75
        
    return samples

def generate_sfx_tap():
    # Light bamboo tile / thẻ bài click
    duration = 0.12
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-70.0 * t)
        v = (
            0.55 * math.sin(2 * math.pi * 1280.0 * t) +
            0.35 * math.sin(2 * math.pi * 2100.0 * t) +
            0.15 * math.sin(2 * math.pi * 3200.0 * t)
        ) * env
        samples[i] = v * 0.7
        
    return samples

def generate_sfx_streak_up():
    # Rising pentatonic cascade (C5, D5, F5, G5, A5, C6)
    duration = 0.95
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    
    scale_notes = [523.25, 587.33, 698.46, 783.99, 880.00, 1046.50]
    note_delay = 0.08
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        val = 0.0
        for idx, freq in enumerate(scale_notes):
            t_note = t - (idx * note_delay)
            if t_note >= 0:
                # Bell chime note
                decay_rate = 6.0 if idx < len(scale_notes) - 1 else 3.0
                env = math.exp(-decay_rate * t_note)
                chime = (
                    0.25 * math.sin(2 * math.pi * freq * t_note) +
                    0.12 * math.sin(2 * math.pi * (freq * 2.0) * t_note) +
                    0.06 * math.sin(2 * math.pi * (freq * 3.0) * t_note)
                ) * env
                val += chime
        samples[i] = val * 0.8
        
    return samples

def generate_sfx_chest_open():
    # Golden chest open: brass latch click + upward shimmering arpeggio + grand chord
    duration = 1.6
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        val = 0.0
        
        # 1. Brass lock click at t=0.0 to 0.05
        if t < 0.06:
            click_env = math.exp(-80.0 * t)
            val += 0.4 * math.sin(2 * math.pi * 1800.0 * t) * click_env
            
        # 2. Golden sparkle sweep
        if t >= 0.05:
            ts = t - 0.05
            sweep_freq = 440.0 + 880.0 * (ts / 0.6 if ts < 0.6 else 1.0)
            tremolo = 1.0 + 0.25 * math.sin(2 * math.pi * 14.0 * ts)
            shimmer_env = math.exp(-2.2 * ts) if ts > 0.4 else (ts / 0.4)
            val += 0.22 * math.sin(2 * math.pi * sweep_freq * ts) * tremolo * shimmer_env
            
        # 3. Final majestic chord at t=0.4
        if t >= 0.38:
            tc = t - 0.38
            chord_env = math.exp(-2.5 * tc)
            chord = (
                0.25 * math.sin(2 * math.pi * 523.25 * tc) + # C5
                0.20 * math.sin(2 * math.pi * 659.25 * tc) + # E5
                0.20 * math.sin(2 * math.pi * 783.99 * tc) + # G5
                0.22 * math.sin(2 * math.pi * 1046.50 * tc)  # C6
            ) * chord_env
            val += chord
            
        samples[i] = val * 0.8
        
    return samples

def generate_narration_sample():
    # Historical narration audio: Vietnamese traditional zither (Đàn Tranh) meditative melody
    # + ambient resonant tone representing the historical recitation passage (duration: ~8.5s)
    duration = 8.5
    total_samples = int(duration * SAMPLE_RATE)
    samples = [0.0] * total_samples
    
    # Gentle Dan Tranh pentatonic sequence
    # Melodic notes: G4, A4, C5, D5, E5, G5, A5, C6
    notes = [
        (0.0, 392.00, 1.8),   # G4
        (0.8, 440.00, 1.6),   # A4
        (1.6, 523.25, 2.2),   # C5
        (2.6, 587.33, 1.8),   # D5
        (3.4, 659.25, 2.0),   # E5
        (4.4, 783.99, 2.4),   # G5
        (5.4, 659.25, 1.8),   # E5
        (6.2, 523.25, 2.5),   # C5
    ]
    
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        val = 0.0
        
        for start_t, freq, note_dur in notes:
            if start_t <= t < start_t + note_dur:
                tn = t - start_t
                # Dan tranh envelope: quick pluck, lingering singing string
                env = math.exp(-1.8 * tn)
                # Vibrato
                vib = 1.0 + 0.008 * math.sin(2 * math.pi * 5.5 * tn)
                plucked = (
                    0.30 * math.sin(2 * math.pi * freq * vib * tn) +
                    0.15 * math.sin(2 * math.pi * (freq * 2.0) * vib * tn) +
                    0.08 * math.sin(2 * math.pi * (freq * 3.0) * vib * tn) +
                    0.04 * math.sin(2 * math.pi * (freq * 4.0) * vib * tn)
                ) * env
                val += plucked
                
        # Subtle ambient river & breeze tone
        ambient = 0.03 * math.sin(2 * math.pi * 110.0 * t) * (1.0 + 0.3 * math.sin(2 * math.pi * 0.25 * t))
        val += ambient
        
        # Master fade in & out
        master_env = 1.0
        if t < 0.2:
            master_env = t / 0.2
        elif t > duration - 0.5:
            master_env = (duration - t) / 0.5
            
        samples[i] = val * master_env * 0.8
        
    return samples

def main():
    target_dir = os.path.join(os.path.dirname(__file__), '..', 'assets', 'audio')
    ensure_dir(target_dir)
    
    print(f"Generating audio assets in {target_dir}...")
    
    write_wav(os.path.join(target_dir, 'sfx_correct.wav'), generate_sfx_correct())
    write_wav(os.path.join(target_dir, 'sfx_wrong.wav'), generate_sfx_wrong())
    write_wav(os.path.join(target_dir, 'sfx_tap.wav'), generate_sfx_tap())
    write_wav(os.path.join(target_dir, 'sfx_streak_up.wav'), generate_sfx_streak_up())
    write_wav(os.path.join(target_dir, 'sfx_chest_open.wav'), generate_sfx_chest_open())
    write_wav(os.path.join(target_dir, 'narration_bach_dang.wav'), generate_narration_sample())
    
    print("All audio assets generated successfully!")

if __name__ == '__main__':
    main()
