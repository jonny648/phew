# 15. Design: look and feel

Written 15 November 2026 for tasks PX.1 (study) and PX.2 (design). It stands in for the Figma drawings: each surface and state is described closely enough to build without a picture. The choices are made here, following Apple's Human Interface Guidelines (HIG) and the best Mac utility tools. You can change any of them; the tokens in 15.4 are the one place to do it.

Not in this phase: the character, the notch, sound. He never speaks. Every surface stays a small non-activating panel; there is no main window and no Dock icon. No surface shows what was captured from the screen.

**As built, 15 November.** Drawn in Figma from the real screens: https://www.figma.com/design/GlLT4s5vxGiTuEnqTutghP ("Phew interface", in the drafts of GG Works). Three things below are no longer true: the acting consent screen (15.1, 15.5 F) was removed on your word, acting is on from the start; `KeyWindow.swift` and `PermissionsWindow.swift` (15.6) are replaced by `SetupPanel.swift`; the card grows on a 0.35 s ease-out, not a spring. Not built: the hint row, the multi-line ask field, the "To undo" line, the "can't be undone" tag.

## 15.1 Surfaces today

Values are read from the code in `Phew/Shell/`. "Rough" means what a designer would notice in the first minute.

### Input panel (`InputPanel.swift`, `EditPanel.swift`)

- Now: a borderless panel whose top-left corner is at the cursor. 320 wide, about 40 high. One plain text field, placeholder "Ask Phew", system 13 pt text, 12 padding. Background `.regularMaterial`, corner radius 10, the system window shadow. Appears and disappears with no transition. Return sends, Escape or a click elsewhere closes.
- Rough:
  - 320 points shows about 40 characters on one line. A longer task scrolls sideways out of view.
  - Nothing marks it as Phew: no sign, no hint. Nobody can discover that Return with nothing typed explains what is under the cursor.
  - It pops in and out. Then the answer card appears 12 points right and 12 down, 40 points wider: the eye sees two unrelated boxes.
  - Phew is never the active app, so the material may draw in its dull "inactive window" look. To check in PX.3 (fix in 15.4).

### Answer card (`TextCard.swift`)

- Now: 360 wide, starts 44 high, grows to at most 420, then scrolls. Padding 14, 10 between blocks, every word in system 13 pt regular. Fades in over 0.15 s; no fade out. Thinking is the small system spinner plus "Thinking…" in grey. A grey "Reply…" line at the bottom. Close is an `xmark` at caption size, top right, about 26 points of hit area. A problem is shown as grey text.
- Rough:
  - The question you asked is not on the card. With two requests in a row you cannot tell which one it answers.
  - One size, one weight, one grey: an answer, a note and an error look the same.
  - The card's height jumps as the words arrive; the frame is set with no motion.
  - "Reply…" reads as part of the answer, not as a place to type.
  - Lines sit at the system's 16 pt line height, tight for an answer of several paragraphs.

### Conversation thread (`TextCard.swift`, `CardView.thread`)

- Now: a click widens the card from 360 to 400 and lets it grow to 520. A 28-point empty strip at the top is the drag area. Your questions sit right in a grey bubble (radius 6, padding 8 and 5); his answers are plain text. A divider, then a reply field of 1 to 6 lines with 12 padding. "Sent when this answer is done." in caption grey. It ends after 10 minutes without a reply.
- Rough:
  - The width jump of 40 points on the click, with no motion.
  - The drag strip is invisible. Nothing says the card can be moved.
  - Bubble radius 6 inside a card of radius 10: the corners are unrelated.
  - Guide steps kept in the thread look the same as an answer.

### Pointer and guide (`PointerOverlay.swift`, `TextCardGuide.swift`, `TextCardFollowing.swift`)

