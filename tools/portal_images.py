"""Add images to the gallery of the mod page on the mod portal.

    FACTORIO_API_KEY=... python3 -m tools.portal_images FIRST.jpg [MORE.jpg ...]

The script uploads each file, then sets the order of the gallery. The first
file leads the gallery. The images that the gallery has already come next,
in their order. The other new files come last, in the order given. The
showcase puts the wide shot of Nauvis first.

The key needs the "ModPortal: Edit Mods" permission. The key goes only in
the Authorization header, never in a URL or in the output. The Factorio
wiki describes the API at https://wiki.factorio.com/Mod_images_API.

This script cannot undo an upload. Run it once for each set of new
images: a second run adds the same pictures again.
"""

import json
import os
import sys
import urllib.error
import urllib.request
import uuid

API = "https://mods.factorio.com/api/v2/mods/images/"
FULL = "https://mods.factorio.com/api/mods/%s/full"


def gallery_order(current, new, first):
    """The ids in gallery order: `first`, then `current`, then `new`.

    No id comes twice. Ids are the SHA1 strings that the portal returns.
    """
    out = [first]
    for image_id in list(current) + list(new):
        if image_id not in out:
            out.append(image_id)
    return out


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """Refuse a redirect, so that the key never goes to another address."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise urllib.error.HTTPError(req.full_url, code, "redirect refused", headers, fp)


_KEYED = urllib.request.build_opener(_NoRedirect)


def _post(url, fields, key=None, files=None):
    """POST a multipart form, and return the JSON answer."""
    boundary = uuid.uuid4().hex
    body = b""
    for name, value in fields.items():
        body += ("--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n"
                 % (boundary, name, value)).encode()
    for name, path in (files or {}).items():
        with open(path, "rb") as f:
            data = f.read()
        body += ("--%s\r\nContent-Disposition: form-data; name=\"%s\"; "
                 "filename=\"%s\"\r\nContent-Type: image/jpeg\r\n\r\n"
                 % (boundary, name, os.path.basename(path))).encode() + data + b"\r\n"
    body += ("--%s--\r\n" % boundary).encode()
    request = urllib.request.Request(url, data=body, method="POST")
    request.add_header("Content-Type", "multipart/form-data; boundary=%s" % boundary)
    opener = urllib.request.build_opener()
    if key:
        request.add_header("Authorization", "Bearer %s" % key)
        opener = _KEYED
    try:
        with opener.open(request) as answer:
            return json.load(answer)
    except urllib.error.HTTPError as err:
        # The portal answers an error with JSON, such as InvalidApiKey.
        try:
            return json.load(err)
        except ValueError:
            return {"error": "HTTP %d" % err.code, "message": err.reason}


def _check(answer, step):
    if answer.get("error") or answer.get("success") is False:
        err = answer.get("error", "?")
        hint = ""
        if err in ("InvalidApiKey", "Forbidden"):
            hint = (' The key may not have the "ModPortal: Edit Mods" permission. '
                    "Add it at https://factorio.com/profile.")
        sys.exit("%s failed: %s -- %s.%s" % (step, err, answer.get("message", ""), hint))
    return answer


def main(paths):
    key = os.environ.get("FACTORIO_API_KEY")
    if not key:
        sys.exit("FACTORIO_API_KEY is not set")
    if not paths:
        sys.exit(__doc__)
    for path in paths:
        if not os.path.isfile(path):
            sys.exit("no file %s" % path)
    with open("info.json") as f:
        mod = json.load(f)["name"]
    with urllib.request.urlopen(FULL % mod) as answer:
        current = [image["id"] for image in json.load(answer).get("images", [])]
    new = []
    for path in paths:
        slot = _check(_post(API + "add", {"mod": mod}, key), "images/add")
        # The upload URL carries its own token, so it needs no key.
        image = _check(_post(slot["upload_url"], {}, files={"image": path}), "upload")
        new.append(image["id"])
        # The id lets you set the order by hand if a later step fails.
        print("uploaded %s as %s" % (path, image["id"]))
    order = gallery_order(current, new, new[0])
    _check(_post(API + "edit", {"mod": mod, "images": ",".join(order)}, key),
           "images/edit")
    print("the gallery has %d images, %s first" % (len(order), paths[0]))


if __name__ == "__main__":
    main(sys.argv[1:])
