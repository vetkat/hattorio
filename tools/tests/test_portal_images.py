"""The gallery order that tools/portal_images.py sets on the mod portal."""

from tools import portal_images as pi


def test_the_first_image_leads_and_the_current_ones_stay():
    assert pi.gallery_order(["a", "b"], ["c", "d"], "c") == ["c", "a", "b", "d"]


def test_an_image_that_is_already_there_is_not_doubled():
    assert pi.gallery_order(["a", "c"], ["c", "d"], "d") == ["d", "a", "c"]


def test_a_new_image_that_comes_twice_is_listed_once():
    assert pi.gallery_order([], ["c", "c", "d"], "c") == ["c", "d"]


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


def test_new_images_can_follow_the_current_ones():
    assert pi.gallery_order(["a"], ["b", "c"], "a") == ["a", "b", "c"]
