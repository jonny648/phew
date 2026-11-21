# Third-party notices

## SQLCipher.swift 4.20.0

Phew uses [SQLCipher.swift](https://github.com/sqlcipher/SQLCipher.swift), pinned to commit `e7415c5e6b4fd9b78874bb956aad8a42b08e9966`. The dependency is fetched by Swift Package Manager and is not vendored in this repository.

The dependency's Community Edition license is reproduced below. The original license file is available [upstream](https://github.com/sqlcipher/SQLCipher.swift/blob/e7415c5e6b4fd9b78874bb956aad8a42b08e9966/LICENSE.md).

Copyright (c) 2025, ZETETIC LLC
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the ZETETIC LLC nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY ZETETIC LLC ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL ZETETIC LLC BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## Node.js 24.22.2

The release disk image bundles the official Node.js v24.22.2 runtime for Apple silicon. The runtime is downloaded by `Tools/fetch-node.sh` from [nodejs.org](https://nodejs.org/dist/v24.22.2/) and its SHA-256 checksum and code signature are checked. Its license and the bundled library notices are available in the upstream [Node.js LICENSE file](https://github.com/nodejs/node/blob/v24.22.2/LICENSE).

`Tools/make-dmg.sh` includes the downloaded Node.js license in the app bundle as `Contents/Resources/Node.js-LICENSE`. This packaging update applies to disk images built from this commit onward; previously published release images were built before that update.
