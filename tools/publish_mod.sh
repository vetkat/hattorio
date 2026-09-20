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
#
#   FACTORIO_API_KEY=... sh tools/publish_mod.sh --check
#
# --check runs only step 1, which validates the key and the mod name without
# publishing anything: a release reaches the portal only when the zip is
# POSTed in step 2.
set -e

ZIP="$1"
[ -n "$ZIP" ] || { echo "usage: publish_mod.sh <zip>|--check" >&2; exit 2; }
[ -n "$FACTORIO_API_KEY" ] || { echo "FACTORIO_API_KEY is not set" >&2; exit 2; }

CHECK_ONLY=no
if [ "$ZIP" = "--check" ]; then
  CHECK_ONLY=yes
else
  [ -f "$ZIP" ] || { echo "no such file: $ZIP" >&2; exit 2; }
fi

MOD=$(python3 -c "import json;print(json.load(open('info.json'))['name'])")
VERSION=$(python3 -c "import json;print(json.load(open('info.json'))['version'])")
if [ "$CHECK_ONLY" = yes ]; then
  echo "checking credentials for $MOD (nothing will be published)"
else
  echo "publishing $MOD $VERSION from $ZIP"
fi

INIT=$(curl -sS -X POST \
  -H "Authorization: Bearer $FACTORIO_API_KEY" \
  -F "mod=$MOD" \
  https://mods.factorio.com/api/v2/mods/releases/init_upload)

# A key that works but names a mod the portal has never seen reports
# UnknownMod. That is the expected answer before the first manual upload, and
# it still proves the key is good -- so report it distinctly rather than as a
# flat failure.
UPLOAD_URL=$(printf '%s' "$INIT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if 'upload_url' in d:
    print(d['upload_url']); sys.exit(0)
err = d.get('error', '?')
if err == 'UnknownMod':
    sys.exit(\"AUTH OK, but the portal has no mod named '\" + '$MOD' + \"' yet. \"
             'The first release of a new mod must be uploaded by hand at '
             'https://mods.factorio.com/upload -- init_upload only adds '
             'releases to a mod that already exists.')
if err == 'InvalidApiKey':
    sys.exit('AUTH FAILED: the API key is rejected. Check it has the '
             '\"ModPortal: Upload Mods\" permission.')
sys.exit('init_upload failed: %s -- %s' % (err, d.get('message', d)))
")

if [ "$CHECK_ONLY" = yes ]; then
  echo "AUTH OK, and the portal already knows $MOD -- a real publish would proceed"
  exit 0
fi

RESULT=$(curl -sS -X POST -F "file=@$ZIP" "$UPLOAD_URL")

printf '%s' "$RESULT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if not d.get('success'):
    sys.exit('upload failed: %s -- %s' % (d.get('error', '?'), d.get('message', d)))
print('uploaded successfully')
"
