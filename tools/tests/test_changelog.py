from tools import changelog

SAMPLE = """# Changelog

Intro text.

## [Unreleased]

### Added

- Wider bands.
- A long entry that
  goes on to a second line.

### Fixed

- A crash.

## [0.1.0] - 2026-11-12

### Added

- The empty mod.

[Unreleased]: https://example.com
"""


def releases():
    return changelog.parse(SAMPLE).releases


def test_parse_reads_releases_in_order():
    parsed = changelog.parse(SAMPLE)
    assert parsed.problems == ()
    assert [r.version for r in parsed.releases] == ["Unreleased", "0.1.0"]
    assert parsed.releases[1].date == "2026-11-12"
    assert parsed.releases[0].date is None


def test_parse_joins_continuation_lines():
    added = dict(releases()[0].groups)["Added"]
    assert added == ("Wider bands.",
                     "A long entry that goes on to a second line.")


def test_parse_reports_an_unknown_heading():
    parsed = changelog.parse("## [Unreleased]\n\n### Improved\n\n- x\n")
    assert any("Improved" in p for p in parsed.problems)


def test_parse_reports_a_bad_release_heading():
    parsed = changelog.parse("## 0.1.0\n")
    assert any("release heading" in p for p in parsed.problems)


def test_parse_never_raises_on_odd_input():
    for text in ["", "###", "### \n- x", "- x", "## [", "  continuation",
                 "## [Unreleased]\n  continuation\n"]:
        changelog.parse(text)


def test_render_maps_headings_to_factorio_categories():
    text = changelog.render(releases(), "0.2.0")
    assert "Version: 0.2.0\n  Features:\n    - Wider bands." in text
    assert "  Bugfixes:\n    - A crash." in text


def test_render_starts_every_block_with_99_dashes():
    lines = changelog.render(releases(), "0.2.0").splitlines()
    separators = [line for line in lines if set(line) == {"-"}]
    assert lines[0] == "-" * 99
    assert len(separators) == 2
    assert all(len(line) == 99 for line in separators)


def test_render_dates_released_versions_only():
    text = changelog.render(releases(), "0.2.0")
    assert "Version: 0.1.0\nDate: 2026-11-12\n" in text
    assert "Version: 0.2.0\n  Features" in text


def test_render_skips_an_empty_unreleased_section():
    parsed = changelog.parse(
        "## [Unreleased]\n\n## [0.1.0] - 2026-11-12\n\n### Added\n\n- x\n")
    assert changelog.render(parsed.releases, "0.1.0").count("Version:") == 1


def test_render_skips_unreleased_when_its_version_is_already_released():
    parsed = changelog.parse(
        "## [Unreleased]\n\n### Fixed\n\n- y\n\n"
        "## [0.1.0] - 2026-11-12\n\n### Added\n\n- x\n")
    text = changelog.render(parsed.releases, "0.1.0")
    assert text.count("Version: 0.1.0") == 1


def test_render_of_nothing_is_empty():
    assert changelog.render((), "0.1.0") == ""


def test_notes_give_the_markdown_of_one_version():
    assert changelog.notes(releases(), "0.1.0") == "### Added\n\n- The empty mod.\n"


def test_notes_of_a_missing_version_are_empty():
    assert changelog.notes(releases(), "9.9.9") == ""


# Factorio's rules for changelog.txt, from the auxiliary docs
# (lua-api.factorio.com/latest/auxiliary/changelog-format.html).

SEP = "-" * 99
GOOD = f"{SEP}\nVersion: 1.0.1\nDate: 2026-11-17\n  Bugfixes:\n    - A fix.\n      More text.\n"


def test_a_good_changelog_has_no_factorio_problems():
    assert changelog.factorio_problems(GOOD) == []


def test_factorio_rejects_tabs_and_trailing_spaces():
    assert any("tab" in p for p in changelog.factorio_problems(GOOD.replace("    - A", "\t- A")))
    assert any("trailing" in p for p in changelog.factorio_problems(GOOD.replace("fix.", "fix. ")))


def test_factorio_needs_a_version_line_after_the_separator():
    found = changelog.factorio_problems(GOOD.replace("Version: 1.0.1\n", ""))
    assert any("Version:" in p for p in found)


def test_factorio_rejects_bad_and_repeated_versions():
    for bad in ["0.0.0", "1.0.65536", "1.0"]:
        assert changelog.factorio_problems(GOOD.replace("1.0.1", bad)), bad
    assert any("twice" in p for p in changelog.factorio_problems(GOOD + GOOD))


def test_factorio_rejects_duplicate_lines_in_a_category():
    twice = GOOD + "    - Another.\n      More text.\n"
    assert any("duplicate" in p for p in changelog.factorio_problems(twice))


def test_factorio_needs_a_category_before_an_entry():
    found = changelog.factorio_problems(GOOD.replace("  Bugfixes:\n", ""))
    assert any("category" in p for p in found)


def test_render_wraps_long_entries_with_continuation_lines():
    long = " ".join(f"word{n}" for n in range(40))
    text = "## [1.0.0] - 2026-01-01\n\n### Fixed\n\n- " + long + "\n"
    rendered = changelog.render(changelog.parse(text).releases, "1.0.0")
    lines = rendered.splitlines()
    assert all(len(line) <= changelog.WIDTH for line in lines if line != SEP)
    assert lines[4].startswith("    - word0") and lines[5].startswith("      word")
    assert changelog.factorio_problems(rendered) == []


def test_the_real_changelog_renders_without_factorio_problems():
    import json
    import pathlib
    root = pathlib.Path(__file__).resolve().parents[2]
    parsed = changelog.parse((root / "CHANGELOG.md").read_text(encoding="utf-8"))
    version = json.loads((root / "info.json").read_text(encoding="utf-8"))["version"]
    assert parsed.problems == ()
    assert changelog.factorio_problems(changelog.render(parsed.releases, version)) == []
