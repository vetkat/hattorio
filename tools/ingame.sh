#!/usr/bin/env bash
# Runs the in-game tests in the Factorio headless server.
#   tools/ingame.sh             base game only, then with Space Age
#   tools/ingame.sh base        base game only
#   tools/ingame.sh space-age   with Space Age
# The server and the factorio-test mod come in the pinned versions. No
# login is needed: the server is a free download, and the factorio-test
# zip is in tools/vendor/. FACTORIO_VERSION=X.Y.Z tests another release of
# the server; watch.yml uses it for new releases.
set -euo pipefail

modes=${1:-base space-age}
case "$modes" in
  base|space-age|"base space-age") ;;
  *) echo "usage: tools/ingame.sh [base|space-age]" >&2; exit 2 ;;
esac

root=$(cd "$(dirname "$0")/.." && pwd)
version=${FACTORIO_VERSION:-$(tr -d '[:space:]' < "$root/.factorio-version")}
ft_version=$(tr -d '[:space:]' < "$root/.factorio-test-version")
cache=${FACTORIO_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/hattorio}
server="$cache/factorio-$version"
binary="$server/bin/x64/factorio"
# The data folder must not sit inside the mod folder: the CLI links the
# mod folder into the data folder's mods/, which would make a loop.
data=$(mktemp -d)
trap 'rm -rf "$data"' EXIT

if [ ! -x "$binary" ]; then
  echo "ingame: downloading the Factorio $version headless server"
  mkdir -p "$cache"
  tmp=$(mktemp -d "$cache/download.XXXXXX")
  curl -fsSL "https://www.factorio.com/get-download/$version/headless/linux64" \
    | tar -xJ -C "$tmp"
  mv "$tmp/factorio" "$server"
  rmdir "$tmp"
fi

mkdir -p "$data/mods"
cp "$root/tools/vendor/factorio-test_$ft_version.zip" "$data/mods/"

run() {
  npx --no-install factorio-test run --mod-path "$root" \
    --factorio-path "$binary" --data-directory "$data" --forbid-only "$@"
}

for mode in $modes; do
  echo "ingame: $mode"
  if [ "$mode" = space-age ]; then
    run --mods space-age --tag-blacklist base
  else
    run --tag-blacklist space-age
  fi
done
