# Phew

Phew is an experimental macOS menu bar assistant. When you call it, it can explain what is on screen, guide you through an app step by step, and carry out selected actions in supported apps.

This repository contains version **0.5.1**. The app is under active development. It is a personal project, not a supported product.

## Download

The [latest release](https://github.com/jonny648/phew/releases/latest) includes a macOS disk image for Apple silicon. It is signed with a personal Apple Development certificate and is not notarized by Apple, so macOS may block it on other Macs. Review the source and decide whether you trust the app before opening it. Building it yourself, as described below, is the safer way.

## What it can do

- Answer questions about the current screen and guide you through app workflows.
- Carry out selected actions in supported apps, with confirmation for some changes.
- Keep encrypted local project memory and perform background research tasks.
- Optionally use voice input and connected tools.

## What you need

- A Mac with Apple silicon.
- An Anthropic API key. Phew asks for it at first run and stores it in the macOS Keychain. Usage is billed to your Anthropic account.
- Screen Recording and Accessibility permissions. Voice input also needs Microphone and Speech Recognition. Some actions ask for Automation, Calendar or Reminders access when first used.
- Optional: the Claude Code program, installed and signed in by you, for the "Use my Claude account" switch.

## Privacy and safety

Phew requires macOS Screen Recording and Accessibility permissions. **Captured screenshots are sent to Anthropic's Claude API without redacting image pixels.** Text filtering is incomplete and does not guarantee that sensitive information is removed. Do not use Phew while passwords, financial or health information, confidential work, or other sensitive material is visible.

Your Claude API key is stored in the macOS Keychain. Voice input is transcribed on your Mac. Project memory is stored encrypted on your Mac. Connected tools can access the services you enable, so review each permission and action carefully.

Phew can click, type and run menu commands in your apps. It can make mistakes. Watch what it does, and use Stop or the "Let Phew act" switch in the menu when in doubt.

## Build

The project is built and tested with Xcode 27. The app's deployment target is macOS 15.

```sh
xcodebuild -project Phew.xcodeproj -scheme Phew -configuration Debug build
```

Xcode fetches one dependency, SQLCipher.swift, through Swift Package Manager. To build without an Apple developer account, add `CODE_SIGNING_ALLOWED=NO`; macOS then asks again for the app's permissions after each build.

The app includes a compiled helper at `Phew/Brain/engine.js`. To rebuild it after changing `Engine/`, run `Tools/build-engine.sh`. `Tools/fetch-node.sh` downloads the Node.js runtime that the skill tests and the disk-image packaging script use. `Tools/make-dmg.sh` builds the disk image and needs a signing certificate on your Mac.

## Test

```sh
Tools/fetch-node.sh
xcodebuild -project Phew.xcodeproj -scheme Phew test -resultBundlePath /tmp/phew.xcresult
Tools/check-tests.sh /tmp/phew.xcresult 715 7
```

`Tools/check-tests.sh` reads the counts, because a skipped test looks like a pass. Seven tests are skipped in a normal run: they need a real window, the microphone or the real Claude Code program. A normal run makes no call to the Claude API or to a connected service, and all test data is made up. Some tests require a graphical session.

## What is in this repository

| Folder | What it holds |
|---|---|
| `Phew/Shell` | The menu bar item, the input panel, the pointer overlay, the text card |
| `Phew/Senses` | Screen reading, speech to text, the secrets filter, and the one function through which every action is sent |
| `Phew/Brain` | The Claude API client, the agents, connected tools, skills |
| `Phew/Map` | The encrypted local memory |
| `PhewTests` | Unit tests |
| `Engine` | A small TypeScript helper that runs skills in a sandbox; compiled to `Phew/Brain/engine.js` |
| `Tools` | Scripts to build the helper, fetch Node.js, package the disk image and check test counts |

The design documents, the roadmap and the working notes are not published. Comments in the code that cite `docs/…`, a roadmap task or `CLAUDE.md` refer to those files.

## Support

There is no support and no promise of fixes. Issues are welcome. If you find a security problem, please open an issue that says so without the details, and wait for a reply before publishing them.

## Dependencies and license

Phew's source is available under the MIT License; see [LICENSE](LICENSE). Third-party notices for SQLCipher.swift and the Node.js runtime are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Changes per version are in [CHANGELOG.md](CHANGELOG.md).
