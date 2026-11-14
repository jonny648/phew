# 10. Research: Locking the Map

Split on 14 November 2026 from what was one research file, one file per part, with section numbers kept. All parts are listed in `README.md`.

This file is the record of what the research found and advised. Where you decided differently, a line marked "What was decided" says so. Those lines were added on 14 November 2026. Where this file and the design documents differ, the design documents count.

## 10.7 Locking the Map

Research for P5.13, done on 14 November 2026. The question is how to encrypt the whole Map file, and how to lock sensitive facts a second time with a different key. You set five needs:

1. The whole file is encrypted on disk.
2. Sensitive facts (health, money, private messages) get a second lock, with a different key.
3. Keys live only in the Keychain.
4. A deleted item leaves the file. No readable trace stays in the database or its write-ahead file.
5. Unit tests run on a plain database in memory.

Nothing here was built or run inside Phew. Where a researcher tried something on this Mac, the text says "local test". That Mac runs macOS 27.2.1 with the system SQLite 3.54.0. Phew targets macOS 15.

### The options

| Option | What it is | Protects against | Cost to build | Effect on search and secure delete | Risks |
|---|---|---|---|---|---|
| **A. SQLCipher 4.20.0** | A free copy of SQLite that encrypts every page of the file. Version 4.20.0 came out on 27 October 2026 and is built on SQLite 3.54.1 [1]. Its licence is BSD-style: its notice must be shown in an About screen or in docs linked from the app [3]. | Anyone who gets a copy of the file: a backup, another user account, a disk read while FileVault is off, another app reading the file [6][24]. | Low. The maker publishes an official Swift package, added in Xcode [4][14]. Phew's code imports `SQLCipher` instead of `SQLite3` [5]. | Text search (FTS5) is built in [8]. The FTS5 secure-delete option needs SQLite 3.42 or later, so it is there [9]. Old copies left in the file or its journal are encrypted [6]. The maker has not said it tested FTS5 secure-delete under encryption. | It must be the only SQLite that Phew's code uses. A wrong link builds and runs with no error and no encryption [10]. About 5 to 15% slower [12]. By default the 5.0 betas cannot open 4.x files, so stay on 4.x [2]. |
| **B. SQLite3 Multiple Ciphers 2.7.0** | Another free encrypting copy of SQLite, MIT licence. Version 2.7.0 came out on 13 November 2026, built on SQLite 3.54.1 [15]. Its default cipher is ChaCha20-Poly1305 [18]. | The same as A. | Medium. There is no official Swift package. Its C source file must be added to the target by hand, with a bridging header [20]. | FTS5 and secure delete are on in its default build [47]. A database in memory is never encrypted, which suits the tests [17]. It also offers encryption of single values, but those cannot be searched (inference: its docs say nothing on search) [19]. | The same clash with the system SQLite as A [21][22]. 2.7.0 fixed key setup errors that could leave a file unencrypted without saying so [15]. It is one day old, and one bug is already noted after the release [16]. |
| **C. SQLite Encryption Extension (SEE)** | SQLite's own paid encryption, US$2000 once [23]. | The file on disk. | Medium. We get source code to build ourselves. | Unknown for the write-ahead file: its page does not mention it [23]. | Costs money. We maintain the build. |
| **D. Apple's built-in SQLite encryption** | Apple's system SQLite contains SEE. | Nothing usable. | Not possible. | None. | Local test: the function exists but is not in Apple's public header. It refused our app with error 21 and the file stayed plain. No public source confirms this. |
| **E. Encrypting the sensitive values with Apple's CryptoKit** | Phew encrypts each sensitive value with AES-GCM before writing it [25]. | Only the sensitive values, against copies of the file and other apps. | Low for the values. | Encrypted values cannot go into the text index, because FTS5 keeps its words as plain text [9]. Sensitive facts would need their own search, for example decrypt and scan. | Does not meet need 1 alone. |
| **F. Database kept in memory, saved as an encrypted snapshot** | SQLite runs in memory. After each change Phew saves the whole database as one CryptoKit-sealed file [26][27]. | The file on disk, fully. A new key on each save also makes old backups unreadable once the old key is deleted. | Medium to high. Custom saving code, plus E for the second lock. | Search and secure delete work unchanged in memory. The write-ahead file must be dropped, because SQLite does not allow it for a database loaded this way [26]. | A crash loses changes not yet saved. Each save briefly holds two copies in memory. Only one process can use the Map. |
| **G. FileVault and Apple's file protection** | macOS encrypts the whole disk (FileVault), or one file with a protection class [28][29]. | A Mac stolen while off, or a logged-out user [29]. | Very low. | None. | Phew cannot make FileVault a requirement. Intel Macs have no file protection [30]. Time Machine copies the file unencrypted unless the backup disk is encrypted [36]. A good extra layer, not a solution. |
| **H. A homemade encryption layer for SQLite (a VFS)** | Phew's own C code encrypts each page as SQLite writes it [31][32]. | Like A. | High. | Like A, if every file type is covered. | Homemade cryptography and a file format we maintain alone. It does what A does. |

