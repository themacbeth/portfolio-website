# THE VEIL

*Laser Projection · Trippy Star Show · Immersive Ceremony*
A Macbeth installation. The embodied counterpart to [KOLOB](https://macbeth.gallery/kolob/).

---

## Concept

A 10-minute immersive audio-visual ceremony performed in darkness. Visitors walk an axis defined by three large hanging fabric veils, each veil representing a stage in the journey of the soul through the kingdoms of the heavens — *telestial, terrestrial, celestial*. A single laser fires from the front of the room and paints continuous-stroke glyphs and constellations onto each veil in sequence. Behind the third (celestial) veil stands a 3-meter LED column, the only physical light source in the room — a sealed luminous body glimpsed through the sheerest fabric, fully revealed only at the climax.

The work translates the digital cosmology of Macbeth's on-chain Kolob project (144 worlds, 15 sealed at the core, three kingdoms) into a physical ritual using laser, fabric, and volumetric LED.

---

## Architecture & Layout

Long narrow vaulted room (Glitch Marfa / Crowley Theater Annex scale):

```
ENTRY                                                             BACK WALL
  │                                                                   │
 [L]──>  ░░░░░░░  ──>  ▒▒▒▒▒▒▒  ──>  ▓▓▓▓▓▓▓  ──>  ▐█▌
laser    veil 1         veil 2         veil 3       LED column
        TELESTIAL    TERRESTRIAL    CELESTIAL       (celestial core)
         (dense)       (medium)       (sheer)        IBW-P-62.5
```

- **Room**: ~18 ft × 40 ft × 16 ft (vaulted to ~21 ft at ridge)
- **Veil dimensions**: each 10 ft wide × 13 ft tall (≈3 m × 4 m)
- **Veil opacities**: 0.55 → 0.38 → 0.20 (cool blue → cool blue → warm gold tint)
- **Veil spacing**: ~11 ft / 11 ft / 9 ft along procession axis
- **Laser position**: 7.5 ft high, on axis with veil mid-line
- **LED column**: ~4 ft behind the celestial veil, centered, top-mounted with 4 suspension cables to the ridge
- **Center aisle**: red rug, ~5 ft wide, full room length
- **Speakers**: 4 corners, flown at ~10 ft, angled toward room center
- **Viewers**: enter at the front, walk the center aisle. The veils are full-width — there is no "around." The ceremony ends at the celestial veil.

---

## Hardware

| Component | Spec |
|---|---|
| Laser | Diode 3000 Nova · ShowNET protocol |
| LED Column | **IBW-P-62.5** 3D volumetric display · 0.5 m × 3 m × 0.5 m · 8 × 48 × 8 voxels (3,072 voxels total) · 370 W · Art-Net4 / sACN / SD Card · Madrix + TouchDesigner support · ~$2,786 + freight |
| Signal | TouchDesigner → ShowNET (laser) + Art-Net4 (LED) from one show file, one clock |
| Audio | 4 corner-flown speakers, sub optional |
| Venue | Glitch Marfa · Crowley Theater · [Crowley Theater Addition Annex](https://arquitecturaviva.com/works/ampliacion-del-teatro-crowley-3) |

The whole rig runs from one TouchDesigner network. A single timecode drives the laser galvo points, the LED voxel frame, and the audio cues, so registration between layers is exact.

---

## Visual Program — Two Vocabularies

### LASER GLYPHS (on the fabric veils)

Single-color continuous-stroke vector art drawn through the veils. The laser's vocabulary thins as the viewer moves deeper:

**Telestial veil** — busy, cosmic primitives
- Concentric rings expanding outward
- Twelve dots flashing around a circle (the twelve governing systems)
- Three rotating triangles (the three great suns)
- Logarithmic spiral unwinding (one revolution = one millennium)
- Sundial tick-fills

**Terrestrial veil** — fewer elements, held longer
- All-Seeing Eye (almond + pupil)
- Compass mark Λ + Square mark L, interlocking
- Cupped hand silhouette (offering / receiving)
- Sun glyph (circle + rays)
- Five-points-of-fellowship (5 vertical dots, then connecting line)

**Celestial veil** — sparse, often a single element
- A held dot (Kolob, the tonic)
- A single invented seal (the new name)
- The veil-rending horizontal line splitting and pulling apart

### LED COLUMN (the celestial reveal)

Volumetric 3D imagery in the 8 × 48 × 8 voxel grid. Only fully visible after the viewer has passed the second veil and the celestial veil parts (visually) at the climax. Runs a 4-minute beat-synced program:

| Time | Scene | Character |
|---|---|---|
| 0:00–0:30 | **CREATION** — Pillar of Cloud | slow drifting white volumetric noise |
| 0:30–0:55 | **KOLOB** — the governing star | bright golden core throbbing with the kick |
| 0:55–1:25 | **144 WORLDS · 15 SEALED** | particle field, 15 brighter cluster at center |
| 1:25–1:53 | **THREE GREAT SUNS** | 3 orbiting orbs at 3 heights, polyrhythmic flashing |
| 1:53–2:21 | **TWELVE GOVERNING SYSTEMS** | helix of 12 voxel clusters, one lights per beat |
| 2:21–2:45 | **TIME COLLAPSE** — one Kolob day | particles converge to a single point over the scene |
| 2:45–3:07 | **JACOB'S LADDER** | rising rungs of light, one per beat |
| 3:07–3:31 | **STANDING FIGURE OF LIGHT** | barely-resolved humanoid silhouette, heartbeat-pulsed |
| 3:31–3:53 | **PILLAR OF FIRE** — climax | turbulent flame, white-hot blast every phrase |
| 3:53–4:00 | **HOLD** — Kolob alone | a single bright voxel breathing at column center |

Cross-fades between scenes are per-voxel color interpolations over 2.6 sec. Spill light color and intensity interpolate too, so the room shifts hue with the column.

---

## Audio Program

A drone-hymnal score at **66 BPM**, generated live (synthesized in WebAudio for the mockup; production version would be a pre-rendered composition in the same idiom):

| Layer | Description |
|---|---|
| **Sub-bass kick** | sine 95→38 Hz with triangle click transient. Hits every beat. Accent on the 1 of each bar. |
| **Drone pad** | 3–4 detuned saw waves + sub-octave sine, lowpass filter 380 Hz with Q 1.2. LFO on cutoff cycles every 8 bars (the swell). |
| **Bell** | inharmonic 4-partial sine (ratios 1, 2.01, 3.02, 4.21), 3-sec exponential decay. Fires on bar-1 of dramatic scenes. |
| **Reverb** | 2.6 sec convolver with HF-damped synthetic IR — "distant source / large bathroom" character |
| **Master bus** | compressor (threshold -14, ratio 3) |

Chord progression per scene — all in minor / Dorian / sus voicings, slow, suspended:

| Scene | Voicing |
|---|---|
| Cloud | D — A — D (open fifth) |
| Kolob | D — A — F — D5 (Dm + high octave) |
| 144 Worlds | A — E — A |
| Three Suns | D — F — A — D (Dm) |
| Twelve | F — A — C — F |
| Time Collapse | D — F — G — Db (tense) |
| Jacob's Ladder | G — B — D |
| Standing Figure | G — B — D — G (G major — resolution) |
| Pillar of Fire | D — F — A — Db (dramatic) |
| Hold Kolob | D — A (back to open fifth) |

The chord changes at every scene boundary. The viewer's body keeps time with the kick without realizing it.

---

## Audience Experience

1. Enter through a single door at the front. Room is dark; only the laser confirms it's on.
2. **Telestial** — laser is busy, drawing constellations onto the first veil. The viewer is at the edge of the cosmos.
3. **Pass behind veil 1** (10–15 sec walk). Laser glyphs simplify.
4. **Terrestrial** — endowment marks appear on the second veil. The All-Seeing Eye holds. Audio thickens.
5. **Pass behind veil 2.** Through the gauze of veil 3 the viewer first glimpses the LED column glowing faintly behind it.
6. **Celestial** — laser pares back to almost nothing. The veil hold. The LED column behind it ignites: Three Great Suns → Twelve → Time Collapse → Standing Figure → Pillar of Fire.
7. **Climax** — phrase blast white-hot up the column. Camera-equivalent moment of awe.
8. **Hold** — everything else cuts. One bright gold voxel at column center breathes once per bar for 7 seconds. End.

Total run: ~10 minutes. The procession itself is the artwork; the column is the destination but never *reached* — the third veil is the threshold and remains intact.

---

## The Kolob Connection

Kolob is the on-chain Macbeth project — a generative galaxy on Art Blocks. The number system, the kingdoms hierarchy, the sealed core, the throne-of-Kolob axis-mundi: all of it carries over directly. The Veil is the physical / ritual translation:

- Kolob's **129 thrones** ↔ the visitor as the 130th, walking the procession
- Kolob's **15 sealed at the core** ↔ the LED column's brightest cluster at column center
- Kolob's **three kingdoms** ↔ the three veils, by opacity and color temperature
- Kolob's **Kolob star** ↔ the final-hold voxel: one point of gold light, breathing

What the chain draws as pixels, the laser and LED column draw as light.

---

## Mockup Files (this project folder)

| File | Purpose |
|---|---|
| `index.html` | Main project page — public-facing |
| `glitch_marfa_veils_led_reveal.html` | The room: 3 veils + laser + LED column, with figures for scale |
| `led_column_show.html` | Standalone 4-minute LED column program, beat-synced with live synth score |
| `visuals_gallery.html` | 31 live thumbnails of every laser-glyph and LED-column state under consideration |
| `glitch_marfa_3veils.html` | Original 3-veil mockup (single laser, no LED) |
| `glitch_marfa_3veils_2lasers.html` | Variant: lasers at both ends, cross-beam |
| `glitch_marfa_3veils_stacked.html` | Variant: two lasers stacked at front |
| `glitch_marfa_led_volume.html` | Variant: full LED voxel volume filling the room |
| `glitch_marfa_led_registration.html` | Technical spec: how a laser galvo maps to specific LEDs via 4-point homography |
| `laser_traces.html` | Three side-by-side panels showing laser tracing Kolob galaxy/sun/core |
| `laser_throw_diagram.html` | Throw chart for the single laser through the three veils |
| `3D dsplay (2).pdf` | IBW-P-62.5 vendor datasheet from ShenZhen ibestwork |

---

## Open Questions / Next Steps

1. **Audio** — currently synthesized in WebAudio for the mockup. Production needs either a recorded composition in this idiom (preferred — performed by a real player), or a more refined synthesis layer with bowed strings / male choir samples.
2. **Veil hanging mechanism** — current mockup assumes rigging from ceiling rafters. Need site survey at Glitch Marfa to confirm load capacity and exact mount points.
3. **Eye safety** — laser at 7.5 ft is above standing eye-line, but viewers in the aisle could still encounter scattered light. Class 3R diffused recommended. Audience fenced from direct beam path.
4. **LED column delivery** — IBW-P-62.5 is a Shenzhen build, 45-day sea freight + duty / brokerage. Order ≥10 weeks before install. Consider sourcing a demo unit first for laser-on-LED registration testing.
5. **Floor treatment** — concrete reads cold. The red rug down the aisle solves the visual but a permanent install would want acoustic absorption on the floor too.

---

*macbeth.gallery / project-veil*
