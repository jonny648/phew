#!/bin/zsh
# Downloads the one Node release Phew ships inside the app, for Apple silicon, and checks its fingerprint against the
# value written here. Result: Vendor/node/node (git-ignored: over 100 MB). Run once; Tools/make-dmg.sh needs it.
# To move to a newer release: change both lines below from https://nodejs.org/dist/<version>/SHASUMS256.txt, and pick
# a long-term-support release at least two weeks old.
set -euo pipefail
version=v24.22.2
sha=1f5ac075be50bed4780ea3be19a007fda95ea4d527d28d76d0b91de47d915115
root=${0:A:h:h}; dest="$root/Vendor/node"; name="node-$version-darwin-arm64"
if [[ -x $dest/node && $(cat "$dest/VERSION" 2>/dev/null) == "$version" ]]; then echo "$dest/node ($version, already here)"; exit 0; fi
work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
curl -fsSL --max-time 300 -o "$work/node.tar.xz" "https://nodejs.org/dist/$version/$name.tar.xz"
got=$(shasum -a 256 "$work/node.tar.xz" | awk '{print $1}')
[[ $got == "$sha" ]] || { echo "fetch-node: the download's fingerprint is $got, not the one written here" >&2; exit 1; }
tar -xJf "$work/node.tar.xz" -C "$work" "$name/bin/node" "$name/LICENSE"
# The program must still carry the Node.js project's own signature, unchanged.
codesign --verify --strict "$work/$name/bin/node"
mkdir -p "$dest"; mv -f "$work/$name/bin/node" "$dest/node"; mv -f "$work/$name/LICENSE" "$dest/LICENSE"; echo "$version" > "$dest/VERSION"
echo "$dest/node ($version)"
