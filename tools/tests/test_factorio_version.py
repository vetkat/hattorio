from tools import factorio_version as fv


def latest(headless, experimental="2.1.25"):
    return {"stable": {"headless": headless, "alpha": "x"},
            "experimental": {"headless": experimental}}


def test_good_data_and_pin_have_no_problems():
    assert fv.problems(latest("2.1.25"), "2.1.24") == []


def test_bump_moves_the_pin_to_a_newer_stable_release():
    assert fv.bump_to("2.1.25", "2.1.24") == "2.1.25"


def test_bump_leaves_the_pin_at_the_same_or_an_older_release():
    assert fv.bump_to("2.1.24", "2.1.24") is None
    assert fv.bump_to("2.1.9", "2.1.24") is None


def test_bump_uses_numeric_order_not_text_order():
    assert fv.bump_to("2.1.100", "2.1.24") == "2.1.100"


def test_a_changed_format_is_a_problem():
    for data in [{}, [], {"stable": {}}, latest(7), latest("2.1")]:
        assert "format" in fv.problems(data, "2.1.24")[0], data


def test_a_bad_pin_is_a_problem():
    assert "X.Y.Z" in fv.problems(latest("2.1.24"), "2.1")[0]


def test_versions_gives_stable_and_experimental():
    data = {"stable": {"headless": "2.1.24"}, "experimental": {"headless": "2.1.25"}}
    assert fv.versions(data) == {"stable": "2.1.24", "experimental": "2.1.25"}


def test_versions_of_a_changed_format_is_empty():
    assert fv.versions({"stable": {}}) == {}


FOUND = {"stable": "2.1.24", "experimental": "2.1.25"}


def test_plan_tests_each_new_release_in_each_mode():
    plan = fv.plan(FOUND, "2.1.24", "abc", set())
    assert plan == [{"version": "2.1.25", "mode": "base"},
                              {"version": "2.1.25", "mode": "space-age"}]


def test_plan_skips_what_this_commit_already_tested():
    keys = {"watch-2.1.25-base-abc"}
    assert fv.plan(FOUND, "2.1.24", "abc", keys) == [
        {"version": "2.1.25", "mode": "space-age"}]
    assert len(fv.plan(FOUND, "2.1.24", "def", keys)) == 2


def test_plan_has_nothing_to_test_at_the_pin():
    same = {"stable": "2.1.24", "experimental": "2.1.24"}
    assert fv.plan(same, "2.1.24", "abc", set()) == []


def test_plan_tests_a_newer_stable_and_experimental_release():
    newer = {"stable": "2.1.25", "experimental": "2.2.0"}
    assert [m["version"] for m in fv.plan(newer, "2.1.24", "abc", set())] == [
        "2.1.25", "2.1.25", "2.2.0", "2.2.0"]


def test_retarget_sets_factorio_version_and_base():
    info = {"factorio_version": "2.1", "dependencies": ["base >= 2.1.0", "? space-age"]}
    out = fv.retarget(info, "2.2.3")
    assert out["factorio_version"] == "2.2"
    assert out["dependencies"] == ["base >= 2.2.0", "? space-age"]
    assert info["factorio_version"] == "2.1", "retarget must not change its input"
