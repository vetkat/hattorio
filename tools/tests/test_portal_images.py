"""The gallery that tools/portal_images.py sets on the mod portal."""

import pytest

from tools import portal_images as pi


def fake_portal(monkeypatch, tmp_path, names):
    """Make one file per name, and a portal that gives each file its name as id.

    The fake refuses a read of the public mod API. The portal caches that
    answer, and an edit with a stale list deletes images.
    """
    monkeypatch.setenv("FACTORIO_API_KEY", "secret")
    edits = []

    def post(url, fields, key=None, files=None):
        if url == pi.API + "add":
            return {"upload_url": "https://upload"}
        if url == "https://upload":
            return {"id": files["image"].rsplit("/", 1)[-1][:-4]}
        assert url == pi.API + "edit"
        edits.append(fields["images"])
        return {"success": True}

    def no_read(*args, **kwargs):
        raise AssertionError("the public mod API was read")

    monkeypatch.setattr(pi, "_post", post)
    monkeypatch.setattr(pi.urllib.request, "urlopen", no_read)
    paths = []
    for name in names:
        path = tmp_path / ("%s.jpg" % name)
        path.write_bytes(b"jpg")
        paths.append(str(path))
    return paths, edits


def test_the_gallery_becomes_the_given_files_in_their_order(monkeypatch, tmp_path):
    paths, edits = fake_portal(monkeypatch, tmp_path, ["b", "a", "c"])
    pi.main(paths)
    assert edits == ["b,a,c"]


def test_a_file_given_twice_is_listed_once(monkeypatch, tmp_path):
    paths, edits = fake_portal(monkeypatch, tmp_path, ["a", "b"])
    pi.main(paths + paths[:1])
    assert edits == ["a,b"]


def test_after_is_refused_before_any_upload(monkeypatch, tmp_path):
    paths, edits = fake_portal(monkeypatch, tmp_path, ["a"])
    with pytest.raises(SystemExit, match="--after"):
        pi.main(["--after"] + paths)
    assert edits == []





def test_a_request_with_the_key_does_not_follow_a_redirect():
    import http.server
    import threading

    seen = []

    class Target(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            seen.append(self.headers.get("Authorization"))
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"{}")

        do_POST = do_GET

        def log_message(self, *args):
            pass

    target = http.server.HTTPServer(("127.0.0.1", 0), Target)

    class Redirect(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            self.send_response(302)
            self.send_header("Location", "http://127.0.0.1:%d/" % target.server_port)
            self.end_headers()

        def log_message(self, *args):
            pass

    source = http.server.HTTPServer(("127.0.0.1", 0), Redirect)
    for server in (target, source):
        threading.Thread(target=server.handle_request, daemon=True).start()
    answer = pi._post("http://127.0.0.1:%d/" % source.server_port, {"mod": "x"}, key="secret")
    target.server_close()
    source.server_close()
    assert seen == []
    assert answer["error"] == "HTTP 302"

