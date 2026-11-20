#!/bin/sh
# Send the long description in mod-description-long.md to the mod portal,
# and the description in info.json as the summary. Factorio shows the
# summary in the list of mods that you can download.
#
#   FACTORIO_API_KEY=... sh tools/portal_details.sh
#
# description.yml runs this when the file changes on main. release.yml runs
# it after each upload, and alone in the mode "description".
#
# The key needs the "ModPortal: Edit Mods" permission, in addition to the
# "ModPortal: Upload Mods" permission that tools/publish_mod.sh needs. You
# set the permissions at https://factorio.com/profile. The Factorio wiki
# describes the API at https://wiki.factorio.com/Mod_details_API.
set -e

[ -n "$FACTORIO_API_KEY" ] || { echo "FACTORIO_API_KEY is not set" >&2; exit 2; }
MOD=$(python3 -c "import json;print(json.load(open('info.json'))['name'])")
SUMMARY=$(python3 -c "import json;print(json.load(open('info.json'))['description'])")
echo "sending mod-description-long.md to the portal page of $MOD"

# curl reads the field value from the file when it starts with <.
RESULT=$(curl -sS -X POST \
  -H "Authorization: Bearer $FACTORIO_API_KEY" \
  -F "mod=$MOD" \
  --form-string "summary=$SUMMARY" \
  -F "description=<mod-description-long.md" \
  https://mods.factorio.com/api/v2/mods/edit_details)

printf '%s' "$RESULT" | python3 -c "
import json, sys
d = json.load(sys.stdin)
if d.get('success'):
    print('the portal description is up to date')
    sys.exit(0)
err = d.get('error', '?')
hint = ''
if err in ('InvalidApiKey', 'Forbidden'):
    hint = (' The key may not have the \"ModPortal: Edit Mods\" permission. '
            'Add it at https://factorio.com/profile.')
sys.exit('edit_details failed: %s -- %s.%s' % (err, d.get('message', d), hint))
"
