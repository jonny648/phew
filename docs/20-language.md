# 20. The language question: Swift, or TypeScript for the thinking part

Written 17 November 2026, at your request. Research with sources (20.3) and a small trial with measured numbers (20.4). Nothing in the app was changed. The decision is yours (decision 48 in `07-decisions.md`).

## 20.1 In plain words

**Recommendation: stay all Swift for now.** Do not move the thinking part to TypeScript. Keep one door open: a small helper, only for connections, only if the tools refuse the Swift kit.

Why:

1. **TypeScript is not more powerful as a language.** What it has is more ready-made parts for AI work. For Phew the gap is real in three places only: the kit for connections (the Swift one is one version of the standard behind), browser automation, and readers for Excel and PowerPoint files. For everything else you asked for (structured answers, memory search, PDF, a closed box for running code) Apple's own tools cover it and Swift reaches them directly.
2. **The trial showed what a move costs.** One agent, the research one, was rewritten in TypeScript and run beside a small Swift program. It worked, and the gates stayed in Swift. It bought a loop about 15 lines shorter. It cost: the app going from 4 MB to between 115 and 170 MB, 69 MB more memory, a second language and toolchain, about 225 lines of plumbing between the two, and a process that can hang or die.
3. **Your rules are the deciding point.** Today "only one function may act" and "the secrets filter runs before every network call" are true because there is one program. With a TypeScript engine they stay true by construction only if the engine has no network of its own. The trial proved that can be enforced on your Mac. But an engine with no network cannot run the things TypeScript was wanted for: the connections kit, browser automation and the Agent SDK all need their own network. So the choice is between reach and the rules, not both.
4. **A whole app in TypeScript** (Electron, Tauri) would still need native code for nine of Phew's ten Mac needs. Electron cannot read another app's controls, and its global shortcut never reports the key being released, so hold-to-talk would not work.
5. **What others did.** Raycast kept a Swift host and added a Node part, for a Windows version and for hiring. Codex moved away from TypeScript to drop the Node dependency. No public case was found of a Mac assistant moving to TypeScript to gain reach.

**The strongest argument against this recommendation:** the gap grows every month. New agent helpers ship for TypeScript and Python first, the Swift connections kit is already behind, and an AI coding assistant writes TypeScript agent code more fluently than Swift.

**The test that settles it,** already planned as NB.1: connect the Swift kit to Notion (then Linear, GitHub) and see whether each accepts it. All accept: Swift holds. Two or more refuse: build a small connections-only helper in TypeScript, with Swift still making every model call and every action. It touches a real service, so it needs your word.

**If a second runtime is ever added,** it should be a worker with no network for one pure job (read a file, run a self-made skill), not the brain.

## 20.2 The four shapes

