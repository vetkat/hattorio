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
                 "data/hat_constants.lua", "prototypes/tiles.lua"]:
        assert pc.is_mod_code(path), path
