import json
import sys
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).parent))
import guard


def test_dangerous_command_blocks_pretool(capsys):
    payload = {"tool_input": {"command": "git reset --hard"}}

    guard.handle_policy("pre-tool-use", payload)

    output = json.loads(capsys.readouterr().out)
    assert output["decision"] == "block"
    assert "hard resets" in output["reason"]


def test_soft_tdd_missing_test_warns_without_block(tmp_path, capsys):
    payload = {"tool_input": {"path": "src/service.py"}}
    with patch.object(guard, "ROOT", tmp_path):
        with patch("checks.guard_mode", return_value="soft"):
            status = guard.handle_tdd(payload)

    captured = capsys.readouterr()
    assert status == 0
    assert captured.out == ""
    assert "WARNING: TDD Guard" in captured.err


def test_hard_tdd_missing_test_blocks(tmp_path, capsys):
    payload = {"tool_input": {"path": "src/service.py"}}
    with patch.object(guard, "ROOT", tmp_path):
        with patch("checks.guard_mode", return_value="hard"):
            guard.handle_tdd(payload)

    output = json.loads(capsys.readouterr().out)
    assert output["decision"] == "block"
    assert "src/service.py" in output["reason"]


def test_java_candidate_tests_include_spring_layout():
    candidates = guard.candidate_tests("src/main/java/com/example/UserService.java")

    assert Path("src/test/java/com/example/UserServiceTest.java") in candidates
    assert Path("src/test/java/com/example/UserServiceTests.java") in candidates


def test_python_source_matches_tests_layout(tmp_path):
    test_path = tmp_path / "tests" / "test_service.py"
    test_path.parent.mkdir()
    test_path.write_text("def test_ok(): pass")

    assert guard.has_matching_test("src/service.py", tmp_path)


def test_docs_and_phase_paths_are_skipped():
    assert guard.should_skip("docs/PRD.md")
    assert guard.should_skip("phases/0-mvp/step0.md")
