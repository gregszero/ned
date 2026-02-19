"""Tests for fang/python/bridge.py"""

import subprocess
import json
import os
import sys

BRIDGE_PATH = os.path.join(os.path.dirname(__file__), '..', '..', 'fang', 'python', 'bridge.py')


def run_bridge(code, context=None):
    """Helper to invoke bridge.py and parse output."""
    payload = json.dumps({"code": code, "context": context or {}})
    result = subprocess.run(
        [sys.executable, BRIDGE_PATH],
        input=payload,
        capture_output=True,
        text=True,
        timeout=10
    )
    return json.loads(result.stdout)


class TestBridgeExpressions:
    def test_simple_expression(self):
        result = run_bridge("2 + 2")
        assert result["success"] is True
        assert result["result"] == "4"

    def test_string_expression(self):
        result = run_bridge("'hello ' + 'world'")
        assert result["success"] is True
        assert result["result"] == '"hello world"'

    def test_list_expression(self):
        result = run_bridge("[1, 2, 3]")
        assert result["success"] is True
        assert result["result"] == "[1, 2, 3]"


class TestBridgeStatements:
    def test_print_capture(self):
        result = run_bridge("print('hello')")
        assert result["success"] is True
        assert "hello" in result["output"]

    def test_multi_statement(self):
        code = "x = 10\ny = 20\nresult = x + y"
        result = run_bridge(code)
        assert result["success"] is True
        assert result["result"] == "30"

    def test_print_and_result(self):
        code = "print('debug')\nresult = 42"
        result = run_bridge(code)
        assert result["success"] is True
        assert result["result"] == "42"
        assert "debug" in result["output"]


class TestBridgeErrors:
    def test_syntax_error(self):
        result = run_bridge("def foo(")
        assert result["success"] is False
        assert "SyntaxError" in result["error"]

    def test_runtime_error(self):
        result = run_bridge("1 / 0")
        assert result["success"] is False
        assert "ZeroDivisionError" in result["error"]

    def test_name_error(self):
        result = run_bridge("undefined_var")
        assert result["success"] is False
        assert "NameError" in result["error"]


class TestBridgeContext:
    def test_context_access(self):
        result = run_bridge("context['name']", context={"name": "OpenFang"})
        assert result["success"] is True
        assert result["result"] == '"OpenFang"'

    def test_context_dict(self):
        result = run_bridge("len(context)", context={"a": 1, "b": 2})
        assert result["success"] is True
        assert result["result"] == "2"


class TestBridgeActions:
    def test_send_message_action(self):
        code = "send_message('hello from python')"
        result = run_bridge(code)
        assert result["success"] is True
        assert len(result["actions"]) == 1
        assert result["actions"][0]["type"] == "send_message"
        assert result["actions"][0]["content"] == "hello from python"

    def test_create_notification_action(self):
        code = "create_notification('Alert', body='Test', kind='warning')"
        result = run_bridge(code)
        assert result["success"] is True
        assert len(result["actions"]) == 1
        action = result["actions"][0]
        assert action["type"] == "create_notification"
        assert action["title"] == "Alert"
        assert action["kind"] == "warning"

    def test_multiple_actions(self):
        code = "send_message('msg1')\nsend_message('msg2')"
        result = run_bridge(code)
        assert result["success"] is True
        assert len(result["actions"]) == 2


class TestBridgeInvalidInput:
    def test_invalid_json_input(self):
        result = subprocess.run(
            [sys.executable, BRIDGE_PATH],
            input="not json",
            capture_output=True,
            text=True,
            timeout=10
        )
        data = json.loads(result.stdout)
        assert data["success"] is False
        assert "Invalid input" in data["error"]
