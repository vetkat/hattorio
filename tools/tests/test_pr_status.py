from tools import pr_status


def run(name="all-checks", status="COMPLETED", conclusion="SUCCESS"):
    return {"__typename": "CheckRun", "name": name, "status": status,
            "conclusion": conclusion}


def test_a_failed_all_checks_is_red():
    assert pr_status.red([run(conclusion="FAILURE"), run("lua")])


def test_a_passed_all_checks_is_not_red():
    assert not pr_status.red([run()])


def test_a_cancelled_run_beside_a_passed_one_is_not_red():
    # A PR edit cancels the run it replaces, and that run reports a red
    # all-checks next to the green one.
    assert not pr_status.red([run(conclusion="FAILURE"), run()])


def test_a_run_in_progress_is_not_red_yet():
    assert not pr_status.red([run(conclusion="FAILURE"),
                              run(status="IN_PROGRESS", conclusion="")])


def test_other_jobs_and_status_contexts_do_not_count():
    assert not pr_status.red([run("lua", conclusion="FAILURE"),
                              {"__typename": "StatusContext", "context": "all-checks",
                               "state": "FAILURE"}])


def test_no_checks_and_bad_data_are_not_red():
    assert not pr_status.red([])
    assert not pr_status.red(None)
    assert not pr_status.red([None, 7, {"name": "all-checks"}])


def test_main_reads_json_and_exits_1_when_red():
    assert pr_status.main('[{"name": "all-checks", "status": "COMPLETED", '
                          '"conclusion": "FAILURE"}]') == 1
    assert pr_status.main("[]") == 0
    assert pr_status.main("not json") == 0
