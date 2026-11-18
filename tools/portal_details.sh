#!/bin/sh
# Send the long description in mod-description-long.md to the mod portal.
#
#   FACTORIO_API_KEY=... sh tools/portal_details.sh
#
# The release workflow runs this after each upload, so the portal page
# describes the newest release. A manual run of the workflow in the mode
# "description" runs it alone.
#
# The key needs the "ModPortal: Edit Mods" permission, in addition to the
# "ModPortal: Upload Mods" permission that tools/publish_mod.sh needs. You
# set the permissions at https://factorio.com/profile. The API is described
# at https://wiki.factorio.com/Mod_details_API.
set -e

[ -n "$FACTORIO_API_KEY" ] || { echo "FACTORIO_API_KEY is not set" >&2; exit 2; }
MOD=$(python3 -c "import json;print(json.load(open('info.json'))['name'])")
echo "sending mod-description-long.md to the portal page of $MOD"

# curl reads the field value from the file when it starts with <.
RESULT=$(curl -sS -X POST \
  -H "Authorization: Bearer $FACTORIO_API_KEY" \
  -F "mod=$MOD" \
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
