"""
OpenFang Python Skill Runner — executes a Python skill file.

Usage: python skill_runner.py <skill_file.py>
Reads JSON from stdin: { "params": {...}, "context": {...} }
Writes JSON to stdout: { "success": true, "result": "...", "output": "...", "actions": [...] }

Python skill convention: module-level `call(**params)` function.
"""

import sys
import json
import io
import traceback
import importlib.util

# Collected actions
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
    if len(sys.argv) < 2:
        json.dump({"success": False, "error": "No skill file specified"}, sys.stdout)
        return

    skill_path = sys.argv[1]

    try:
        payload = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, Exception) as e:
        json.dump({"success": False, "error": f"Invalid input: {e}"}, sys.stdout)
        return

    params = payload.get("params", {})
    context = payload.get("context", {})

    # Load the skill module
    try:
        spec = importlib.util.spec_from_file_location("skill", skill_path)
        if spec is None:
            json.dump({"success": False, "error": f"Cannot load skill: {skill_path}"}, sys.stdout)
            return

        module = importlib.util.module_from_spec(spec)

        # Inject helpers into the module before executing it
        module.send_message = send_message
        module.create_notification = create_notification
        module.context = context

        spec.loader.exec_module(module)
    except Exception:
        json.dump({
            "success": False,
            "error": f"Failed to load skill: {traceback.format_exc()}",
            "actions": _actions,
        }, sys.stdout)
        return

    # Check for call function
    if not hasattr(module, "call") or not callable(module.call):
        json.dump({
            "success": False,
            "error": f"Skill {skill_path} has no callable 'call' function",
        }, sys.stdout)
        return

    # Execute the skill
    captured = io.StringIO()
    old_stdout = sys.stdout
    sys.stdout = captured

    try:
        result = module.call(**params)
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
