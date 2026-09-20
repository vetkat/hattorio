#!/bin/sh
# Upload a built mod zip to the Factorio mod portal.
#
#   FACTORIO_API_KEY=... sh tools/publish_mod.sh build/hattorio_0.1.0.zip
#
# The key comes from https://factorio.com/profile and needs the
# "ModPortal: Upload Mods" permission.
#
# Two steps, per https://wiki.factorio.com/Mod_upload_API :
#   1. POST the mod name to init_upload, which returns a one-shot upload_url
#   2. POST the zip to that URL
#
# A portal release cannot be withdrawn once accepted, so every check that can
# run before this point should already have run.
set -e

ZIP="$1"
[ -n "$ZIP" ] || { echo "usage: publish_mod.sh <zip>" >&2; exit 2; }
[ -f "$ZIP" ] || { echo "no such file: $ZIP" >&2; exit 2; }
[ -n "$FACTORIO_API_KEY" ] || { echo "FACTORIO_API_KEY is not set" >&2; exit 2; }

MOD=$(python3 -c "import json;print(json.load(open('info.json'))['name'])")
VERSION=$(python3 -c "import json;print(json.load(open('info.json'))['version'])")
echo "publishing $MOD $VERSION from $ZIP"

INIT=$(curl -sS -X POST \
  -H "Authorization: Bearer $FACTORIO_API_KEY" \
  -F "mod=$MOD" \
  https://mods.factorio.com/api/v2/mods/releases/init_upload)

UPLOAD_URL=$(printf '%s' "$INIT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if 'upload_url' not in d:
    sys.exit('init_upload failed: %s -- %s' % (d.get('error', '?'), d.get('message', d)))
print(d['upload_url'])
")

RESULT=$(curl -sS -X POST -F "file=@$ZIP" "$UPLOAD_URL")

printf '%s' "$RESULT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if not d.get('success'):
    sys.exit('upload failed: %s -- %s' % (d.get('error', '?'), d.get('message', d)))
print('uploaded successfully')
"