### Where the keys live

- macOS has two keychains. The older file-based one is the default. Apple says to prefer the newer "data protection" keychain [24].
- The data protection keychain keeps items private to the app, and allows Touch ID or a password on each use [24]. It needs the app to be signed with an App ID from a provisioning profile [39]. Without it every call fails with error -34018 [38]. This project has no entitlements file today, so it would most likely fail now. Not tested.
- The file-based login keychain works with no profile. Phew's Claude API key is already stored there. Access follows the app's signature. Builds signed "Apple Development" keep access across rebuilds with no prompt [41]. On this keychain the "when unlocked" settings have no effect [40].
- A key is 32 random bytes from Apple's random generator, checked for success [42].
- If the key is lost, an encrypted file cannot be opened. There is no recovery, by design [7].
- Since macOS 26.4 the login keychain is tied to one Mac. Restoring it onto a different Mac is reported to fail. A Migration Assistant transfer is reported to work [24][43].

### Deleting for real, under encryption

- Without encryption, SQLite's own secure delete leaves traces in text indexes [33]. A third-party test also found a deleted word in the write-ahead file after a checkpoint [34]. This is why `05-map-storage.md` 5.12 sets three steps.
- With A or B, any leftover copy is ciphertext [6]. The three steps still matter, so that someone holding the key cannot recover a deleted item.
- Time Machine makes local snapshots about every hour and keeps them up to 24 hours [35]. Backups keep older versions of the file. A deleted item stays in them, encrypted, as long as the key exists. Excluding the files from backup removes that, but then there is no backup [37].
- Overwriting flash storage does not guarantee data is gone. Destroying the key does (crypto-erase) [46].

### What none of this stops

Someone using your unlocked Mac. Malware that you allow through a keychain prompt. An administrator or root. What Phew holds in memory while it runs, though the hardened runtime blocks other apps from reading it [44]. Malware with screen-recording permission sees the screen anyway.

### Recommendation

Option A, SQLCipher 4.20.0. It meets all five needs with the least new code, it has an official Swift package, and it keeps text search and secure delete as already designed. B is a close second, but needs hand integration. F is the strongest against old backups, but it means much more code of our own. The design is in `05-map-storage.md` 5.12. A second reviewer checked the proposal against these findings; its 12 corrections are applied there.

### Not confirmed

- That FTS5 secure-delete and the `unicode61` word splitter behave the same under SQLCipher. Upstream code, so likely. To be proved by a test.
- That a SQLCipher database in memory with no key behaves exactly like plain SQLite. Inferred from the docs [7], not stated.
- That Apple frameworks loading the system SQLite in the same process are harmless. SQLite warns only when two copies open the same file [22].
- Whether this team is a paid team or a free Personal Team. This matters for the data protection keychain [38].
- How macOS 15 behaves, as opposed to the 27.2.1 Mac used for local tests.

### Sources

