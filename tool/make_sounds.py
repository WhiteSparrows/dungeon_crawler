"""Génère les bruitages et musiques 8 bits du jeu (originaux, synthétisés ici).

Usage : python tool/make_sounds.py   (écrit dans assets/audio/)
Aucune dépendance : formes d'onde carrée / triangle / bruit + enveloppes.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets', 'audio')
rnd = random.Random(1234)

NOTES = {'C': -9, 'C#': -8, 'D': -7, 'D#': -6, 'E': -5, 'F': -4, 'F#': -3, 'G': -2, 'G#': -1, 'A': 0, 'A#': 1, 'B': 2}


def freq(note):
    """'A4' -> 440 Hz ; None / '-' = silence."""
    if note in (None, '-'):
        return 0.0
    name, octave = note[:-1], int(note[-1])
    return 440.0 * 2 ** ((NOTES[name] + 12 * (octave - 4)) / 12)


def osc(kind, f, t, duty=0.5):
    if f <= 0:
        return 0.0
    ph = (f * t) % 1.0
    if kind == 'square':
        return 1.0 if ph < duty else -1.0
    if kind == 'tri':
        return 4 * abs(ph - 0.5) - 1
    if kind == 'saw':
        return 2 * ph - 1
    if kind == 'noise':
        return rnd.uniform(-1, 1)
    return math.sin(2 * math.pi * ph)


def tone(dur, f0, f1=None, kind='square', vol=0.5, attack=0.005, release=0.05, duty=0.5, vibrato=0.0):
    """Note avec glissando de f0 à f1."""
    n = int(dur * RATE)
    f1 = f0 if f1 is None else f1
    out = []
    phase = 0.0
    for i in range(n):
        t = i / RATE
        k = i / max(1, n - 1)
        f = f0 + (f1 - f0) * k
        if vibrato:
            f *= 1 + vibrato * math.sin(2 * math.pi * 6 * t)
        phase += f / RATE
        env = min(1.0, t / attack) if attack else 1.0
        tail = dur - t
        if tail < release:
            env *= max(0.0, tail / release)
        if kind == 'noise':
            s = rnd.uniform(-1, 1)
        else:
            ph = phase % 1.0
            s = {'square': 1.0 if ph < duty else -1.0, 'tri': 4 * abs(ph - 0.5) - 1, 'saw': 2 * ph - 1,
                 'sine': math.sin(2 * math.pi * ph)}[kind]
        out.append(s * env * vol)
    return out


def seq(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]


def silence(dur):
    return [0.0] * int(dur * RATE)


def write(name, samples, gain=1.0):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + '.wav')
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = min(1.0, 0.9 / peak) * gain
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s * scale)) * 32767)) for s in samples))
    print(f'{path}  {os.path.getsize(path) // 1024} Ko')


def melody(notes, step, kind='square', vol=0.35, duty=0.5, legato=0.9):
    """notes : liste de (note, durée en pas)."""
    out = []
    for note, steps in notes:
        d = step * steps
        f = freq(note)
        if f:
            out.extend(tone(d * legato, f, kind=kind, vol=vol, duty=duty, release=0.03))
            out.extend(silence(d * (1 - legato)))
        else:
            out.extend(silence(d))
    return out


# ------------------------------------------------------------------ bruitages

def sfx():
    write('hit', seq(tone(0.03, 900, 300, 'square', 0.6, duty=0.3), tone(0.05, 300, 120, 'noise', 0.5)))
    write('crit', seq(tone(0.04, 1400, 500, 'square', 0.6, duty=0.25), tone(0.04, 1800, 600, 'square', 0.5),
                      tone(0.09, 400, 80, 'noise', 0.6)))
    write('hurt', seq(tone(0.07, 220, 90, 'saw', 0.6), tone(0.08, 160, 60, 'noise', 0.4)))
    write('kill', seq(tone(0.05, 600, 900, 'square', 0.5), tone(0.06, 900, 1500, 'square', 0.45),
                      tone(0.12, 300, 60, 'noise', 0.35)))
    write('coin', seq(tone(0.05, freq('B5'), kind='square', vol=0.4, duty=0.25),
                      tone(0.14, freq('E6'), kind='square', vol=0.4, duty=0.25, release=0.1)))
    write('pickup', seq(tone(0.05, freq('C5'), kind='tri', vol=0.6), tone(0.05, freq('E5'), kind='tri', vol=0.6),
                        tone(0.09, freq('G5'), kind='tri', vol=0.6)))
    write('potion', seq(*[tone(0.04, 300 + 120 * i, 500 + 120 * i, 'sine', 0.5) for i in range(6)],
                        tone(0.08, 1100, 1300, 'tri', 0.4)))
    write('levelup', seq(*[tone(0.07, freq(n), kind='square', vol=0.4, duty=0.25)
                           for n in ['C5', 'E5', 'G5', 'C6', 'E6', 'G6']], tone(0.25, freq('C7'), kind='square',
                                                                                 vol=0.35, duty=0.25, release=0.2)))
    write('lootbox', seq(tone(0.25, 200, 1200, 'square', 0.3, duty=0.2),
                         mix(tone(0.4, freq('C6'), kind='square', vol=0.3, duty=0.25, release=0.3),
                             tone(0.4, freq('E6'), kind='tri', vol=0.4, release=0.3),
                             tone(0.4, 2000, 300, 'noise', 0.15))))
    write('achievement', melody([('G5', 1), ('C6', 1), ('E6', 1), ('G6', 3)], 0.07, duty=0.25, vol=0.4))
    write('boss', seq(mix(tone(0.6, 70, 55, 'saw', 0.6, vibrato=0.02), tone(0.6, 105, 82, 'square', 0.3)),
                      mix(tone(0.8, 55, 40, 'saw', 0.6, release=0.4), tone(0.8, 200, 50, 'noise', 0.25, release=0.4))))
    write('trap', seq(tone(0.04, 2000, 1500, 'square', 0.4), tone(0.2, 600, 80, 'noise', 0.6)))
    write('stairs', seq(*[tone(0.06, freq(n), kind='tri', vol=0.6) for n in ['G5', 'E5', 'C5', 'G4', 'E4', 'C4']]))
    write('box_gained', melody([('E6', 1), ('G6', 1), ('C7', 2)], 0.05, duty=0.25, vol=0.35))
    write('click', tone(0.025, 1200, 900, 'square', 0.3, duty=0.3))
    write('door', seq(tone(0.08, 120, 80, 'saw', 0.5), tone(0.1, 300, 100, 'noise', 0.3)))
    # Trombone triste « wah wah wah waaah »
    write('death', seq(tone(0.32, freq('D4'), freq('C#4'), 'saw', 0.5, vibrato=0.01),
                       tone(0.32, freq('C#4'), freq('C4'), 'saw', 0.5, vibrato=0.01),
                       tone(0.32, freq('C4'), freq('B3'), 'saw', 0.5, vibrato=0.01),
                       tone(1.0, freq('B3'), freq('A#3'), 'saw', 0.5, vibrato=0.03, release=0.5)))
    write('victory', melody([('C5', 1), ('C5', 1), ('C5', 1), ('C5', 3), ('G#4', 3), ('A#4', 3), ('C5', 2),
                             ('A#4', 1), ('C5', 6)], 0.09, duty=0.25, vol=0.45))
    # Jingle télé de MAESTRO (« ta-da ! »)
    write('jingle', mix(melody([('C5', 1), ('E5', 1), ('G5', 1), ('C6', 4)], 0.08, duty=0.25, vol=0.35),
                        melody([('-', 3), ('G4', 4)], 0.08, kind='tri', vol=0.5)))
    # Foule : applaudissements (bruit en rafales) et rires (glissandos)
    claps = silence(1.2)
    for _ in range(140):
        start = int(rnd.uniform(0, 1.1) * RATE)
        c = tone(0.02, 3000, 1000, 'noise', rnd.uniform(0.2, 0.5))
        for i, s in enumerate(c):
            if start + i < len(claps):
                claps[start + i] += s
    env = [min(1, i / (0.1 * RATE)) * min(1, (len(claps) - i) / (0.4 * RATE)) for i in range(len(claps))]
    write('applause', [s * e for s, e in zip(claps, env)])
    write('laugh', seq(*[tone(0.09, 500 - 30 * i, 380 - 30 * i, 'saw', 0.35, vibrato=0.05) + silence(0.04)
                         for i in range(5)]))
    write('boo', mix(tone(0.9, 180, 140, 'saw', 0.35, vibrato=0.04, release=0.3),
                     tone(0.9, 190, 150, 'saw', 0.3, vibrato=0.05, release=0.3),
                     tone(0.9, 400, 200, 'noise', 0.1, release=0.3)))


# ------------------------------------------------------------------ musiques

def bass_line(roots, step, bars_steps=8):
    out = []
    for r in roots:
        for k in range(bars_steps):
            n = r if k % 2 == 0 else r[:-1] + str(int(r[-1]) + 1)
            out.extend(tone(step * 0.8, freq(n), kind='tri', vol=0.45, release=0.02))
            out.extend(silence(step * 0.2))
    return out


def drums(n_steps, step):
    out = []
    for k in range(n_steps):
        if k % 4 == 0:
            hit = tone(0.06, 150, 50, 'sine', 0.6)
        elif k % 4 == 2:
            hit = tone(0.05, 4000, 2000, 'noise', 0.25)
        else:
            hit = tone(0.02, 8000, 6000, 'noise', 0.08)
        out.extend(hit)
        out.extend(silence(step - len(hit) / RATE))
    return out


def music():
    # Donjon : mineur, un peu inquiétant mais entraînant (boucle de 32 pas x 4)
    step = 0.15
    roots = ['A2', 'A2', 'F2', 'G2'] * 2
    lead = [('A4', 2), ('C5', 2), ('E5', 2), ('D5', 1), ('C5', 1), ('B4', 4), ('G4', 2), ('B4', 2),
            ('F4', 2), ('A4', 2), ('C5', 2), ('B4', 1), ('A4', 1), ('G4', 4), ('E4', 4),
            ('A4', 2), ('C5', 2), ('E5', 2), ('G5', 2), ('F5', 4), ('E5', 2), ('D5', 2),
            ('C5', 2), ('B4', 2), ('A4', 2), ('G4', 2), ('A4', 8)]
    total = len(roots) * 8
    write('music_dungeon', mix(melody(lead, step, duty=0.25, vol=0.22), bass_line(roots, step),
                               drums(total, step)), gain=0.8)

    # Plateau / menu : majeur, sautillant, « émission de télé »
    step = 0.13
    roots = ['C3', 'A2', 'F2', 'G2'] * 2
    lead = [('E5', 1), ('G5', 1), ('C6', 2), ('B5', 1), ('A5', 1), ('G5', 2), ('E5', 2), ('G5', 2), ('A5', 4),
            ('F5', 1), ('A5', 1), ('C6', 2), ('B5', 1), ('A5', 1), ('G5', 4), ('D5', 2), ('E5', 2),
            ('E5', 1), ('G5', 1), ('C6', 2), ('D6', 2), ('E6', 2), ('D6', 1), ('C6', 1), ('A5', 2), ('G5', 2),
            ('F5', 2), ('E5', 2), ('D5', 2), ('G5', 2), ('C5', 12)]
    total = len(roots) * 8
    write('music_show', mix(melody(lead, step, duty=0.125, vol=0.22), bass_line(roots, step),
                            drums(total, step)), gain=0.8)


if __name__ == '__main__':
    sfx()
    music()
