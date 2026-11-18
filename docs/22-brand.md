# 22. Brand: the mark, the name, the states (phase N7)

Approved by you on 17 November 2026 ("Ok, implement"), after three explorations in Figma. The drawings are on the page "Brand sheet" of the file "Phew interface" (https://www.figma.com/design/GlLT4s5vxGiTuEnqTutghP?node-id=35-3). This file is the same sheet in words and numbers, for the build. The earlier idea of a black chick is closed: there is no chick, no face and no character.

## 22.1 The mark

The top of an eggshell, just lifted, drawn in one heavy line by an uneven hand. Two drawings, both in a box of 120 by 120. The line weight is s = 11, with round joins and round ends.

The mark, from 32 points up:

```
M 26 82 C 23 52 35 20 56 20 C 80 20 97 50 95 82 L 89.42 73.93 Q 86.00 69.00 82.58 73.93 L 80.42 77.07 Q 77.00 82.00 73.56 77.08 L 66.44 66.92 Q 63.00 62.00 59.56 66.92 L 52.44 77.08 Q 49.00 82.00 44.54 77.99 L 43.46 77.01 Q 39.00 73.00 34.07 76.42 L 26.00 82.00 Z
```

The small mark, at 24, 20 and 16 points (two notches):

```
M 26 82 C 23 52 35 20 56 20 C 80 20 97 50 95 82 L 78.18 66.71 Q 73.00 62.00 68.05 66.95 L 57.95 77.05 Q 53.00 82.00 47.66 77.48 L 45.34 75.52 Q 40.00 71.00 34.50 75.32 L 26.00 82.00 Z
```

- Ink of the mark: 80 wide, 73 high (line included). The top of the dome is 4.5 left of the centre. Both feet stand on y = 82.
- Notches of the mark: 13, 20 and 9 deep. The line is 11, so every notch but the smallest is deeper than the line.
- Under 16 points the mark is not used.

## 22.2 The name

Always `phew!`: lowercase, with its exclamation mark. Outfit Medium, letter spacing 0. Outfit is for the name only; all other text in the app stays in the system font. The app does not ship the font: the name is kept as its outline (`Phew/Shell/Brand.swift`), taken from Outfit Medium at 100 points, 255.21 wide and 92 high, baseline at y = 72.

Measures of Outfit Medium at 100 points: small-letter height x = 48, tall letters = 72, stem = 11.

## 22.3 Mark and name together

One unit: x, the small-letter height of the name.

| Form | Rule |
|---|---|
| Beside (the main logo) | Mark 1.04 times the tall letters; its top 2% over their line, its feet 2% under the baseline. Gap 0.8 x. The mark's line equals the letters' stem |
| Stacked | Mark 2 x tall, centred. Gap 0.6 x to the top of the tall letters |
| Clear space | One x on every side |
| Smallest | Beside: name 12 points high, with the small mark. Stacked: 48 points wide |

The shell is never used in place of a letter or of the "!".

## 22.4 Colour

| Name | Value | Use |
|---|---|---|
| Ink | `#141414` | Mark and name on light grounds; ground of the dark app icon |
| Shell white | `#F4EFE6` | The main ground; mark and name on ink |
| White | `#FFFFFF` | Pages and panels |
| Warm grey | `#D9D2C4` | A third ground, for ink only |
| Orange | `#F2541B` (Increase Contrast, light grounds: `#D9440F`) | The active line |

The orange is the active line: the mark itself turns orange while he acts and while a result waits. A mark is ink (or shell white) or orange, never both. The orange is never text and never a field. Contrast: ink on shell white 16 to 1; orange 3.3 to 1 on shell white, 3.6 on white, 4.9 on ink, 2.5 on warm grey (so never orange on warm grey).

In the app, where a surface follows the system's light and dark look, "ink" is the label colour and "shell white" is used only on black (the notch) and in the app icon. The accent token of `docs/15-design.md` 15.4 stays `#F2541B`.

## 22.5 The states

The shell alone carries the state, by its pose, its line and its colour. No dot, tick, badge or other sign is added to the mark; words and counts sit beside it in the interface. The baseline never moves. Lift is 1.5 s. A tip turns the shell about the point (60, 82) of its box.

| State | Pose | Line | Colour (set A) | One colour (set B, menu bar) |
|---|---|---|---|---|
| Resting | down | whole | ink | line |
| Listening | lifted, tipped back 9° | whole | ink | line |
| Thinking | lifted | a gap of 44 in a line of 240 travels round it, once in 1.6 s | ink | line with the gap |
| Acting | lifted | whole | orange | full |
| Pointing | lifted, tipped 10° toward the side, moved 5 that way | whole | orange | full |
| Done | down | full, for 2 seconds, then resting | orange | full, 2 seconds |
| Could not | down, tipped over 16° | broken (dashes 15, gaps 19) | ink | broken line |
| A result waits | down | whole, still | orange | full, with a count beside it |

Motion: lift, tip and settle use the "grow" spring of 15.4 (response 0.35), with no bounce. Colour changes in 0.16 s. One thing loops, only while he thinks: the travelling gap. Reduce Motion: no lift, no tip, no travelling gap; states swap by opacity and "thinking" is a still gap. Increase Contrast: the orange becomes `#D9440F` on light grounds.

## 22.6 Where he lives

- **App icon:** the mark in shell white on ink, nothing else, the mark 56% of the tile.
- **Menu bar:** the small mark at 16 points as a template image, in set B. A waiting result shows its count beside the icon.
- **The notch:** at rest nothing is drawn. When called, the mark in shell white (or orange, by state) at 22 points with its word beside it. He is shown only when called, working, or with a result waiting. As built in 0.5.0: only while you hold the key (listening, or "could not" for a failed hold); the app has no notch surface for working or a waiting result, and none was added.

## 22.7 Never

- Never shade it, fill it with a gradient or give it a shadow.
- Never give it eyes, a mouth or a body.
- Never add a dot, a tick, a badge or any other sign to the mark.
- Never let anything overlap the mark or sit inside it.
- Never mix ink and orange in one mark. Never make the name or a field orange.
- Never stretch, mirror or redraw the break.
- Never set the name in capitals, without its "!", or in another face.

## 22.8 Not checked

- The line has one even width; a hand would vary it.
- The optical corrections of 22.3 are set by rule and one look, not tuned at each size.
- Outfit is published under the SIL Open Font Licence; the licence was not read in full for this use.
- No trademark search was done on the mark or the name.
- Known weak points of the states: in set B "done" and "a result waits" are the same drawing; the lift shows only beside something; "could not" can read as damage.