- Now: a clear full-screen panel above everything that ignores the mouse. An arrow about 12 by 20 points, filled with the Mac's own accent colour, white 1.5 outline, a light shadow. It glides from the menu bar icon in 0.4 s, ease in and out, on a straight line. A ring around the target: 3-point stroke in the same colour, glow of radius 6 at 70%, 4 points of room, corners up to 8; a circle of radius 22 for a bare point. The ring fades in 0.2 s and out 0.1 s. While he looks, the arrow pulses from size 1 to 1.25 every 0.35 s. With Reduce Motion: no glide, the arrow jumps; the pulse becomes a fade to 40%. On the card, steps are "1. text": the current one semibold, the others grey; a click on a line jumps to it.
- Rough:
  - The colour is whatever accent the Mac is set to. With Graphite the pointer is grey; a blue ring on a blue selection disappears. Phew has no colour of his own.
  - The glow gives no contrast on a white page. The ring is weakest exactly where most work happens.
  - The 0.35 s pulse reads as nervous, not as "looking".
  - A finished step and a coming step look the same. There is no "step 2 of 5".
  - With Reduce Motion the arrow teleports with no fade.

### Action list while he acts, and the acting mark

- Now: not built. Nothing in `Phew/Shell/` lists actions, shows Stop on the card or changes the menu bar icon. They are tasks PH.3 and PH.5; their look is set here first (15.5 B and D).

### Menu (`PhewApp.swift`)

- Now: a standard menu on the menu bar icon, the symbol `cursorarrow.rays`. Seven entries, one divider: API Key…, Recently deleted…, Export the Map…, Never read this app, Never-read apps…, About and licences, Quit Phew.
- Rough:
  - There is no "Ask Phew" entry, and a click on the icon does not call him, though `03-experience.md` 3.3 lists the click as a way in.
  - The shortcut (right Option and right Command together) is written nowhere in the app.
  - The API key, used once, is the first entry. Daily entries come after it.
  - The icon never changes. It cannot show that he is working or that a result waits.
  - "Never read this app" does not say which app.

### Small panels (`MenuPanels.swift`, `NeverReadPanel.swift`, `PermissionsWindow.swift`, `KeyWindow.swift`)

- Now: standard titled panels with a close button, floating, centred on screen each time. Padding 20, 12 between blocks, a grey footnote at the bottom, system buttons.

| Panel | Size | Title |
|---|---|---|
| Never read | 360 × 260 | "Never read" |
| Recently deleted | 420 × 320 | "Recently deleted" |
| Export the Map | 400 wide | "Export the Map" |
| About and licences | 560 × 420 | "About Phew" |
| Permissions | 380 wide | "Phew" |
| API key | 380 wide | "Phew" |

- Rough:
  - Four widths for six panels of the same kind. Two different panels are both called "Phew".
  - An empty list is one grey line in the middle of an empty box.
  - Rows have no dividers. "Restore" and "Delete now" have the same weight, side by side.
  - In Permissions, after a refusal the "Allow" button does nothing you can see; macOS shows its prompt only once.

### Consent screens and first run

- Now: no consent screen exists yet (research: PA.2; acting: PH.3). First run is two unconnected moments: the Permissions panel at launch if a permission is missing, and the API key panel only after your first question fails for lack of a key. Nothing tells you the shortcut.
- Rough: a new user can grant both permissions, see the panel close, and not know what to press. The first question then fails and asks for a key.

## 15.2 References

How each was checked is stated. "Snippet" means only a search summary was read, not the page.

