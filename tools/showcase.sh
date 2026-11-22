#!/usr/bin/env bash
# Build the showcase bases in the game, and record their screenshots and
# clips.
#
#   tools/showcase.sh                  all five planets
#   tools/showcase.sh nauvis gleba     only these planets
#
# This runs the Steam copy of Factorio with graphics, because
# game.take_screenshot needs a renderer. The game gets its own config, mods
# and save folders, so the normal game of the owner stays as it is. A window
# opens while the script runs.
#
# Output:
#   docs/preview/showcase/<planet>-5.jpg and <planet>-wide.jpg
#   ~/Videos/hattorio-showcase/stills/<planet>-<1..4>.jpg
#   ~/Videos/hattorio-showcase/<planet>-<stage>.mp4, silent
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
planets=${*:-nauvis vulcanus fulgora gleba aquilo}
binary=${FACTORIO_BINARY:-$HOME/.local/share/Steam/steamapps/common/Factorio/bin/x64/factorio}
work=${SHOWCASE_WORK:-${XDG_CACHE_HOME:-$HOME/.cache}/hattorio/showcase}
videos=${SHOWCASE_VIDEOS:-$HOME/Videos/hattorio-showcase}
shots_out=$root/docs/preview/showcase
stills=$videos/stills
limit=${SHOWCASE_TIMEOUT:-3600}
# A stage takes well under a minute. Without a new SHOWCASE line for this
# long, the run counts as stuck and stops.
idle_limit=${SHOWCASE_IDLE:-300}

[ -x "$binary" ] || { echo "showcase: no Factorio at $binary" >&2; exit 2; }
for p in $planets; do
  case $p in
    nauvis | vulcanus | fulgora | gleba | aquilo) ;;
    *) echo "showcase: no planet $p" >&2; exit 2 ;;
  esac
done
# The script deletes the work folder on each run, so it takes only a folder
# named showcase.
case $work in
  */showcase) ;;
  *) echo "showcase: SHOWCASE_WORK must end in /showcase, not $work" >&2; exit 2 ;;
esac
for tool in ffmpeg magick; do
  command -v "$tool" >/dev/null || { echo "showcase: $tool is missing" >&2; exit 2; }
done

# A fresh work folder, so that old frames or shots cannot count.
rm -rf "$work"
mkdir -p "$work/write" "$work/mods" "$videos" "$shots_out" "$stills"
ln -s "$root" "$work/mods/hattorio"
cp -r "$root/tools/showcase" "$work/mods/hattorio-showcase"
{
  printf 'return {'
  for p in $planets; do printf ' "%s",' "$p"; done
  printf ' }\n'
} > "$work/mods/hattorio-showcase/planets.lua"
# Since 2.1 the recycler is a mod of its own, and Fulgora needs it. The
# game enables a built-in mod that the list leaves out, but the list names
# it so that the run does not depend on that.
cat > "$work/mods/mod-list.json" <<'EOF'
{"mods": [
  {"name": "base", "enabled": true},
  {"name": "space-age", "enabled": true},
  {"name": "quality", "enabled": true},
  {"name": "recycler", "enabled": true},
  {"name": "elevated-rails", "enabled": true},
  {"name": "hattorio", "enabled": true},
  {"name": "hattorio-showcase", "enabled": true}
]}
EOF
printf '[path]\nread-data=__PATH__executable__/../../data\nwrite-data=%s\n' \
  "$work/write" > "$work/config.ini"

# Without these, the Steam copy restarts itself through Steam and drops the
# command line.
export SteamAppId=427520 SteamGameId=427520
run() { "$binary" -c "$work/config.ini" --mod-directory "$work/mods" "$@"; }

run --create "$work/write/showcase.zip" --map-gen-seed 1 > "$work/create.log" 2>&1 ||
  { tail -20 "$work/create.log" >&2; exit 1; }

log=$work/write/factorio-current.log
: > "$log"
run --load-game "$work/write/showcase.zip" > "$work/run.log" 2>&1 &
game=$!
# The Steam binary is a wrapper that starts the game as a child, so the
# script stops every game that uses this config, not only the wrapper.
stop_game() { pkill -f -- "-c $work/config.ini" 2>/dev/null || true; }
trap stop_game EXIT

frames=$work/write/script-output/showcase/frames
shots=$work/write/script-output/showcase/shots
seen=0
status=running
start=$(date +%s)
last=$start
while [ "$status" = running ]; do
  if ! kill -0 "$game" 2>/dev/null; then
    echo "showcase: the game stopped before SHOWCASE DONE" >&2
    status=failed
    break
  fi
  now=$(date +%s)
  if [ $((now - start)) -gt "$limit" ]; then
    echo "showcase: no SHOWCASE DONE after $limit s" >&2
    status=failed
    break
  fi
  if [ $((now - last)) -gt "$idle_limit" ]; then
    echo "showcase: no new SHOWCASE line for $idle_limit s, so the run stops" >&2
    status=failed
    break
  fi
  # wc counts newlines, so a line that the game is still writing does not
  # count yet.
  # The game can move the log aside while it starts.
  [ -f "$log" ] || { sleep 2; continue; }
  lines=$(wc -l < "$log")
  if [ "$lines" -gt "$seen" ]; then
    while IFS= read -r line; do
      case $line in *"SHOWCASE "*) last=$(date +%s) ;; esac
      case $line in
        *"SHOWCASE CLIP "*)
          set -- ${line##*SHOWCASE CLIP }
          name=$1-$2
          # The script logs this line when the game saves no more frames
          # (set_wait_for_screenshots_to_finish).
          # With this flag, ffmpeg does not read the lines of this loop.
          ffmpeg -nostdin -v error -y -framerate 60 -i "$frames/$name/%04d.jpg" \
            -c:v libx264 -pix_fmt yuv420p -an "$videos/$name.mp4"
          rm -rf "${frames:?}/$name"
          echo "showcase: clip $name"
          ;;
        *"SHOWCASE STAGE "* | *"SHOWCASE WORKING "*)
          echo "showcase: ${line##*SHOWCASE }"
          ;;
        *"SHOWCASE ERROR "* | *"Error "*)
          echo "showcase: ${line}" >&2
          status=failed
          ;;
        *"SHOWCASE DONE"*)
          [ "$status" = running ] && status=done
          ;;
      esac
    done < <(sed -n "$((seen + 1)),${lines}p" "$log")
    seen=$lines
  fi
  sleep 2
done

stop_game
wait "$game" 2>/dev/null || true
[ "$status" = done ] || exit 1

# Stage 5 and the wide shot of each planet go to the repository and the mod
# page. The other stills go next to the clips, for the video.
count=0
for p in $planets; do
  for n in 1 2 3 4 5 wide; do
    png=$shots/$p-$n.png
    [ -f "$png" ] || { echo "showcase: missing $p-$n.png" >&2; exit 1; }
    case $n in
      5 | wide) out=$shots_out ;;
      *) out=$stills ;;
    esac
    magick "$png" -quality 85 "$out/$p-$n.jpg"
    count=$((count + 1))
  done
  for n in 1 2 3 4 5; do
    [ -f "$videos/$p-$n.mp4" ] || { echo "showcase: missing clip $p-$n" >&2; exit 1; }
  done
done
if [ -n "$(ls -A "$frames" 2>/dev/null)" ]; then
  echo "showcase: frames left in $frames" >&2
  exit 1
fi
echo "showcase: $count screenshots, stage 5 and wide in $shots_out, the rest in $stills, clips in $videos"