| | 1. All Swift (today) | 2. Swift + a TypeScript engine | 3. All TypeScript | 4. A server part |
|---|---|---|---|---|
| Reach gained | Connections through the Swift kit, one version behind | The newest connections kit, browser automation, every npm package | The same as 2 | Shared key, work that runs while the Mac sleeps |
| Work (rough estimate) | 2 to 3 weeks for connections, as planned | 5 to 8 weeks | 12 to 20 weeks | 4 to 6 weeks, then running costs |
| Size of the app | 4 MB | 115 to 170 MB measured in the trial with Node | 120 MB or more | 4 MB |
| Memory | as today | about 69 MB more (measured) | several hundred MB (Raycast's own figures) | as today |
| One acting function | Kept by construction | Kept, if every action crosses to Swift | By discipline | Kept on the Mac |
| Secrets filter before the network | Kept by construction | Kept only if the engine has no network; otherwise by discipline | By discipline | Lost for what the server sends |
| Key only in the Keychain | Kept | Kept (the trial's engine held no key) | By discipline | Lost with a shared key |
| No words in a log, no capture on disk | Kept | By discipline in a second program | By discipline | Lost on the server |
| Stop within a second | Kept | Kept (trial: 1 ms; a frozen engine killed in 0.83 s) | Kept | Kept on the Mac |
| Upkeep for you | One language | Two languages, a runtime to patch and sign | One language, many native add-ons | A service to run |

## 20.3 The trial, measured

One agent (the research Runner) in TypeScript with the official Claude kit, started by a small Swift program, talking over a pipe. A scripted fake model: no real call, no key. Node 22 on this Mac.

| Measure | Result |
|---|---|
| Start of the engine | 97 ms |
| One full scripted task | 20 ms the first time, 2.6 ms after |
| One crossing between the two programs | 0.03 ms |
| Memory of the idle engine | 68.6 MB |
| What would ship | Node 110.7 MB, packages 54 to 86 MB, the engine itself 11 KB |
| Code for the loop and its limits | 125 lines of TypeScript against 140 of Swift |
| Plumbing that exists only because there are two programs | about 225 lines |
| The engine's "no network" | A convention in its own code. Enforced by macOS when started under `sandbox-exec`, which works here but which Apple marks as deprecated. Node's own permission flag does not cover the network in this version |
| Tests | 14 checks pass: the report, each of the five limits, Stop, a planted fake key never reaching the model, Swift refusing a 13th request even when the engine is told it may make 99 |

Not shown by the trial: a real model, streaming of words as they are written, a real connection, signing and notarising an app with Node inside, and Bun or Deno (not installed, not measured).

## 20.4 Also found, for the code as it is

- The research found no retry in Phew's own Claude client when the service is busy or limits the rate. About 30 lines. Passed to the code review (`19-review.md`) to confirm.

---

## 20.5 Research note, with sources

## Should the thinking part move to TypeScript? Research note

Written 16 November 2026. Research only; nothing in the project was changed. It builds on `docs/18-capabilities.md` (MCP, the Agent SDK, agent patterns) and does not repeat it.

How to read the marks: **[measured]** = I ran it on this Mac today (macOS 27.2.1, Node v22.19.0). **[API]** = GitHub or nodejs.org public API, read today. **[fetched]** = I read the page today. **[search]** = seen only through a search summary. **[bundled]** = Anthropic's bundled API reference, cached 3 November 2026. **[not verified]** = from general knowledge, no source checked today.

The four shapes: (1) stay all Swift; (2) Swift app plus a TypeScript engine as a child process; (3) an all-TypeScript desktop app; (4) add a server part.

---

### 0. The answer in short

Stay all Swift (shape 1). The gap is real in three places only: the connection kit (MCP) is one protocol version behind, there is no browser automation library, and Office files other than Word have no Apple reader. None of the three is needed for what is planned next, and each has a Swift-side or API-side route. Shape 2 is technically sound and I proved its hardest claim today (a child process with no network at all), but the things TypeScript would bring are exactly the things that need their own network and their own child processes, so the safe form of shape 2 gives up most of the gain. Shape 3 loses the native parts this app is made of. Shape 4 is a privacy decision, not a language one.

---

### 1. Capability by capability

What the app has today, for scale: the whole Claude client is `Phew/Brain/ClaudeProvider.swift` (154 lines) plus `SSEParser.swift` (134 lines); the tool loop is `ToolLoop.swift` (118 lines). I found no automatic retry on 429 or 5xx in `ClaudeProvider.swift` (grep only; worth a look).

| Capability | TypeScript today | Swift today | What Swift lacks in practice | Cost to write in Swift | Apple frameworks |
|---|---|---|---|---|---|
| **Claude API client** | Official `@anthropic-ai/sdk`, release 1.8.0 of 10 Nov 2026 [API, [repo](https://github.com/anthropics/anthropic-sdk-typescript)]. Adds: 2 automatic retries on 408/409/429/5xx, typed errors, `stream().finalMessage()`, `messages.parse()` for structured output, a tool runner (`toolRunner` + `betaZodTool`) that validates each tool input and runs the loop with per-turn hooks, helpers for the memory tool [bundled] | No official Swift SDK: official ones are Python, TypeScript, Java, Go, Ruby, C#, PHP [bundled, [client SDKs](https://platform.claude.com/docs/en/api/client-sdks)]. Community: [SwiftAnthropic](https://github.com/jamesrochabrun/SwiftAnthropic) 254 stars, last push 18 Apr 2026, 7 months quiet; [AnthropicSwiftSDK](https://github.com/fumito-ito/AnthropicSwiftSDK) 18 stars, last push June 2026 [API]. Neither is safe to depend on | Nothing that blocks. Each new API feature must be added by hand from the docs. Retries are missing | Already written (288 lines). Retries: about 30 lines. Each new feature: tens of lines | `URLSession` covers transport and streaming |
| **MCP client and server** | Official SDK v2.4.0 (23 Oct 2026), Tier 1, implements spec **2026-07-28**; v1 line gets fixes until about Jan 2027 [API, [README](https://github.com/modelcontextprotocol/typescript-sdk)] | Official [swift-sdk](https://github.com/modelcontextprotocol/swift-sdk) 0.12.1, Tier 3, speaks **2025-11-25**, active (pushed 15 Nov 2026) [API; details in doc 18 section 3.1] | One protocol version behind. Breaks only against a server that drops the older version | Hand-written tools-only client over HTTP: about 300 to 500 lines; sign-in (OAuth) is the big part, about 600 to 1,000 lines if the SDK's could not be used [my estimate] | None |
| **Claude Agent SDK** | TypeScript and Python only. It starts a bundled `claude` program and talks to it over stdin/stdout. Writes transcripts to `~/.claude/projects/<folder>/*.jsonl`; `persistSession: false` (TypeScript only) keeps them in memory. Key comes from an environment variable [fetched, [sessions](https://code.claude.com/docs/en/agent-sdk/sessions); doc 18 B.3] | Not available | A ready loop with files, shell, sub-agents, compaction | Not worth copying: built around a shell and a work folder, which the rules forbid acting on | None |
| **Agent frameworks** | Vercel AI SDK, LangGraph.js, Mastra, OpenAI Agents SDK [not verified today; none is needed to call one provider] | None of weight | A loop with hooks, which the app already has in 118 lines | Done. Workers (doc 18): about 200 lines more | Foundation Models has tool calling, but for Apple's on-device model only [search, [Apple](https://developer.apple.com/documentation/foundationmodels)] |
| **Browser automation** | Playwright (Node; drives its own downloaded Chromium/WebKit), raw CDP clients. Anthropic's browser tool has helper classes only for Python and TypeScript [doc 18 A.8] | No Playwright. Routes: `safaridriver`, "do JavaScript" over Apple Events, a `WKWebView` the app owns [doc 18 A.6] | A maintained library for clicks, waits, frames, downloads | A usable subset over `WKWebView`: about 800 to 1,500 lines and constant upkeep [my estimate]. This is the largest real gap | `WKWebView` gives a browser the app owns; not the user's signed-in tabs |
| **Structured output, schema checks** | Zod: one definition gives the type, the JSON schema and the runtime check | `Codable` plus the API's own guarantee (`strict: true` tools, `output_config.format`), which the app uses already | A schema generated from the type; schemas are hand-written strings today | Nothing needed. A small macro would be polish | `Codable`; `@Generable` works only with Apple's model |
| **Local vector search, embeddings** | `sqlite-vec` bindings, transformers.js for local models | `sqlite-vec` is a C extension, usable from Swift [API, [repo](https://github.com/asg017/sqlite-vec), last push May 2026]; whether it loads under SQLCipher is [not verified]. The app already uses FTS5 and `NLEmbedding` | Bigger local embedding models; reachable with [mlx-swift](https://github.com/ml-explore/mlx-swift) (active, Nov 2026) [API] | Adding a vector column and search: about 150 to 300 lines | `NLEmbedding`, `NLContextualEmbedding` [not verified today] |
| **Document parsing** | pdf.js, mammoth (Word), SheetJS (Excel), officeparser | PDF: PDFKit. Word: `NSAttributedString` reads `.docx` [not verified today]. Excel: [CoreXLSX](https://github.com/CoreOffice/CoreXLSX), last push March 2024, stale [API]. PowerPoint: nothing | Excel and PowerPoint readers | Excel text out of the zip and XML: about 300 lines. Or send the file to the model: the API reads PDF directly [bundled] | PDFKit, `NSAttributedString`, Vision for scans |
| **Sandbox for generated code** | Anthropic's [sandbox-runtime](https://github.com/anthropics/sandbox-runtime) (TypeScript, 7,150 stars): on macOS it wraps `sandbox-exec` with generated profiles and a proxy with a domain allowlist; "early research preview" [fetched]. Runtime flags (Node `--permission`, Deno) are weaker, see section 2 | The same system call is open to Swift: start any program under `sandbox-exec` with `Process()`. [apple/containerization](https://github.com/apple/containerization) runs Linux containers from Swift (9,021 stars, active) [API]. JavaScriptCore runs JavaScript in-process with only the functions the app hands it | Nothing: the strongest sandboxes on a Mac are the system's own, and Swift reaches them directly | A `sandbox-exec` wrapper: about 50 lines. A JavaScriptCore runner for self-made skills: about 200 lines | Yes: Seatbelt, App Sandbox, Containerization, JavaScriptCore |

Reading the table: TypeScript is ahead by a library in three rows (MCP version, browser automation, Excel/PowerPoint). In the other six rows Swift either has it, or the API gives it, or Apple's own framework is the stronger tool.

---

### 2. Shape 2: Swift app plus a TypeScript engine as a child process

#### 2.1 Runtimes that can ship inside a signed app

| Runtime | Size | Cold start | Idle memory | Notes |
|---|---|---|---|---|
| **Node 26 LTS** (26.13.1, 10 Nov 2026) | Download 30.6 MB (`.tar.xz`), 58.3 MB (`.tar.gz`) [API, [nodejs.org/dist](https://nodejs.org/dist/)]. The `node` program itself on disk: **110.7 MB** for v22.19.0 [measured] | **0.02 s** for an empty script [measured, v22] | **about 40 MB** resident [measured, v22]. Raycast reports about 12 MB bare and 150 to 200 MB for its real backend [fetched] | Single executable applications: `node --build-sea`, still "Stability 1.1, active development"; one bundled script; native add-ons must be written to a temp file first; ad-hoc sign after building [fetched, [docs](https://nodejs.org/api/single-executable-applications.html)] |
| **Bun** 1.4.4 (22 Oct 2026) | Runtime download 40.3 MB zipped for Apple silicon [API]. A compiled program contains the runtime, so expect about 60 MB or more [not measured: Bun is not installed here] | Not measured | Not measured | `bun build --compile` is stable. A newer `bun compile` (ahead-of-time, no JIT) is experimental [fetched, [compiler docs](https://bun.com/docs/compiler)]. Claude Code ships as a Bun executable [search, [Anthropic, 3 Dec 2025](https://www.anthropic.com/news/anthropic-acquires-bun-as-claude-code-reaches-usd1b-milestone)] |
| **Deno** 2.9.8 (21 Oct 2026) | Runtime download 38.8 MB zipped [API]; compiled size not stated in the docs | Not measured | Not measured | `deno compile`: permission flags are fixed at build time; ad-hoc signed by default, can be re-signed [fetched, [docs](https://docs.deno.com/runtime/reference/cli/compile/)] |
| **JavaScriptCore** (in the app, no runtime shipped) | 0 MB: part of macOS | None: same process | Small | No Node APIs, no `fetch`, no npm native modules. Raycast prototyped this and dropped it because developers could not use npm packages [fetched, [Raycast, 31 May 2023](https://raycast.com/blog/how-raycast-api-extensions-work)]. That weakness is a strength for self-made skills: code can only call what the app hands it |

The app is about 4 MB today. Any shipped runtime makes it 15 to 30 times larger.

#### 2.2 Signing and notarisation

- A notarised app must use the hardened runtime, and every program inside the bundle must be signed with it [not verified today; Apple's page returned only its title].
- JavaScript engines make machine code at run time. Under the hardened runtime that needs `com.apple.security.cs.allow-jit`. Bun's own signing guide lists `allow-jit`, and later versions add `allow-unsigned-executable-memory` and `disable-executable-page-protection`; without them a signed Bun program fails with "Ran out of executable memory" [search, [Bun guide](https://bun.com/docs/guides/runtime/codesign-macos-executable)]. Those last two weaken a protection the app has today for free.
- Library validation: a native add-on (`.node` file) not signed by the same team is refused unless `disable-library-validation` is added [not verified today].
- **Mac App Store**: needs the App Sandbox. This app already cannot be sandboxed, because reading and pressing other apps through Accessibility is not allowed there [not verified today]. So the store is closed in every shape; shape 2 does not change that.

#### 2.3 The protocol between the two

| Channel | Cost | Notes |
|---|---|---|
| **JSON-RPC over stdin/stdout** | About 200 to 300 lines on each side, plus start, crash and restart handling | What Raycast uses ("easy to debug due to its plain text nature") [fetched], what MCP stdio servers use, what the Agent SDK uses. Nothing else on the Mac can connect to a pipe. Screenshots cross as base64 text |
| **XPC** | A Swift helper target; Node cannot speak XPC without a native add-on | Useful for a *Swift* helper: it gets its own sandbox entitlements, the Apple-supported way to have a part with no network |
| **Local socket** | Small | Any program on the Mac can try to connect, so it needs its own secret. Avoid |

#### 2.4 Updates and security patches

Node 26 had two releases in the two weeks before today (26.13.0 on 28 Oct, 26.13.1 on 10 Nov) [API]. A bundled runtime is patched only when a new version of the app ships, so the owner takes on a second release train he cannot judge. Raycast avoided bundling: it downloads Node on first use and checks the file before starting it [fetched].

#### 2.5 Can the engine be denied its own network? Yes, I tested it

**[measured]** A Node child started under `sandbox-exec -p '(version 1)(allow default)(deny network*)'`:

- its own web request failed (`ENOTFOUND`);
- a program it started itself (`curl`) failed too (exit 6): the rule is inherited by everything below it;
- a connection to `127.0.0.1` failed (`EPERM`);
- writing to its pipe still worked, and start-up time did not change (0.02 s).

So "every byte to the internet goes through the Swift side" can be made true by the system's kernel, not by good behaviour. Three ways, strongest first:

1. **A Seatbelt profile (`sandbox-exec`).** Works today. Its manual page on this Mac says "The sandbox-exec command is DEPRECATED" [measured]. Raycast wrote that it is not "supported for third-party development" [fetched]. Yet Anthropic's sandbox-runtime, built for Claude Code, is made on it [fetched]. Honest status: widely used, working, officially unsupported, could be removed in any macOS release.
2. **App Sandbox entitlements on the helper.** A helper signed with the sandbox and without the network entitlement has no network; this is the supported route. Whether Node or Bun runs correctly inside it together with the JIT entitlements is [not verified].
3. **The runtime's own switches** (Node `--permission`, Deno without `--allow-net`). Not enough alone. Node's page says: "This feature does not protect against malicious code" [fetched, [docs](https://nodejs.org/api/permissions.html)].

**The catch.** A profile can also deny file writes, which would keep captures off disk by construction. But a network-less engine cannot use what TypeScript was wanted for: the MCP SDK opens its own connections, Playwright starts and drives a browser, the Agent SDK starts `claude` and calls the API with its own key. Each would need its traffic re-routed through the pipe (possible for the two SDKs through a custom transport or `fetch` [not verified], not possible for Playwright). Once that is done the engine is a loop plus parsers, which Swift already has.

---

### 3. Shape 3: an all-TypeScript desktop app

| Need of this app | Electron (45.3.3, 14 Nov 2026) | Tauri (2.12, Nov 2026) |
|---|---|---|
| Read other apps' Accessibility tree | No API. `systemPreferences.isTrustedAccessibilityClient` only asks for the permission [fetched, [docs](https://www.electronjs.org/docs/latest/api/system-preferences)]. Needs a native add-on in Swift or Objective-C | Not in the web layer. Written in Rust or Swift on the native side |
| Synthetic clicks and keys | Native add-on | Native side |
| Non-activating panel that never takes focus | `type: 'panel'` exists; it has a history of focus bugs and fixes that differ by macOS version [search, [issue 35815](https://github.com/electron/electron/issues/35815)] | Community plugin [tauri-nspanel](https://github.com/ahkohd/tauri-nspanel), 428 stars [API] |
| Pointer overlay over other apps, the notch shape | A transparent always-on-top window is possible; exact levels and the notch need native code [not verified] | Same |
| Global hotkey with press-and-hold | `globalShortcut` reports the press only, never the release, so hold-to-talk does not work with it [search, [Electron docs](https://www.electronjs.org/docs/latest/api/global-shortcut), [Vesktop PR 326](https://github.com/Vencord/Vesktop/pull/326)]. Native add-on | Same limit reported [search, [Tauri issue 4364](https://github.com/tauri-apps/tauri/issues/4364)]. Native side |
| On-device speech (SpeechAnalyzer) | Swift-only framework. Native add-on | Swift side |
| Keychain | `safeStorage` encrypts with a key held in the Keychain; direct Keychain items need an add-on [not verified today] | Plugin or native side |
| EventKit, AppleScript | Native add-on, or run `osascript` | Native side |
| ScreenCaptureKit | `desktopCapturer` gives screens and windows [not verified today]; fine control needs native code | Native side |
| No Dock icon | `app.dock.hide()` [not verified today] | Supported |
| Size | Runtime download alone is **121 MB** zipped for Apple silicon [API] | "A minimal Tauri app can be less than 600KB" [fetched, [tauri.app](https://v2.tauri.app/start/)]; it uses the system's web view |
| Memory | An empty web view is about 50 MB; a real one 120 to 200 MB [fetched, Raycast's figures] | Same web view cost |

Nine of the ten needs are native code in either framework. What would remain in TypeScript is the card, the menu panels and the engine. For this app Electron is "shape 2 plus a 121 MB browser". Tauri is "rewrite the native half in Rust".

The best public evidence is Raycast 2.0 (14 May 2026). Raycast rejected both Electron and Tauri "for giving too little native control" and built a Swift/AppKit host with web UI, a Node backend and a Rust core, because "we need access to low-level native code to have fine-grained control" for global hotkeys, accessibility and "floating panels that don't steal focus". Memory went from 200 to 300 MB to 350 to 450 MB [fetched, [Raycast](https://www.raycast.com/blog/a-technical-deep-dive-into-the-new-raycast)]. Their reason for moving was a Windows version and hiring, not reach on the Mac.

---

### 4. What comparable products are built with

| Product | Native part | Web or Node part | Source and date |
|---|---|---|---|
| **Raycast 1** | Whole app in Swift/AppKit | Extensions in one child Node process, JSON-RPC over stdio, UI drawn natively | [fetched, 31 May 2023](https://raycast.com/blog/how-raycast-api-extensions-work) |
| **Raycast 2** | Swift/AppKit host (windows, hotkeys, menu bar), Rust data layer | React UI in the system web view; one long-lived Node backend | [fetched, 14 May 2026](https://www.raycast.com/blog/a-technical-deep-dive-into-the-new-raycast) |
| **ChatGPT for Mac** | Launched in 2024 as "a fully native macOS app. Not Electron" | Replaced in July 2026 by a web-technology build; the native one renamed "ChatGPT Classic". Reported at about 1.5 GB against about 170 MB | [search: [engineer's post, 2024](https://x.com/Javi/status/1790074965112328538); [Daring Fireball, 11 Jul 2026](https://daringfireball.net/linked/2026/07/11/can-someone-explain-to-me-how-to-get-chatgpt-classic); sizes from one blog, unverified] |
| **Claude desktop app** | Not verified | Electron | [search, secondary sources only] |
| **Claude Code** | — | TypeScript, shipped as one Bun executable | [search, [Anthropic, 3 Dec 2025](https://www.anthropic.com/news/anthropic-acquires-bun-as-claude-code-reaches-usd1b-milestone)] |
| **OpenAI Codex CLI** | Rewritten from TypeScript to Rust, announced June 2025; reasons given: no Node install needed, sandboxing, memory. The repository today is 87 MB of Rust and 0.1 MB of TypeScript | — | [search, [InfoQ, June 2025](https://www.infoq.com/news/2025/06/codex-cli-rust-native-rewrite); API] |
| **Cursor** | — | A fork of VS Code, so Electron | [not verified today] |
| **Clicky / HeyClicky** (points at the screen, voice) | Swift, Xcode, ScreenCaptureKit | A small server (Cloudflare Worker) that holds the API keys | [fetched, [README](https://github.com/farzaa/clicky), update of 27 Apr 2026] |
| **Peekaboo** (screen reading for agents) | Swift | Optional MCP server | [API, [repo](https://github.com/openclaw/Peekaboo)] |
| **Cua** (computer-use drivers) | Rust first, then TypeScript, Python, Swift | — | [API, [repo](https://github.com/trycua/cua)] |
| **Goose** | Rust core (10.9 MB of code) | TypeScript UI (3.5 MB of code) | [API, [repo](https://github.com/aaif-goose/goose)] |
| **UI-TARS desktop** | — | TypeScript/Electron; archived | [API, [repo](https://github.com/bytedance/UI-TARS-desktop)] |
| **Granola, Wispr Flow, Highlight, Rewind/Limitless** | — | — | **Not verified.** Two searches found no primary source for any of the four |

The pattern: products that touch the system deeply keep a native core (Swift or Rust) and put the web layer where the screens are. Products that moved toward the web did it for a second platform (Raycast, ChatGPT) and paid in size and memory. The one tool that moved away from TypeScript (Codex) did it to drop the Node dependency and to sandbox better. Nobody public moved to TypeScript "to reach more capabilities" on the Mac.

---

### 5. Shape 4, briefly: a server part

What it would give: research that goes on with the Mac asleep, scheduled jobs, and a place to hold a shared key so a user need not bring one (this is what Clicky's worker does). Anthropic's Managed Agents already offers the first two without a server of the owner's (doc 18 B.4).

What it changes:

- **Privacy.** The task's words and the whole transcript live on a server. Three rules stop being true as written: "the MVP runs entirely on the Mac", "no log holds the user's words" (a server keeps them by nature), and, if a shared key is used, "the key lives only in the Keychain".
- **Cost.** Today the owner pays nothing per user: each uses his own key. A server adds hosting, and with a shared key, every user's tokens. Managed Agents adds $0.08 per session hour on top of tokens [bundled].
- **Work.** Accounts, billing, abuse limits, uptime. This is a company decision. It is independent of the language question and can be taken later without touching it: the `Brain` interface exists for this.

---

### 6. Decision table

Person-weeks are rough estimates for a solo owner building with an AI coding assistant, checker included.

| | 1. All Swift | 2. Swift + TypeScript engine | 3. All TypeScript app | 4. Server part (added to 1) |
|---|---|---|---|---|
| **Reach gained** | None new; gaps closed one by one (MCP kit, an owned web view, Excel text) | Newest MCP version, Playwright, npm parsers, every new Anthropic SDK helper on day one | Same as 2, plus Windows later | Work while the Mac sleeps, schedules, no key for users |
| **Work to get there** | 0 now. Connections as planned in doc 18: 2 to 3 | 5 to 8: port 5,300 lines of Brain and its tests, the bridge, signing with a runtime, crash handling | 12 to 20: rewrite the screens, write native add-ons for nine of ten needs, redo 487 tests | 4 to 6, then running costs for ever |
| **What breaks** | Nothing | 4 MB app becomes 60 to 115 MB; a second language and release train; Brain tests leave `xcodebuild` | Focus behaviour, the notch, hold-to-talk until rebuilt natively; size 120 MB or more | "Runs entirely on the Mac" |
| **One acting function** | Kept by construction (a test fails the build) | Kept by construction **only if** the engine is sandboxed with no Apple Events, no network and no child programs that act; otherwise by discipline | By discipline: any npm package or add-on can act | Unchanged on the Mac |
| **Secrets filter before every network call** | Kept by construction: one `URLSession` call site | Kept by construction with a network-less engine [measured possible]; lost the day the engine gets its own network | By discipline | Lost for what the server sends on |
| **Key only in the Keychain** | Kept by construction | Kept if Swift makes the calls; lost with the Agent SDK (environment variable) | By discipline | Lost with a shared key |
| **No log holds the user's words** | Kept by discipline plus tests | By discipline, harder: libraries print to stderr; the Agent SDK writes transcripts unless told not to | By discipline, harder: Chromium and packages keep their own logs and caches | Lost |
| **Captures never on disk** | Kept by discipline plus tests | By construction if the profile denies file writes; otherwise discipline | By discipline; a web view may cache | Lost if captures are sent up |
| **Card lists every action, stop within 1 s** | Kept: one process, one cancel | Kept if every action still returns to Swift; stop means cancelling across a pipe and, worst case, killing the child | Kept by discipline | A remote job cannot always stop within a second |
| **Size** | About 4 MB | 60 to 115 MB | 120 MB or more (Electron) | 4 MB |
| **Speed** | Today's | +0.02 s start, +40 MB or more memory; per-call cost of the pipe is small | +120 to 200 MB memory | Network delay on every step |
| **Upkeep for a solo non-developer** | One language, one build, one test command. New API features added by hand | Two of everything. Runtime security updates. An assistant writes TypeScript agent code easily, which hides the cost until something breaks between the two halves | Highest: native add-ons are the hardest code to keep alive across macOS versions | A service to keep running |

#### Recommendation

**Stay with shape 1.** Three concrete reasons:

1. **The six rules are true today because of how the program is built, not because someone is careful.** Shape 2 keeps them only in its network-less form, and that form cannot run the three things TypeScript was wanted for.
2. **The gaps are small and named.** The MCP kit lag is the only one on the planned path, and doc 18 already carries the test that settles it. Browser automation and Office parsing are not in any open phase.
3. **The strongest sandbox tools on a Mac are Apple's, and Swift reaches them directly.** For self-made skills (phase NC), JavaScriptCore inside the app or a child under a Seatbelt profile gives "code that can only do what it is handed", with nothing shipped.

If a second runtime is ever needed, make it a **worker, not the brain**: a network-less, write-less child that does one pure job (parse this file, run this skill) and answers over a pipe. That is the test in 2.5, and it leaves all six rules where they are.

#### The strongest argument against this

Every month the distance grows. The Swift MCP kit is Tier 3, version 0.x and already one protocol version behind; Anthropic ships each new helper (tool runner, browser tool handlers, memory tool) for TypeScript and Python only; and the owner's builder is an AI assistant that has seen far more TypeScript agent code than Swift agent code. Raycast, with a full team of Mac specialists, concluded in 2026 that a Node backend behind a Swift shell was the practical answer. If connections become the centre of the product, hand-keeping a Swift client against a moving protocol may cost more than the second runtime would.

#### The smallest first step that would tell

Run the first test already listed in doc 18 section 7, and count: connect the official Swift MCP kit to the first three servers (Notion, Linear, GitHub) and see whether each accepts protocol 2025-11-25 and the sign-in. A few minutes each, with the owner's word since they touch real services.

- All three work: shape 1 is right for the next phase. Re-run the test when the kit or a vendor changes version.
- Two or more refuse: the recommendation is wrong for connections. Then build the smallest shape 2: a connections-only helper, with Swift still making every model call and every action.

Alongside, keep one line in `docs/07-decisions.md` each time a wanted capability is refused for lack of a Swift library. Three such lines in three months is the signal to reopen this note.

---

### Not verified, in one place

- Bun and Deno: compiled size, cold start and idle memory (neither is installed here; only download sizes were read).
- Apple's pages on `allow-jit`, hardened runtime, library validation, App Sandbox and Accessibility (the one page fetched returned only its title).
- Whether Node or Bun runs inside the App Sandbox with JIT entitlements.
- Whether `sqlite-vec` loads under SQLCipher.
- `NSAttributedString` reading `.docx`; `NLContextualEmbedding`.
- Electron's `safeStorage`, `desktopCapturer`, `app.dock.hide()`, and overlay window levels.
- That the Anthropic and MCP TypeScript SDKs accept a custom `fetch` or transport that could run over a pipe.
- What Granola, Wispr Flow, Highlight, Rewind/Limitless, Cursor and the Claude desktop app are built with (no primary source found).
- ChatGPT's July 2026 change and its sizes (search summaries and one blog).
- The Node measurements are for v22.19.0 on this Mac, not for Node 26.
- All person-week and line-count figures are my estimates.


---

## 20.6 The trial's own results file

## Trial: the Runner's loop in TypeScript, as a child process of a Swift host

16 November 2026. Throwaway. Mac: arm64, macOS 27.2.1, Node v22.19.0, Swift 6.4.2.
Everything is in this folder; nothing outside it was written. No model call, no API key, no Keychain.

### What was built

- `engine/` (TypeScript): `src/runner.ts` is the loop, the five limits and the tool handling, ported from
  `Runner.research` and `ToolLoop`. `src/rpc.ts` is JSON-RPC over stdio. `src/main.ts` wires them. The engine never
  opens a connection: the Anthropic SDK's `fetch` option is replaced by a function that sends the request body to the
  parent as a `model/request` message. Tools go out as `tool/call`.
- `host/` (Swift package, no dependencies): `Bridge.swift` starts the engine with `Process` and speaks the JSON-RPC.
  `main.swift` holds the stand-in secrets filter, a scripted fake model, the tests and the measures.
- `engine/test/` : the network-denial probe and its tests.

### Numbers

Each is the median of the runs shown. Raw output: `bench.txt`.

| Measure | Value | Runs |
|---|---|---|
| Cold start, process launch to `ready` | 97 ms (sandboxed 96 ms; sandbox + Node permissions 103 ms) | 9 |
| of which bare Node (`node -e 0`) | 23 ms | 9 |
| of which importing `@anthropic-ai/sdk` | 48 ms | 9 |
| of which importing the MCP SDK's stdio helper (pulls zod) | 31 ms | 9 |
| Full scripted task (4 model requests, 2 tool calls), first task on a fresh engine | 20.3 ms | 9 |
| The same task, third on the same engine | 2.6 ms | 9 |
| Time the Swift host spends in that task (decode, filter, fake model, encode) | 0.52 ms | 9 |
| One crossing of the process boundary (request and answer) | 0.03 ms | 1000 |
| Idle engine resident memory | 68.6 MB | 5 |
| Node binary that would ship | 110.7 MB (110,712,624 bytes) | |
| `node_modules` after install | 86 MB, 103 packages (about 54 MB without TypeScript and type files, computed by subtraction) | |
| Compiled engine (`dist/*.js`) | 10.9 KB | |
| Single-file build (Node SEA) | not built, see below | |

| Code | Lines (without comments and blanks) |
|---|---|
| Swift today: limits, limit sentences, `research`, `cleaned`, `checked`, `round` (Runner.swift 25-46, 114-128, 167-267) and `toolUses`, `result` (ToolLoop.swift 86-117) | 170 (140) |
| TypeScript: the same in `runner.ts` | 144 (125) |
| TypeScript: needed only because of the boundary (`rpc.ts`, `main.ts`) | 99 (83) |
| Swift: the bridge the real app would need (`Bridge.swift`), plus about 10 lines for the model handler | 114 (90) |

So the loop itself is about the same size in both languages. The move adds roughly 99 lines of TypeScript and
125 lines of Swift that exist only to cross the boundary.

Commands:

```
cd engine && npm install --before=2026-11-01 --ignore-scripts @anthropic-ai/sdk @modelcontextprotocol/sdk
npm install --before=2026-11-01 --ignore-scripts -D typescript @types/node@22 && npx tsc -p .
cd ../host && swift build -c release
H=host/.build/out/Products/Release/host; N=~/.nvm/versions/node/v22.19.0/bin/node
$H test  --node $N --engine $PWD/engine/dist/main.js --mode plain|permission|sandbox|both
$H bench --node $N --engine $PWD/engine/dist/main.js --mode plain|sandbox|both
$N --test engine/test/nettest.mjs
ls -l $N; du -sh engine/node_modules; ls -l engine/dist     # sizes; memory is `ps -o rss= -p <pid>` inside bench
```

### Tests

`host test`: 14 checks, all pass in all four modes (plain, permission, sandbox, both).

- A report is produced from the script (plan, Map search, two web searches, a page read, report); plan and preamble removed.
- Each of the five limits ends the task with its fixed sentence, chosen by code in `runner.ts`.
  The rounds limit makes exactly 12 requests, the last with `tool_choice: none`.
- Stop: the task ends 1 ms after `stop`, and the engine stays usable. A frozen engine (SIGSTOP) is killed by the
  host after 0.83 s. So the one-second promise is kept by Swift, not by the engine's good will.
- A fake key planted in a tool result never reaches the fake model: the host filter removed it 4 times.
  The host log holds only counts (`model request 2: 1009 bytes, 1 secrets removed`).
- Host ceiling: an engine told it has 99 rounds is refused its 13th model request by Swift.

`nettest.mjs`: 4 checks, all pass.

### Installed or refused

Nothing was refused. npm installed `@anthropic-ai/sdk` 1.3.0 and `@modelcontextprotocol/sdk` 1.32.2 (both chosen by
`--before=2026-11-01`, so at least two weeks old), plus `typescript` 7.0.2 and `@types/node` 22.20.5 to compile.
Install scripts were disabled. The SDKs are used for real: the Anthropic client, its types and its request code
with `fetch` pointed at the bridge; the MCP SDK's `ReadBuffer`, `serializeMessage` and JSON-RPC types.
The SDK was given a placeholder key in code, so it reads no key from the environment, and the host starts the
engine with an empty environment.

### Is "no network" enforced?

In the engine's code it is only a convention: nothing stops a future line, or a dependency, from calling `fetch`.
What makes it real is how the host launches the process:

- (a) Node's permission model: **does not cover the network in Node 22.** `--allow-net` is rejected as a bad
  option, and under `--permission` a socket still connects. It does block file writes and child processes.
- (b) `sandbox-exec` with `(version 1)(allow default)(deny network*)`: **works on this macOS 27.2.1.** A local socket
  fails with EPERM and `fetch('https://example.com')` fails (ENOTFOUND, the name lookup is denied). The engine runs
  normally under it and all 14 host checks pass. Apple marks `sandbox-exec` deprecated; it still runs here, but it
  could go away, and it is not allowed in a Mac App Store build.
- (a) + (b) together: no network, no file writes, no child processes; all checks pass; cold start 103 ms.
- (c) nothing: the control connects, as expected.

Not tried: the supported way, a signed helper with App Sandbox entitlements and no network entitlement.

### What crossing the boundary cost

- Latency: 0.03 ms per crossing. Against a model call of seconds it is nothing. The real cost is the start:
  about 100 ms per engine launch, and 20 ms for the first task while the code warms up.
- Memory: 69 MB resident for an idle engine, on top of the app.
- Size: at least 111 MB for Node, plus 54 MB of packages unless a bundler shrinks them.
- Code: about 225 lines that only move messages, on two sides, in two languages.
- A second failure mode: the engine can die, hang or send bad JSON. The host needs the kill timer and a "gone" path.

### What was awkward

- Streaming was not built. The bridge answers a model request with one whole response, so the `writing` event
  and the words arriving live are missing. Real streaming needs one notification per piece and more bridge code.
- The single-file build stopped early. Node's SEA step that makes the blob works, but it wraps one file only: no
  bundler (esbuild) and no injector (postject) are installed, and I did not install them. A SEA would be at
  least the size of the Node binary anyway.
- Two thirds of the cold start is importing the two SDKs. The MCP SDK brings zod, express, hono and ajv along
  for two small helpers; plain `JSON.parse` on lines would do the same job.
- The host refused a request, and the SDK reported it as "Connection error.": errors lose their meaning at the bridge
  unless each one is mapped by hand.
- The time-limit sentence was tested with 0.4 s in place of 300 s, so it reads "0 minutes".
- Not ported: the day's dollar ceiling, the hour-cache price, cache marks, the screen read, `add_item`.

### Honest reading

What it bought: the official SDK's types and request code, and a loop that reads a little shorter (125 lines against
140). The gates did stay in Swift: the key, the secrets filter, the log, Stop and a hard ceiling on requests all live in
the host, and the engine can be started with no network at all.

What it cost: 111 to 165 MB more to ship, 69 MB of memory, 100 ms to start, a second language and toolchain,
about 225 lines of plumbing, a process that can fail on its own, and a network lock that depends on a deprecated tool.
For this one agent the loop was already written and tested in Swift, so the move buys almost nothing.
It could pay only if many agents or ready-made TypeScript connectors were to share the one engine.

### What this trial does not show

- The model was a fixed script. Nothing here says how a real model, real streaming or real errors behave.
- One agent only. No Guide, Follower or Conductor; no shared engine under load; no two tasks at once.
- No real connection: no MCP server, no web, no Keychain, no real secrets filter, no real cost log.
- The Swift Runner's own time for the same script was not measured: building the app would write outside this folder.
- No signing, notarization or App Sandbox packaging of a bundled Node.