| Tool | What it does for the same surface | Source |
|---|---|---|
| Apple HIG | Use system materials and semantic colours so light, dark and Increase Contrast work by themselves. Panels float and do not take over. Motion is brief, has a purpose, and is never the only way to understand something; with Reduce Motion, replace movement with a fade | [Materials](https://developer.apple.com/design/human-interface-guidelines/materials), [Typography](https://developer.apple.com/design/human-interface-guidelines/typography), [Motion](https://developer.apple.com/design/human-interface-guidelines/motion), [Panels](https://developer.apple.com/design/human-interface-guidelines/panels), [The menu bar](https://developer.apple.com/design/human-interface-guidelines/the-menu-bar). From knowledge of the guidelines; the pages did not load as text |
| Raycast | The search bar was made bigger "to reflect its importance". One bar at the bottom of the window holds the title, messages and the actions with their shortcuts. Follow-ups are typed in the same surface | [A fresh look and feel](https://raycast.com/blog/a-fresh-look-and-feel) (read), [Quick AI manual](https://manual.raycast.com/ai/quick-ai.md) (from 11.10) |
| Spotlight and Siri, macOS 27 | One floating bar; the answer expands in place; an "Ask" bar at the bottom takes follow-ups; you can drag it | [Engadget, 9 June 2026](https://engadget.com/2190638/siri-ai-first-look-how-apples-rebuilt-ai-powered-assistant-behaves-across-iphone-ipad-and-mac) (from 11.10) |
| Linear | "The interface shouldn't compete for attention it hasn't earned": fewer and smaller icons, fewer dividers, softer contrast for what is not active | [Behind the latest design refresh](https://linear.app/now/behind-the-latest-design-refresh) (snippet) |
| Things | Quick Entry opens over any app from one shortcut, takes typing at once, and closes on save. Its top edge is the drag area | [Quick Entry](https://culturedcode.com/things/support/articles/2249437/), [release notes](https://culturedcode.com/things/releasenotes/) (snippets) |
| CleanShot X | The result of a capture waits as a small overlay in a corner. It never opens a window by itself; you act on it or close it | [iMore on 4.1](https://www.imore.com/cleanshot-x-gains-new-keyboard-shortcuts-quick-access-overlay-more) (snippet) |
| Claude computer use | While it controls the Mac: one notice, "Claude is using your computer · press Esc to stop". Escape works from anywhere. A second notice when done. Your apps are put back | [Claude Code docs](https://code.claude.com/docs/en/computer-use) (read) |
| Cursor computer use | A blue outline on the screen and a pill while it acts. Users report the pill leaves after about a second, so Stop is hard to reach; staff point to the Stop button in the chat | [Cursor forum](https://forum.cursor.com/t/computer-use-on-off-repeatedly/171695) (snippet) |
| ChatGPT companion window | Lessons from its bugs: a window that opens in random places, and focus not handed back on close | Sources in `11-direction.md` 11.10 |

What Phew takes from them: a larger ask field (Raycast); one surface that grows in place, with the reply at its bottom (Siri, Raycast); quiet secondary elements (Linear); results that wait (CleanShot); and for acting, a Stop that stays in one fixed place for the whole job (the lesson from Cursor), with Escape stopping from anywhere (Claude).

## 15.3 Principles

1. **One surface.** The ask field, the answer, the conversation and the action list are the same box, in the same place, at the same width. Forbids: a second window, a width jump, an answer that appears somewhere else.
2. **Quiet until working.** At rest nothing moves and nothing is coloured. Colour and motion mean "Phew is doing something now". Forbids: decoration, idle animation, colour used for emphasis in text.
3. **Words first.** The answer is the content; everything else is smaller and greyer. Forbids: icons beside every line, borders around text, more than two levels of emphasis on a card.
4. **System-made.** System font, system materials, system colours, standard menus and title bars. Phew adds one colour and one shape, the pointer. Forbids: custom window chrome, a second typeface, hard-coded greys.
5. **Motion explains, never delays.** Every motion shows where something came from or what just happened, and is over in a third of a second. Forbids: an action or an answer waiting for an animation, bounce, anything that loops when he is idle.
6. **Always clear who has the controls.** While he acts, the mark, the list and Stop are visible the whole time, and Stop does not move. Forbids: an action that is not listed, a Stop that hides, scrolls away or changes place.
7. **Fixed places.** A panel opens where you called it or where it was, stays inside the screen, and does not move by itself except to uncover the spot he points at. Forbids: random positions, panels that slide in from an edge, taking focus.

## 15.4 Tokens

### Type: SF Pro, the system font

| Name | Size / line | Weight | Used for | SwiftUI |
|---|---|---|---|---|
| `ask` | 16 / 20 | Regular | The ask field only | `.system(size: 16)` |
| `title` | 15 / 20 | Semibold | Heading of a consent screen and of first run | `.title3.weight(.semibold)` |
| `body` | 13 / 18 | Regular | Answers, replies, steps, actions, panel text | `.body` with `.lineSpacing(2)` |
| `strong` | 13 / 18 | Semibold | The current step, the current action, button labels | `.body.weight(.semibold)` |
| `small` | 11 / 14 | Regular | Hints, footers, notes, the question line on a card | `.subheadline` |
| `tag` | 10 / 13 | Medium | Key caps, the "can't be undone" tag | `.caption2.weight(.medium)` |
| `mono` | 12 / 16 | Regular, SF Mono | Licence text | `.system(size: 12, design: .monospaced)` |

Five sizes, two weights. Nothing else.

### Colour: black and shell white, plus one accent

| Name | Light | Dark | Source |
|---|---|---|---|
| `surface` | Blurred material | Blurred material | `NSVisualEffectView`, material `.popover`, state `.active` (so it does not go dull while Phew is not the active app) |
| `panel` | Window background | Window background | `NSColor.windowBackgroundColor`, for titled panels |
| `ink` | Near black | Near white | `NSColor.labelColor` |
| `ink2` | Grey | Grey | `NSColor.secondaryLabelColor` |
| `ink3` | Light grey | Dim grey | `NSColor.tertiaryLabelColor` |
| `hairline` | — | — | `NSColor.separatorColor`, 0.5 point |
| `fill` | — | — | SwiftUI `.quaternary`: bubbles, key caps, quiet buttons |
| `accent` | `#F2541B` | `#FF6B35` | Phew's one colour, a warm orange. Presence dot, ticks, the current-step bar. Shapes only, never text |
| `accentOnScreen` | `#F2541B` | `#F2541B` | Pointer and ring. One value in both modes, because they sit on your app's content, not on Phew's. Always with a white outline |
| `ok` / `problem` | — | — | `NSColor.systemGreen` / `systemRed`, on a small symbol only |

- The main button is black on light and white on dark (`ink` fill, `panel` text). The accent is never a button.
- `#F2541B` has a contrast of about 3.5 to 1 on white and 4.8 to 1 on a dark window, enough for a shape, not for text.
- The brand sheet comes with the character, after the MVP. If the colour changes then, it changes in this one token.
- Increase Contrast: `surface` becomes `panel` with a 1-point `ink2` border.

### Space, corners, sizes

| Token | Value |
|---|---|
| Space | 4, 8, 12, 16, 20, 24. Nothing in between |
| Radius `chip` | 6: key caps, tags, buttons |
| Radius `bubble` | 10: your message in a thread, text fields in panels |
| Radius `panel` | 14: the ask panel and the card |
| Radius `ring` | Up to 8 around an element; a full circle of radius 22 around a bare point |
| `width` | 400: ask panel, card and thread, always |
| `cardMax` / `threadMax` | 420 / 520 high, then the content scrolls |
| `bar` | 36: header and footer of the card. 44 for the footer while he acts |
| `panelWidth` | 420 for small panels, 440 for consent and first run, 560 for licences |
| Button height | 28. Hit area of any control at least 28 × 28 |

### Shadow and material

| Where | Value |
|---|---|
| Ask panel, card | `surface`, a 0.5-point `hairline` border, the system window shadow (`hasShadow`; call `invalidateShadow()` after a resize) |
| Titled panels | Standard title bar and shadow. Nothing custom |
| Pointer | Fill `accentOnScreen`, white outline 1.5, shadow black 30%, radius 2, 1 down |
| Ring | Stroke `accentOnScreen` 3, a white line of 1 outside it at 80%, shadow black 35%, radius 3. No coloured glow |

### Motion: one language

| Name | Value | Used for | With Reduce Motion |
|---|---|---|---|
| `appear` | 0.16 s ease-out: opacity 0 to 1, scale 0.98 to 1 | Ask panel, card, ring | Opacity only |
| `leave` | 0.12 s ease-in: opacity to 0 | Anything closing | Same |
| `grow` | Spring, response 0.35, damping 0.86 (Core Animation: mass 1, stiffness 322, damping 31) | Card height as words arrive, opening the thread, the card moving aside | Frame set at once; content cross-fades in 0.16 s |
| `travel` | Spring, response 0.5, damping 0.9 (stiffness 158, damping 22.6) | The pointer between spots, from and to the menu bar | Pointer fades out (`leave`) and in at the new spot (`appear`) |
| `press` | 0.18 s: pointer scale 1 to 0.88 to 1; the ring fills with accent at 25%, fading in 0.3 s | Each action he takes | The ring fill only |
| `breathe` | 1.6 s cycle, ease in and out: opacity 1 to 0.4; on the pointer, scale 1 to 1.12 | Thinking (the dot), looking (the pointer) | Opacity only, on both |
| `tick` | 0.12 s: opacity 0 to 1, scale 0.6 to 1 | A step or action marked done | Opacity only |

What moves: the card's bottom edge, the pointer, the ring, the presence dot. What never moves:
- The card's top-left corner while it grows.
- Text. Words appear in place as they arrive: no typing effect, no fade per word, no sliding lines.
- Panels on opening: none slides in from an edge.
- Anything at rest. Only `breathe` loops, and only while he thinks, looks or acts.
- Nothing bounces: both springs settle without overshoot you can see.

An action never waits for motion. If he acts faster than the pointer travels, the pointer jumps to the new spot.

## 15.5 Each surface, final

### A. Ask panel

```
┌──────────────────────────────────────────────┐  400 wide, 48 high
│ ●  Ask Phew                                  │  dot 8, field in `ask`
└──────────────────────────────────────────────┘
   ↵ ask · empty ↵ explains what is here · esc     hint, `small`, `ink3`
```

- Place: top-left corner at the cursor, kept inside the screen, as today.
- Layout: 16 padding left and right. The presence dot (8 points, `accent`), 12 gap, the field. The field grows to 4 lines, then scrolls.
- **Empty:** placeholder "Ask Phew" in `ink3`. Under the panel, inside the same surface, a hint row 24 high: `↵ ask · empty ↵ explains what is here · esc`, with `↵` and `esc` as key caps (`tag` on `fill`, radius 6). The hint row goes away at the first character.
- **Typing:** the text in `ink`. Shift and Return makes a new line.
- **Sent:** the panel does not close and reopen as a card. The same box becomes the card (B): the field turns into the question line of the header and the answer grows below. Same corner, same width.
- **Closed without a question:** `leave`.
- Motion: `appear` on opening. The field takes typing at once; typing never waits for the fade.

### B. The card

One box, 400 wide, three parts: header (36), body, footer (36).

```
┌──────────────────────────────────────────────┐
│ ●  Make the title bold                     ✕ │  header: dot, question (`small`, ink2, 1 line), close
│                                              │
│  Body: `body` text in `ink`, 16 padding      │
│                                              │
│──────────────────────────────────────────────│  hairline
│  Reply…                                      │  footer
└──────────────────────────────────────────────┘
```

- Header: the presence dot at 16 from the left; your question in `small`, `ink2`, one line, cut with "…" (nothing if you asked with no words); the close control, `xmark` 11 pt semibold in `ink2`, inside a 28 × 28 hit area. The header is the drag area once the thread is open; the cursor shows the open hand over it.
- The dot is Phew. Still when he is done, `breathe` while he thinks, looks or acts.
- Place: where the ask panel was. It grows downward with `grow`; if it would leave the screen, it is moved up, not shrunk.

States of the body and footer:

| State | Body | Footer |
|---|---|---|
| **Thinking** | Empty. The card is header only, 36 high. The dot breathes. No spinner, no "Thinking…" (VoiceOver reads the dot as "Thinking") | None |
| **Answer** | The words in `body`, appearing as they arrive. A note ("Notes is on your Never read list…") above them in `small`, `ink2`. Scrolls beyond 420 | "Reply…" in `ink3`. The whole card opens the thread on a click, as today |
| **Conversation** | Oldest at the top. Your messages right-aligned on `fill`, radius 10, padding 8 and 12, at most 300 wide. His answers plain, full width. 12 between turns. The newest stays in view. Up to 520 high | A reply field, 1 to 6 lines, `body`, with the cursor in it. While he answers and you have sent the next reply: "Sent when this answer is done." in `small`, `ink2`, under the field |
| **Guide** | The answer, if any, then the steps, one row each, 8 apart. A done step: a tick in `ok` then the text in `ink2`. The current step: a 2-point `accent` bar at the left edge of the row, text in `strong`. A coming step: its number in `ink3`, text in `ink2`. A click on a row jumps to it | "Step 2 of 5" in `small`, `ink2`, left. "Reply…" stays on the right when the thread is closed |
| **Acting** | The action list, below | Stop, below |
| **Error** | One row: `exclamationmark.circle` in `problem`, then the sentence in `body`, `ink`. If there is one thing to do, one quiet button under it ("API Key…", "Open permissions"). No red background, no red text | "Reply…" if a reply can help; else none |

In a thread, a past guide or a past job is folded to one line in `ink2` ("Guide, 5 steps" or "4 actions in Notes"), so the thread stays readable.

**Acting, in full** (follows `13-hand.md` 13.4):

```
┌──────────────────────────────────────────────┐
│ ●  Make the title bold and send it         ✕ │
│                                              │
│  ✓  Selected the title                       │  done: tick in `ok`, text ink2
│  ✓  Pressed Bold                             │
│  ◌  Typing 12 characters in Subject          │  now: small spinner, text `strong`
│                                              │
│──────────────────────────────────────────────│
│  Working in Mail · 3 actions      [ ■ Stop ] │  footer 44, never scrolls
└──────────────────────────────────────────────┘
```

- One row per action, added at the bottom as it happens, in his plain words from 13.4 ("Pressed Bold.", "Typed 12 characters in Title."). The list scrolls inside the body; the newest row stays in view.
- A row has three looks: now (small system spinner, text in `strong`), checked (tick in `ok` with `tick`, text in `ink2`), failed (`xmark` in `problem`, text in `ink`).
- An action that cannot be undone carries a tag at the end of its row: "can't be undone", in `tag`, on `fill`, radius 6.
- Footer, 44 high, pinned: on the left "Working in Mail · 3 actions" in `small`, `ink2`. On the right the Stop button: 28 high, `fill` background, a `stop.fill` symbol and "Stop" in `strong`. It is the only button on the card and it stays in that corner for the whole job. It is not red: stopping is the safe choice.
- The close control is hidden while he acts, so the only way to end the job from the card is Stop. The shortcut and using the app yourself stop him too, as in 13.4.
- **Done:** the dot goes still. Under the list, one line in `body`: what was done. Under it, when the app has Undo, "To undo: Command-Z in Mail." in `small`, `ink2`. The footer returns to "Reply…" and the close control comes back.
- **Stopped, by you or by him:** the list stays. Under it one row as in Error, with his sentence from 13.4 ("The button is not where it was. I stopped."). When you stopped him: "Stopped." in `ink2`, no symbol. Footer: "Reply…".
- The list lives in memory and goes when the card closes.

### C. Pointer and ring

- The pointer: the arrow of today, same size, in `accentOnScreen` with the white outline. Its colour no longer follows the Mac's accent setting.
- The ring: as in 15.4. It appears with `appear` when the pointer arrives and leaves with `leave` before the pointer sets off.
- **Guide:** the pointer travels (`travel`) from the menu bar icon to the spot and rests at the ring's bottom right, as today. At the end it travels home and the overlay goes.
- **Looking:** the pointer breathes (`breathe`, scale to 1.12). Slower and smaller than today's pulse.
- **Acting:** the pointer rests on the centre of the target, not beside it: he is the one pressing. Each action plays `press` once. Between actions the ring stays on the spot he is acting on; this ring is the acting mark on screen that 13.4 asks for.
- The card moves aside (`grow`) when it covers the spot, as today.
- No trail, no sparkle, no screen-wide outline. Those belong to the character phase or not at all.

### D. Menu bar icon and menu

The icon is the second half of the acting mark. It is a template symbol, so it follows the menu bar's colour.

| State | Icon |
|---|---|
| Resting | `cursorarrow.rays`, as today |
| Acting | `cursorarrow.motionlines`, for the whole job |
| Research tasks running | The resting icon followed by the number of tasks, in the menu bar's text style |
| A result waits | The resting icon with a 5-point dot at its top right. The dot is the only thing that may be in `accent` |

The icon never animates. He never opens anything by himself.

The menu stays a standard system menu:

```
Ask Phew                    right ⌥ + right ⌘
─────────────────────────────
Working                                        (heading, only while tasks run)
  Stop "Kerning sources"
Ready                                          (heading, only when a result waits)
  Kerning sources
─────────────────────────────
✓ Let Phew act                                 (on from the start)        
  Never read Notes                             (names the app in front)
─────────────────────────────
Memory                    ▸   Recently deleted… · Export the Map… · Never-read apps…
Reports                   ▸   Saved reports… · Choose reports folder…
─────────────────────────────
API Key…
About Phew
Quit Phew
```

- "Ask Phew" does what the shortcut does, and shows the shortcut. It is the first entry.
- Entries for things not built yet (Working, Ready, Let Phew act, Reports) arrive with their own phases, in these places.
- "…" only on entries that open a panel.

### E. Small panels: Never read, Recently deleted, Export, About

- One shape: a standard titled panel, close button, floating, non-activating, 420 wide (licences 560). The title is the menu entry's name without "…". It opens centred the first time and where you left it after that.
- Inside: 20 padding. A list fills the panel; rows are 36 high, separated by a `hairline`, text in `body`, a second line in `small`, `ink2`.
- A row has one quiet button on the right (`fill`, 28 high): "Remove", "Restore". A second, rarer action ("Delete now") is a plain text button in `ink2` beside it, so the two no longer look equal.
- The help line stays at the bottom in `small`, `ink2`, above nothing else.
- **Empty:** the help line moves to the middle of the panel with one line above it in `body`, `ink2`: "No apps on the list.", "Nothing in Recently deleted." The panel shrinks to 160 high.
- **Error:** the sentence replaces the help line, with the `exclamationmark.circle` in `problem`.

### F. Consent screens: research and acting

Not in the app: both consent screens were removed on 15 November (see the note at the top). Kept as the record of the design.

One shape for both, 440 wide, non-activating, floating, centred. Standard title bar with no title text.

```
┌────────────────────────────────────────────────┐
│ ✕                                              │
│   Phew can do things for you.                  │  `title`
│                                                │
│   When you ask, he clicks, types and picks     │  `body`, ink, paragraphs 12 apart
│   menus in your apps by himself, and lists     │
│   what he did. …                               │
│                                                │
│   Text on a web page or in a document can      │
│   mislead him. …                               │
│                                                │
│                      [ Not now ]  [  Allow  ]  │  28 high, 8 apart, right-aligned
└────────────────────────────────────────────────┘
```

- 24 padding. The text column is 392 wide, about 60 characters a line.
- Buttons: "Allow" is the main button (black on light, white on dark), on the right, as on the Mac. "Not now" is quiet (`fill`) on its left. Neither answers Return: the panel does not take the keyboard, and a risk should be accepted with a deliberate click. Escape and the close button mean Not now.
- No icon, no illustration, no checkbox, no "learn more".
- Acting, the text exactly as approved in `13-hand.md` 13.8:

> **Phew can do things for you.**
>
> When you ask, he clicks, types and picks menus in your apps by himself, and lists what he did. He never types passwords, pays, or changes system settings. Stop always works.
>
> Text on a web page or in a document can mislead him. He may then do a wrong thing, including sending or deleting.
>
> [Allow] [Not now]

- Research: the same shape with the text exactly as in `03-experience.md` 3.5 ("Phew can research a task by himself."). It is longer: four paragraphs. The panel grows to fit, up to 560 high, then the text scrolls and the buttons stay pinned.
- After a choice the panel closes with `leave`. After Allow the job or task starts and the card shows it.

### G. First run: key and permissions as one flow

One panel, 440 wide, shown at launch when anything is missing. It replaces the two separate panels.

```
┌────────────────────────────────────────────────┐
│   Set up Phew                                  │  `title`
│   Three things, once.                          │  `small`, ink2
│                                                │
│   ○  Claude API key                            │  row heading in `strong`
│      [ ••••••••••••••••        ] [Paste][Save] │
│      Stored only in this Mac's Keychain.       │  `small`, ink2
│ ────────────────────────────────────────────── │
│   ○  Accessibility                   [ Allow ] │
│      So he can read the window you are in.     │
│ ────────────────────────────────────────────── │
│   ○  Screen Recording                [ Allow ] │
│      So he can see what the text leaves out.   │
└────────────────────────────────────────────────┘
```

- Each row: a circle that becomes a tick in `ok` (`tick`) when done; the heading; one line saying why, in plain words; one control.
- **Key row:** the secure field (radius 10), "Paste", "Save". Wrong or refused key: the why-line is replaced by the sentence, with the `problem` symbol.
- **Permission rows:** "Allow" shows the macOS prompt. If you refused before, the button reads "Open System Settings" and opens the right page there, because macOS will not ask twice.
- **Screen Recording granted but not yet active:** the why-line becomes "Takes effect when Phew reopens." and the button becomes "Reopen Phew".
- **All done:** the three rows fold into one last state, and the panel waits for you to close it:

```
│   ✓  Phew is ready                             │  `title`
│                                                │
│   Press  [right ⌥]  and  [right ⌘]  together,  │  key caps
│   in any app. He is in the menu bar.           │
│                                      [ Done ]  │
```

- "API Key…" in the menu opens the same panel showing the key row only.

## 15.6 Build order for the shell builder

New file first: `Phew/Shell/Design.swift`. Names only; values from 15.4.

```swift
enum Design {
    enum Text   { static let ask, title, body, strong, small, tag, mono: Font }
    enum Ink    { static let primary, secondary, tertiary, hairline, fill,
                             accent, accentOnScreen, ok, problem: Color }
    enum Space  { static let s4, s8, s12, s16, s20, s24: CGFloat }
    enum Radius { static let chip, bubble, panel, ring: CGFloat }
    enum Size   { static let width, cardMax, threadMax, bar, actingBar,
                             panelWidth, consentWidth, licenceWidth, button: CGFloat }
    enum Motion {
        static var reduce: Bool                 // the system's Reduce Motion setting
        static let appear, leave, press, tick: TimeInterval
        static let grow, travel: Animation      // and their Core Animation twins
        static let breathe: Animation
    }
}
struct Surface: NSViewRepresentable   // the blurred material, always in its active look
struct PresenceDot: View              // still or breathing
struct Keycap: View
struct MainButton: ButtonStyle        // ink fill
struct QuietButton: ButtonStyle       // `fill` background
struct Row: View                      // list row for small panels and first run
```

| Pass | File | What it gets |
|---|---|---|
| **PX.3** panel, card, conversation | `Design.swift` | The tokens and the small shared pieces above |
| | `InputPanel.swift` | 400 wide, `ask` text, presence dot, hint row, up to 4 lines, `Surface`, `appear` and `leave` |
| | `TextCard.swift` | One width (400) for closed and open. Header with dot, question and close; footer. States thinking, answer, conversation, error. `fit(height:)` uses `grow`. The card opens at the ask panel's corner, not 12 points off |
| | `PhewApp.swift` | Hands the ask panel's corner to the card |
| | `EditPanel.swift` | Unchanged |
| **PX.4** pointer, guide, acting | `PointerOverlay.swift` | `accentOnScreen`, the ring with its white line and dark shadow, `travel`, `press`, the slower `breathe`, the Reduce Motion fades |
| | `TextCardGuide.swift`, `TextCard.swift` | Step rows with done, current and coming looks; "Step 2 of 5" |
| | `TextCard.swift` | The action list and the pinned Stop footer, fed by PH.5. If PH.5 is not built yet, build the view against made-up rows behind the test flag |
| | `PhewApp.swift` | The menu bar icon's four states |
| | `TextCardFollowing.swift`, `FollowRule.swift` | Unchanged |
| **PX.5** menu, panels, consent, first run | `PhewApp.swift` | The menu in its new order, with "Ask Phew" and the app's name in "Never read" |
| | `MenuPanels.swift`, `NeverReadPanel.swift` | One width, `Row`, empty and error states, remembered position |
| | `MenuPanels.swift` | The consent view, one shape for both texts, used by PA.2 and PH.3 |
| | `PermissionsWindow.swift`, `KeyWindow.swift` | One first-run panel made of the three rows and the ready state. `KeyWindow` shows the key row alone from the menu |

Checks for every pass, by hand: light and dark; Reduce Motion on; Increase Contrast on; a white document and a dark one under the ring; the front app still has the keyboard after each panel closes; Phew is never the active app.

## 15.7 What this changes in other documents

Named here, not edited:

- `03-experience.md` 3.10 says the closed card is 360 wide and the open one about 400. Here both are 400, so the click no longer changes the width.
- The pointer's colour was the Mac's accent colour. It is now Phew's own.
- The ask field shows a hint about the empty Return. `02-vision.md` 2.5 says "one way in"; the hint adds no choice, it only says what already happens.
- First run gains two buttons that did not exist: "Open System Settings" and "Reopen Phew". They are what lets a new user reach a first answer without help (PX.5).
