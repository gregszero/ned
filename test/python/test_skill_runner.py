"""Tests for fang/python/skill_runner.py"""

import subprocess
import json
import os
import sys
import tempfile

SKILL_RUNNER_PATH = os.path.join(os.path.dirname(__file__), '..', '..', 'fang', 'python', 'skill_runner.py')


def run_skill(skill_code, params=None, context=None):
    """Helper to create a temp skill file and invoke skill_runner.py."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
        f.write(skill_code)
        skill_path = f.name

    try:
        payload = json.dumps({"params": params or {}, "context": context or {}})
        result = subprocess.run(
            [sys.executable, SKILL_RUNNER_PATH, skill_path],
            input=payload,
            capture_output=True,
            text=True,
            timeout=10
        )
        return json.loads(result.stdout)
    finally:
        os.unlink(skill_path)


class TestSkillRunner:
    def test_simple_skill(self):
        code = """
def call(name="World"):
    return f"Hello, {name}!"
"""
        result = run_skill(code, params={"name": "OpenFang"})
        assert result["success"] is True
        assert result["result"] == '"Hello, OpenFang!"'

    def test_skill_with_default_params(self):
        code = """
def call(greeting="Hi"):
    return greeting
"""
        result = run_skill(code)
        assert result["success"] is True
        assert result["result"] == '"Hi"'

    def test_skill_with_print_output(self):
        code = """
def call():
    print("debug info")
    return "done"
"""
        result = run_skill(code)
        assert result["success"] is True
        assert "debug info" in result["output"]

    def test_skill_runtime_error(self):
        code = """
def call():
    raise ValueError("something broke")
"""
        result = run_skill(code)
        assert result["success"] is False
        assert "ValueError" in result["error"]

    def test_skill_missing_call_function(self):
        code = """
def not_call():
    return "wrong name"
"""
        result = run_skill(code)
        assert result["success"] is False
        assert "no callable 'call' function" in result["error"]

    def test_skill_with_actions(self):
        code = """
def call():
    send_message("hello from skill")
    create_notification("Skill Done", kind="success")
    return "ok"
"""
        result = run_skill(code)
        assert result["success"] is True
        assert len(result["actions"]) == 2
        assert result["actions"][0]["type"] == "send_message"
        assert result["actions"][1]["type"] == "create_notification"

    def test_skill_has_context_access(self):
        code = """
def call():
    return context.get("key", "missing")
"""
        result = run_skill(code, context={"key": "found"})
        assert result["success"] is True
        assert result["result"] == '"found"'


class TestSkillRunnerErrors:
    def test_no_skill_file_arg(self):
        result = subprocess.run(
            [sys.executable, SKILL_RUNNER_PATH],
            input="{}",
            capture_output=True,
            text=True,
            timeout=10
        )
        data = json.loads(result.stdout)
        assert data["success"] is False
        assert "No skill file" in data["error"]

    def test_invalid_json_input(self):
        with tempfile.NamedTemporaryFile(mode='w', suffix='.py', delete=False) as f:
            f.write("def call(): return 'ok'")
            skill_path = f.name

        try:
            result = subprocess.run(
                [sys.executable, SKILL_RUNNER_PATH, skill_path],
                input="not json",
                capture_output=True,
                text=True,
                timeout=10
            )
            data = json.loads(result.stdout)
            assert data["success"] is False
            assert "Invalid input" in data["error"]
        finally:
            os.unlink(skill_path)
