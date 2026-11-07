<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

The design plays the Nyan Cat loop as a square wave and repeats it forever.

- **Tempo:** a single 24-bit counter keeps track of the song position. Its top 8 bits select one of 256 eighth-note
  slots, and the bottom 16 bits count the clocks within a slot. At 1.24 MHz one slot is 2^16 clocks (about 53 ms).
- **Song ROM:** the loop is A, A', B, B. Only A and B are stored (128 slots × 4 bits). A' reuses A with its final
  note changed. Each slot holds a code: hold the previous note, rest, or one of 12 pitches.
- **Tone generator:** a 10-bit down-counter reloads with the note's half period, which gives a square wave within
  about 1 cent of equal temperament. Every new note starts with a short silent gap (about 3.3 ms), so repeated
  notes are heard separately.
- **Output:** the wave drives `uo[0]` and its complement drives `uo[1]`. A piezo wired between those two pins
  sees a 2 × VDD peak-to-peak swing. During silence both pins are low, so no DC voltage sits across the piezo.

The note ROM and pitch table are generated from the reference model in `model/nyan.py`.

## How to test

1. Set the clock to **1.24 MHz** and reset the design. The song starts at once.
2. `ui[0]` pauses (freezes and mutes). `ui[2:1]` plays 0–3 octaves lower. `ui[3]` fast-forwards at 8× speed.
3. `uo[2]` lights while a note is sounding. `uo[6:3]` shows the current note code. `uo[7]` toggles on every
   eighth note.

Other clock rates also work: pitch and tempo both scale with the clock.

## External hardware

A passive piezo buzzer connected between `uo[0]` and `uo[1]`. No amplifier is needed. Do not connect a
low-impedance speaker directly to the pins.
