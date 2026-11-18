"""Static checks on the workflows and the Makefile, for rules that only fail on GitHub."""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(name):
    return (ROOT / ".github/workflows" / name).read_text(encoding="utf-8")


def job(text, name):
    """The text of one job, up to the next job."""
    start = text.index(f"\n  {name}:\n")
    following = re.search(r"\n  [\w-]+:\n", text[start + 1:])
    return text[start:start + 1 + following.start()] if following else text[start:]


def test_check_uses_no_secrets():
    assert "secrets." not in read("check.yml")


def test_all_checks_needs_every_job():
    text = read("check.yml")
    jobs = re.findall(r"^  ([\w-]+):\n", text[text.index("\njobs:\n"):], re.MULTILINE)
    needs = re.search(r"needs: \[(.*)\]", job(text, "all-checks"))[1].split(", ")
    assert sorted(needs) == sorted(j for j in jobs if j != "all-checks")


def test_pr_checks_run_again_when_title_or_labels_change():
    assert ("types: [opened, synchronize, reopened, edited, labeled, unlabeled]"
            in read("pr.yml"))
    assert "python3 -m tools.pr_checks" in read("pr.yml")


def test_ci_runs_every_make_target_of_make_check():
    text = read("check.yml")
    for target in ["make version", "make pytest", "make test", "make lint",
                   "make markdown", "make links", "make ingame"]:
        assert target in text, target


def test_a_release_runs_the_checks_first():
    text = read("release.yml")
    assert "uses: ./.github/workflows/check.yml" in text
    assert "needs: checks" in job(text, "build")


def test_a_release_tag_must_be_on_main():
    assert "git merge-base --is-ancestor" in job(read("release.yml"), "build")


def test_the_portal_upload_runs_only_on_a_tag_or_on_request():
    publish = job(read("release.yml"), "publish")
    assert "github.event_name == 'push' || inputs.mode == 'publish'" in publish
    assert "environment: mod-portal" in publish


def test_every_job_that_uses_the_key_is_in_the_portal_environment():
    text = read("release.yml")
    jobs = re.findall(r"^  ([\w-]+):\n", text[text.index("\njobs:\n"):], re.MULTILINE)
    for name in jobs:
        body = job(text, name)
        if "secrets." in body:
            assert "environment: mod-portal" in body, name


def test_the_hook_runs_make_fast():
    hook = (ROOT / ".githooks/pre-commit").read_text(encoding="utf-8")
    assert hook.rstrip().endswith("exec make fast")


def test_watch_tests_new_releases_often_and_in_game():
    text = read("watch.yml")
    assert re.search(r'cron: "\d+ \*/3 \* \* \*"', text), "watch must run every three hours"
    assert "python3 -m tools.factorio_version plan" in job(text, "plan")
    ingame = job(text, "ingame")
    assert "include: ${{ fromJSON(needs.plan.outputs.matrix) }}" in ingame
    assert "python3 -m tools.factorio_version retarget ${{ matrix.version }}" in ingame
    assert "FACTORIO_VERSION: ${{ matrix.version }}" in ingame


def test_the_portal_description_uses_the_long_description():
    script = (ROOT / "tools/portal_details.sh").read_text(encoding="utf-8")
    assert '-F "description=<mod-description-long.md"' in script
    assert "sh tools/portal_details.sh" in job(read("release.yml"), "description")
