# 10. Research: Guide speed and cost

Split on 14 November 2026 from what was one research file, one file per part, with section numbers kept. All parts are listed in `README.md`.

Done on 13 November 2026 by research agents on the web. Each fact carries a source number; the sources are listed at the end of the part. "Not confirmed" means the page could not be opened or the vendor does not say.

This file is the record of what the research found and advised. Where you decided differently, a line marked "What was decided" says so. Those lines were added on 14 November 2026. Where this file and the design documents differ, the design documents count.

## 10.4 Guide speed and cost

Starting point, measured by Phew: 1 s wait, then 2.1 s per look on average and up to 6.2 s; 4,531 tokens and 0.9 cents per look. "Estimate" below means nobody has measured it.

### Three findings that change the picture

- **The picture is less than half of what is sent.** At today's sizes it is about 1,700 to 1,950 of the 4,531 tokens, roughly 40% (see the table under "Sending less"). The window text and the list of 80 elements are the rest (G5).
- **The small model is 20 times cheaper**: $0.10 against $2 per million tokens (G2). A look on it would cost about 0.045 cents.
- **Speed cannot be bought.** The faster service options do not cover the two models Phew uses (G9, G10).

### Knowing the screen changed, without the model

| Signal | Works where | Limit |
|---|---|---|
| Comparing the window text and elements with the last look | Native apps, panels | Blind to the Figma canvas (G20) |
| Comparing two small versions of the picture | Everywhere | A very small change can be missed. Timing is an estimate: under 5 ms |
| Accessibility notifications | Native apps | Browsers, Electron apps and Figma often send nothing (G18, G19) |
| A live screen stream that reports what was redrawn | Everywhere, the best signal (G14) | It watches the screen all through the guide. The research left this to your decision on the rule "he reads the screen only when called". You approved it on 13 November for the length of a guide: see "What was decided" below |

A look can be skipped when both the text and the small picture are unchanged. Neither alone is enough.

### Sending less

A picture costs (width ÷ 28, rounded up) × (height ÷ 28, rounded up) tokens. On Claude 4.7 and later models, which includes the main model, the limit is 4,784 tokens per picture; a larger picture is shrunk first (G5).

| Picture | Tokens | Cost on the main model |
|---|---|---|
| Whole display, 1512×982 | 1,944 | 0.39 cents |
| Window, 1440×900 | 1,716 | 0.34 cents |
| Cut around the target, 560×420 | 300 | 0.06 cents |

The documentation advises cutting to the region of interest for small targets. The model then answers with positions inside the cut picture, so the position of the cut on the screen must be added back before pointing (G26). Caching the fixed part of the request saves about 0.15 cents per look and almost no time; it needs at least 512 fixed tokens (G7).

### The slow looks

The model's guide says that with structured answers at low effort "the model occasionally keeps thinking until it reaches `max_tokens`", and to treat that as a failure and retry (G12). This may be the cause of the 6.2 s looks. Not confirmed against Phew's logs.

### How it feels

- 0.1 s feels instant, 1 s keeps the flow of thought, beyond that show that something is happening (G22). Phew's 3.1 s per step is past that limit on every step.
- Business guidance tools (WalkMe, Pendo) move to the next step the moment you click the marked element, without asking a server (G23, G24).
- Apple: put the status near the thing it describes, and keep it moving (G25).

### Five changes, best first

Effects are estimates.

| # | Change | Speed | Cost per look | Looks per guide | Risk |
|---|---|---|---|---|---|
| 1 | No look while you drag or scroll. One look when you let go. On scroll the pointer just moves with its target | Lag in drags and scrolls goes away | Same | 30 to 50% fewer | Low |
| 2 | Skip the look when nothing changed (text and small picture both the same) | A skipped look takes 0.05 s, not 2.1 s | Same | 10 to 25% fewer | Medium: a tiny change missed |
| 3 | Advance at once when you click the marked target, show a "looking" motion on the pointer, confirm with the look. Wait 0.4 s after a click instead of 1 s. Built only on steps that need just a click: see "What was decided" below | Feels under 0.5 s on a direct hit | Same | Same | Medium: a wrong advance must step back visibly |
| 4 | Send less: picture cut around the target, fewer elements, fixed part cached | 0.1 to 0.3 s faster | 0.9 to about 0.45 cents | Same | Medium: a dialog elsewhere is not seen |
| 5 | Tune the call: cap the answer length, retry a runaway answer, test less thinking on the recorded hard cases | 0.3 to 0.8 s faster, fewer 6 s looks | Same | Same | Accuracy may drop. Keep only if the recorded cases still pass |

Left out of the five: the small model as a first pass (it already failed once on "two steps at once"; worth a retry with a narrower question after change 5), and the live screen stream, because it needed your decision on the rule "he reads the screen only when called".

**What was decided.** On 13 November you put more than changes 1 to 3 in the MVP, as phase PS: changes 1 to 4, the cap and the retry from change 5, and the live screen stream. "Test less thinking" from change 5 was not decided and is not in the roadmap.

The screen watch (task PS.6). You approved it for the length of a guide. Its limits are in `04-architecture.md` 4.6, and that text counts. In short:

- It is used only to know when the screen has settled and whether it changed. The watch alone sends nothing to the model. A look is still made only after you act.
- It starts when the guide's steps are shown. It stops as soon as following stops: the last step is done, the card closes, you press Escape, the limit of 40 looks is reached, or a look fails.
- It also stops after 2 minutes without an action from you, and starts again when you act. Decided 14 November, when Pause was also removed from Phew (see `07-decisions.md` 7.1).
- Frames stay in memory. They are never written to disk or to a log.

Change 3, the direct hit (task PS.3). The rule is in `04-architecture.md` 4.4. The Guide marks each step that needs only a click, with one yes or no field per step. Only on such a step does a direct hit advance at once. The look then confirms, and a wrong advance steps back. A direct hit is a press and release without a drag, inside the marked element, or inside the ring (22 points radius) around a marked point. Steps that need typing, dragging or choosing wait for the look. The last step always waits for the look, so the card never closes on a guess.

### Sources

- G2 https://platform.claude.com/docs/en/about-claude/pricing
- G5 https://platform.claude.com/docs/en/build-with-claude/vision
- G7 https://platform.claude.com/docs/en/build-with-claude/prompt-caching
- G9 https://platform.claude.com/docs/en/build-with-claude/fast-mode
- G10 https://platform.claude.com/docs/en/api/service-tiers
- G12 https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-sonnet-5-5
- G14 https://developer.apple.com/documentation/screencapturekit/scstreamframeinfo/dirtyrects
- G18 https://chromium.org/developers/design-documents/accessibility
- G19 https://www.electronjs.org/docs/latest/tutorial/accessibility
- G20 https://www.figma.com/blog/building-accessibility-into-a-canvas-based-product/
- G22 https://www.nngroup.com/articles/response-times-3-important-limits/
- G23 https://support.walkme.com/?p=1009
- G24 https://support.pendo.io/hc/en-us/articles/360033838131-Create-an-effective-dashboard-walkthrough
- G25 https://developer.apple.com/design/human-interface-guidelines/feedback
- G26 https://platform.claude.com/docs/en/build-with-claude/vision-coordinates
