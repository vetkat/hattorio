from tools import prose


def lines(text):
    return text.split("\n")


def test_markdown_keeps_the_line_count():
    text = "a\n```\ncode\n```\nb\n"
    assert len(lines(prose.markdown_prose(text))) == len(lines(text))


def test_markdown_drops_code_blocks_and_spans():
    out = prose.markdown_prose("The `color` key.\n```lua\nlocal color = 1\n```\n")
    assert "color" not in out
    assert "The" in out and "key." in out


def test_markdown_drops_tilde_fences():
    assert "color" not in prose.markdown_prose("~~~\ncolor\n~~~\n")


def test_markdown_drops_link_targets_and_urls():
    out = prose.markdown_prose(
        "See [the docs](https://example.com/colour) and <https://x.org>.\n")
    assert "example" not in out and "x.org" not in out
    assert "the docs" in out


def test_lua_keeps_comments_only():
    out = prose.lua_prose('local color = 1 -- the colour of the larva\n'
                          'print("-- not a comment")\n')
    assert lines(out) == ["the colour of the larva", "", ""]


def test_lua_block_comments_span_lines():
    out = prose.lua_prose("--[[ first line\nsecond line ]] local x = 1\n")
    assert lines(out)[:2] == ["first line", "second line"]


def test_lua_long_strings_are_not_prose():
    out = prose.lua_prose("local s = [[ -- not a comment\nstill a string ]]\n")
    assert out.strip() == ""


def test_lua_doc_comment_dashes_are_dropped():
    assert prose.lua_prose("--- A doc comment.\n") == "A doc comment.\n"


def test_locale_keeps_values_only():
    text = "[mod-name]\nabominable-ordnance=Abominable Ordnance\n; a comment\n"
    assert lines(prose.locale_prose(text)) == ["", "Abominable Ordnance", "", ""]


def test_locale_drops_placeholders_and_rich_text():
    out = prose.locale_prose("[x]\nk=Fires __1__ [item=iron-plate] larvae\n")
    assert "__1__" not in out and "iron-plate" not in out and "larvae" in out


def test_markdown_drops_link_definitions():
    text = "See [it][a].\n\n[a]: docs/design.md#a-long-anchor\n  [b]: <https://x.org> \"Title\"\n"
    out = prose.markdown_prose(text)
    assert lines(out)[2:4] == ["", ""]
    assert prose.without_link_definitions(text).split("\n")[2:4] == ["", ""]


def test_lua_comment_code_spans_and_annotations_are_not_prose():
    out = prose.lua_prose("-- the `color` field is read\n---@param color Color\n")
    assert lines(out)[:2] == ["the field is read", ""]


def test_markdown_drops_reference_labels():
    out = prose.markdown_prose("See [the design][color-section] and [it][].\n")
    assert "color" not in out and "the design" in out


PY = '''"""Build the zip.

The archive holds `info.json` at its root.

    python3 -m tools.package
"""
import json  # the stdlib parser
x = "# not a comment"


def f():
    """Return one."""
    return 1
'''


def test_python_keeps_the_line_count():
    assert len(prose.python_prose(PY).split("\n")) == len(PY.split("\n"))


def test_python_keeps_comments_and_docstrings():
    lines = prose.python_prose(PY).split("\n")
    assert lines[0] == "Build the zip."
    assert lines[6] == "the stdlib parser"
    assert lines[11] == "Return one."


def test_python_drops_code_strings_code_spans_and_indented_examples():
    lines = prose.python_prose(PY).split("\n")
    assert lines[2] == "The archive holds at its root."
    assert lines[4] == ""
    assert lines[7] == ""


def test_python_that_does_not_parse_has_no_prose():
    assert prose.python_prose("def (:\n") == "\n"


def test_hash_comments_keep_full_line_comments_only():
    text = "#!/bin/sh\n# Upload the zip.\nset -e  # not this\n\t@# A recipe note.\n## a target\n"
    assert prose.hash_prose(text).split("\n") == [
        "", "Upload the zip.", "", "A recipe note.", "a target", ""]


def test_lua_ldoc_tags_are_not_prose():
    text = "--- Paint a chunk.\n--- @param area  the chunk; right is exclusive\n-- @return nothing\n"
    assert prose.lua_prose(text).split("\n") == ["Paint a chunk.", "", "", ""]


def test_lua_indented_comment_lines_are_preformatted():
    text = "-- At band 3:\n--\n--   size  cell area\n--     15     63 t\n-- The end.\n"
    assert prose.lua_prose(text).split("\n") == ["At band 3:", "", "", "", "The end.", ""]


def test_hash_and_python_indented_comment_lines_are_preformatted():
    text = "# Three results:\n#   upload_url    the key works\n"
    assert prose.hash_prose(text).split("\n") == ["Three results:", "", ""]
    assert prose.python_prose(text).split("\n") == ["Three results:", "", ""]