1. SQLCipher 4.20.0 release, 2026-10-27: https://github.com/sqlcipher/sqlcipher/releases/tag/v4.20.0
2. SQLCipher 5.0.0 beta: https://github.com/sqlcipher/sqlcipher/releases/tag/v5.0.0-beta
3. SQLCipher licence: https://www.zetetic.net/sqlcipher/license/
4. Official Swift package: https://github.com/sqlcipher/SQLCipher.swift/blob/master/Package.swift
5. Apple integrator guide: https://www.zetetic.net/sqlcipher/sqlcipher-apple-integrators/
6. SQLCipher design: https://www.zetetic.net/sqlcipher/design/
7. SQLCipher API: https://www.zetetic.net/sqlcipher/sqlcipher-api/
8. SQLCipher 4.20.0 framework, inspected without running it: https://github.com/sqlcipher/SQLCipher.swift/releases/download/4.20.0/SQLCipher.xcframework.zip
9. SQLite FTS5: https://www.sqlite.org/fts5.html
10. Zetetic advisory on the system SQLite: https://discuss.zetetic.net/t/important-advisory-sqlcipher-with-xcode-8-and-new-sdks/1688
11. SQLCipher Xcode tutorial: https://www.zetetic.net/sqlcipher/ios-tutorial/
12. SQLCipher performance: https://www.zetetic.net/sqlcipher/performance/
13. SQLite ATTACH: https://www.sqlite.org/lang_attach.html
14. SQLCipher 4.10.0, Swift package support, 2025-08-04: https://www.zetetic.net/blog/2025/08/04/sqlcipher-4.10.0-release/
15. SQLite3 Multiple Ciphers 2.7.0, 2026-11-13: https://github.com/utelle/SQLite3MultipleCiphers/releases/tag/v2.7.0
16. SQLite3 Multiple Ciphers changelog: https://github.com/utelle/SQLite3MultipleCiphers/blob/main/CHANGELOG.md
17. SQLite3 Multiple Ciphers overview: https://utelle.github.io/SQLite3MultipleCiphers/
18. SQLite3 Multiple Ciphers settings: https://utelle.github.io/SQLite3MultipleCiphers/docs/configuration/config_sql_pragmas/
19. SQLite3 Multiple Ciphers value encryption: https://utelle.github.io/SQLite3MultipleCiphers/docs/features/feat_vle/
20. Adding SQLite3 Multiple Ciphers to an Xcode project: https://moneymanagerex.org/blog/integrate-sqlite3mc-into-mmex-ios-project/
21. SQLite3 Multiple Ciphers FAQ: https://utelle.github.io/SQLite3MultipleCiphers/docs/faq/faq_overview/
22. SQLite, how to corrupt a database: https://www.sqlite.org/howtocorrupt.html
23. SQLite Encryption Extension: https://sqlite.org/com/see.html
24. Apple TN3137, Mac keychains, revised 2026-09-24: https://developer.apple.com/documentation/technotes/tn3137-on-mac-keychains
25. CryptoKit AES-GCM: https://developer.apple.com/documentation/cryptokit/aes/gcm
26. SQLite deserialize: https://sqlite.org/c3ref/deserialize.html
27. SQLite 3.36.0 release: https://sqlite.org/releaselog/3_36_0.html
28. Apple, Data Protection overview: https://support.apple.com/guide/security/data-protection-overview-secf6276da8a/web
29. Apple, Data Protection classes: https://support.apple.com/guide/security/data-protection-classes-secb010e978a/web
30. Apple forum, Data Protection on Intel Macs: https://developer.apple.com/forums/thread/780632
31. SQLite VFS: https://sqlite.org/vfs.html
32. SQLite cksumvfs example: https://raw.githubusercontent.com/sqlite/sqlite/master/ext/misc/cksumvfs.c
33. SQLite pragmas: https://sqlite.org/pragma.html
34. Third-party secure-delete test, 2024-05-29: https://antonz.org/sqlite-secure-delete/
35. Time Machine local snapshots: https://support.apple.com/en-us/102154
36. Time Machine backup encryption: https://support.apple.com/guide/mac-help/choose-a-backup-disk-set-encryption-options-mh11421/mac
37. Excluding a file from backup: https://developer.apple.com/documentation/foundation/urlresourcekey/isexcludedfrombackupkey
38. Apple forum, error -34018 and the App ID: https://developer.apple.com/forums/thread/740164
39. Apple TN3125, provisioning profiles: https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles
40. kSecAttrAccessible: https://developer.apple.com/documentation/security/ksecattraccessible
41. Apple TN3127, code signing requirements: https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements
42. SecRandomCopyBytes: https://developer.apple.com/documentation/security/secrandomcopybytes(_:_:_:)
43. Copying or restoring keychains, 2026-09-14: https://eclecticlight.co/2026/09/14/how-can-you-copy-or-restore-keychains/
44. Hardened runtime: https://developer.apple.com/documentation/security/hardened-runtime
45. GRDB, on SQLCipher and the system SQLite: https://github.com/groue/GRDB.swift/blob/master/README.md
46. Apple, erasing by destroying keys: https://support.apple.com/guide/security/aside/sec0183122de/1/web/1
47. SQLite3 Multiple Ciphers default build: https://utelle.github.io/SQLite3MultipleCiphers/docs/installation/install_overview/
