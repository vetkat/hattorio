import pathlib

from tools import pr_checks as pc


def test_conventional_titles_pass():
    for title in ["fix: target Factorio 2.1", "feat(bands)!: wider bands",
                  "ci: bump actions/checkout from 4 to 7"]:
        assert pc.title_problems(title) == [], title


def test_other_titles_fail():
    for title in ["Fix things", "release: 1.0.0", "fix:no space", "feat: "]:
        assert pc.title_problems(title), title


def test_a_long_title_fails():
    assert "72" in pc.title_problems("docs: " + "x" * 70)[0]


def test_mod_code_needs_a_changelog_entry():
    found = pc.changelog_problems(["mod/terrain.lua"], [])
    assert found and "mod/terrain.lua" in found[0]


def test_a_changelog_entry_or_the_label_passes():
    assert pc.changelog_problems(["mod/terrain.lua", "CHANGELOG.md"], []) == []
    assert pc.changelog_problems(["mod/terrain.lua"], ["no-changelog"]) == []


def test_files_that_do_not_ship_need_no_entry():
    changed = ["docs/design/hattorio-design.md", "tools/verify.py", "spec/bands_spec.lua",
               "tests/ingame/smoke_test.lua", ".github/workflows/check.yml", "wiki/Home.md"]
    assert pc.changelog_problems(changed, []) == []


def test_every_shipped_entry_counts_as_mod_code():
    for path in ["info.json", "control.lua", "locale/en/hattorio.cfg", "hat/tiling.lua",
                 "data/hat_rules.lua", "prototypes/tiles.lua"]:
        assert pc.is_mod_code(path), path


GOOD_BODY = """## What changes

Stuff.

## Review angles

- Multiplayer safety: pass
- Save compatibility: fixed: nil check for the new storage key
- Mod compatibility: minor: a surface that already has chunks keeps them
- Performance (UPS): n/a
- Test quality: pass
- Security: N/A
"""


def test_a_filled_review_section_passes():
    assert pc.review_problems(GOOD_BODY, [], "vetkat") == []


def test_a_missing_review_section_fails():
    assert pc.review_problems("## What changes\n\nStuff.\n", [], "vetkat")
    assert pc.review_problems(None, [], "vetkat")


def test_a_blank_verdict_fails():
    body = GOOD_BODY.replace("Test quality: pass", "Test quality:")
    found = pc.review_problems(body, [], "vetkat")
    assert len(found) == 1 and "Test quality" in found[0]


def test_a_missing_angle_fails():
    body = GOOD_BODY.replace("- Security: N/A\n", "")
    assert any("Security" in p for p in pc.review_problems(body, [], "vetkat"))


def test_an_open_finding_fails():
    body = GOOD_BODY.replace("Mod compatibility: minor: a surface that already has chunks keeps them",
                             "Mod compatibility: Important: a copied chunk gets its ore twice")
    found = pc.review_problems(body, [], "vetkat")
    assert len(found) == 1 and "Mod compatibility" in found[0]


def test_the_section_ends_at_the_next_heading():
    body = GOOD_BODY.replace("- Security: N/A\n", "") + "\n## Notes\n\n- Security: pass\n"
    assert any("Security" in p for p in pc.review_problems(body, [], "vetkat"))


def test_the_label_and_dependabot_skip_the_rule():
    assert pc.review_problems("", ["no-review"], "vetkat") == []
    assert pc.review_problems("", [], "dependabot[bot]") == []


def test_the_template_asks_for_every_angle():
    template = pathlib.Path(".github/pull_request_template.md").read_text(encoding="utf-8")
    lines = pc.review_section(template).splitlines()
    assert [line[2:-1] for line in lines if line.startswith("- ")] == list(pc.ANGLES)
