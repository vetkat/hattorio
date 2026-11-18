from tools import review_stamp as rs

HEREDOC = "git commit -q -F - <<'EOF'\nfeat: don't stop\n\nmore text\nEOF"


def test_commits_are_recognised():
    for command in ["git commit -m x", "cd repo && git commit -m x",
                    "git -C /repo commit -m x", "git --no-pager commit",
                    "make fast; git commit --amend --no-edit",
                    "make fast\ngit commit -m x", HEREDOC]:
        assert rs.is_commit(command), command


def test_other_commands_are_not_commits():
    for command in ["git status", "git log --grep commit", 'echo "git commit"',
                    "make fast", "git commit-tree abc"]:
        assert not rs.is_commit(command), command


def test_guard_passes_a_commit_while_the_git_hook_is_active():
    for command in ["git commit -m x", "git commit -am x", "git commit -m x f", HEREDOC]:
        assert rs.guard(command, ".githooks") == (0, ""), command


def test_guard_ignores_other_commands():
    assert rs.guard("git status", None) == (0, "")


def test_guard_blocks_a_commit_without_the_git_hook():
    code, message = rs.guard("git commit -m x", None)
    assert code == 2 and "make setup" in message


def test_guard_blocks_skipping_the_git_hook():
    for command in ["git commit --no-verify -m x", "git commit -n -m x",
                    "git commit -qn -m x"]:
        code, message = rs.guard(command, ".githooks")
        assert code == 2 and "--no-verify" in message, command


def test_check_passes_a_current_stamp():
    assert rs.check("tree1", "tree1") == (0, "")


def test_check_blocks_a_missing_or_old_stamp():
    for tree, stamp in [("tree1", None), ("tree2", "tree1"), (None, None)]:
        code, message = rs.check(tree, stamp)
        assert code == 1, (tree, stamp)
        for step in ["/ste80-humanizer", "/simplify", "make stamp"]:
            assert step in message
