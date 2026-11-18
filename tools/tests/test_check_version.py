from tools import check_version as cv

RELEASED = "## [Unreleased]\n\n## [1.0.1] - 2026-11-17\n\n### Fixed\n\n- A fix.\n"
UNRELEASED = "## [Unreleased]\n\n### Fixed\n\n- Another fix.\n\n" + RELEASED.split("\n\n", 1)[1]
CHANGELOG = RELEASED


def info(**changes):
    base = {
        "name": "hattorio", "version": "1.0.1", "title": "Hattorio",
        "author": "vetkat", "factorio_version": "2.1",
        "description": "Hats.", "dependencies": ["base >= 2.1.0", "? space-age"],
    }
    base.update(changes)
    return base


def problems(manifest=None, changelog=CHANGELOG, pin="2.1.24", tag=None):
    return cv.problems(manifest or info(), changelog, pin, tag)


def test_a_consistent_release_passes():
    assert problems(tag="v1.0.1") == []


def test_factorio_version_must_follow_the_pin():
    # Factorio 2.1 refuses to load a mod that says "2.0".
    found = problems(info(factorio_version="2.0"))
    assert found and "'2.0'" in found[0] and "2.1" in found[0]


def test_base_dependency_must_follow_the_pin():
    found = problems(info(dependencies=["base >= 2.0.0", "? space-age"]))
    assert found and "base >= 2.1.0" in found[0]


def test_a_missing_key_is_a_problem():
    manifest = info()
    del manifest["author"]
    assert "'author'" in problems(manifest)[0]


def test_a_bad_pin_is_a_problem():
    assert "X.Y.Z" in problems(pin="2.1")[0]


def test_the_version_must_be_semver():
    assert any("X.Y.Z" in p for p in problems(info(version="1.0")))


def test_without_a_tag_the_newest_section_is_unreleased_or_the_version():
    assert problems(changelog=UNRELEASED) == []
    newer = "## [1.0.2] - 2026-11-18\n\n### Fixed\n\n- x\n\n" + RELEASED
    assert "1.0.2" in problems(changelog=newer.replace("## [Unreleased]\n\n", ""))[0]


def test_a_tag_needs_a_dated_section_at_the_top():
    undated = RELEASED.replace(" - 2026-11-17", "")
    assert any("no date" in p for p in problems(changelog=undated, tag="v1.0.1"))
    older = RELEASED.replace("1.0.1", "1.0.0")
    assert any("no section for 1.0.1" in p for p in problems(changelog=older, tag="v1.0.1"))


def test_a_tag_fails_while_unreleased_has_entries():
    assert any("Unreleased" in p for p in problems(changelog=UNRELEASED, tag="v1.0.1"))


def test_a_changelog_format_problem_is_reported():
    assert any("unknown heading" in p
               for p in problems(changelog=RELEASED.replace("### Fixed", "### Bugfixes")))


def test_an_empty_changelog_is_a_problem():
    assert problems(changelog="") == ["CHANGELOG.md has no release sections"]


def test_the_tag_must_name_the_version():
    assert "v1.0.0" in problems(tag="v1.0.0")[0]
