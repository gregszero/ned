# Python Support Guide

You can run Python code and Python skills alongside Ruby. Python runs in a virtualenv at `workspace/python/venv/` (auto-created on first use).

## Running Python code
```
run_code(language: "python", code: "import sys; result = sys.version")
```

Helpers available inside Python code:
- `send_message(content)` — send a message back to the user
- `create_notification(title, body, kind)` — create a notification
- `context` — dict with any context passed from the framework

For expressions, the return value is captured automatically. For statements, set a `result` variable.

## Installing packages
```
manage_python(action: "install", packages: ["requests", "pandas"])
manage_python(action: "list")
```

## Python skills
Python skills are `.py` files in the `skills/` directory with a module-level `call(**params)` function:

```python
# skills/analyze_data.py
import pandas as pd

def call(csv_path=None, **kwargs):
    df = pd.read_csv(csv_path)
    send_message(f"Found {len(df)} rows")
    return {"rows": len(df), "columns": list(df.columns)}
```

Python skills are auto-discovered and can be run with `run_skill` just like Ruby skills.
