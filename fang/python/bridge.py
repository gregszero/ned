"""
OpenFang Python Bridge — executes ad-hoc Python code.

Reads JSON from stdin: { "code": "...", "context": {...} }
Writes JSON to stdout: { "success": true, "result": "...", "output": "...", "actions": [...] }
"""

import sys
import json
import io
import traceback

# Collected actions (send_message, create_notification, etc.)
_actions = []


def send_message(content, conversation_id=None):
    """Send a message back to the user."""
    action = {"type": "send_message", "content": str(content)}
    if conversation_id:
        action["conversation_id"] = str(conversation_id)
    _actions.append(action)


def create_notification(title, body="", kind="info"):
    """Create a notification."""
    _actions.append({
        "type": "create_notification",
        "title": str(title),
        "body": str(body),
        "kind": str(kind),
    })


def main():
    try:
        payload = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, Exception) as e:
        json.dump({"success": False, "error": f"Invalid input: {e}"}, sys.stdout)
        return

    code = payload.get("code", "")
    context = payload.get("context", {})

    # Capture stdout from the executed code
    captured = io.StringIO()
    old_stdout = sys.stdout
    sys.stdout = captured

    # Build execution namespace with helpers
    namespace = {
        "__builtins__": __builtins__,
        "send_message": send_message,
        "create_notification": create_notification,
        "context": context,
    }

    result = None
    try:
        # Try exec first (statements), fall back to eval (expressions)
        try:
            compiled = compile(code, "<openfang>", "eval")
            result = eval(compiled, namespace)
        except SyntaxError:
            exec(compile(code, "<openfang>", "exec"), namespace)
            result = namespace.get("result", None)
    except Exception:
        sys.stdout = old_stdout
        json.dump({
            "success": False,
            "error": traceback.format_exc(),
            "output": captured.getvalue(),
            "actions": _actions,
        }, sys.stdout)
        return

    sys.stdout = old_stdout
    output = captured.getvalue()

    # Format result
    if result is not None:
        try:
            result_str = json.dumps(result)
        except (TypeError, ValueError):
            result_str = repr(result)
    else:
        result_str = output.strip() if output.strip() else None

    json.dump({
        "success": True,
        "result": result_str,
        "output": output,
        "actions": _actions,
    }, sys.stdout)


if __name__ == "__main__":
    main()
