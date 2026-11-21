# Phew

Phew is an experimental macOS menu bar assistant that can explain what is on screen, guide app workflows, and carry out selected actions in supported apps.

This repository contains version **0.5.1**. The app is under active development and is not a supported production product.

## Download

The [latest release](https://github.com/jonny648/phew/releases/latest) includes a macOS disk image. The current release is signed with an Apple Development certificate but is not notarized by Apple, so macOS may block it on other Macs. Review the source and decide whether you trust the app before opening it.

## What it can do

- Answer questions about the current screen and guide you through app workflows.
- Carry out selected actions in supported apps, with confirmation for some changes.
- Keep encrypted local project memory and perform background research tasks.
- Optionally use voice input and connected tools.

## Privacy and safety

Phew requires macOS Screen Recording and Accessibility permissions. **Captured screenshots are sent to Anthropic's Claude API without redacting image pixels.** Text filtering is incomplete and does not guarantee that sensitive information is removed. Do not use Phew while passwords, financial or health information, confidential work, or other sensitive material is visible.

Your Claude API key is stored in the macOS Keychain, and API usage is billed to your Anthropic account. Voice input is transcribed on your Mac. Connected tools can access the services you enable, so review each permission and action carefully.

## Build

Builds require macOS 26 or later and Xcode 27.

```sh
xcodebuild -project Phew.xcodeproj -scheme Phew -configuration Debug build
```

The repository includes app and helper tests under `PhewTests/` and `Engine/src/`. Some app tests require a graphical session.

The app includes a compiled helper at `Phew/Brain/engine.js`. To rebuild it after changing `Engine/`, run `Tools/build-engine.sh`. `Tools/fetch-node.sh` downloads the Node.js runtime used by the disk-image packaging script.

## Dependencies and license

Phew's source is available under the MIT License; see [LICENSE](LICENSE). Third-party notices for SQLCipher.swift and the Node.js runtime are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
