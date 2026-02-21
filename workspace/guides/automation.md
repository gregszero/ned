# Automation Guide — Triggers & Workflows

## Event Triggers

Use `create_trigger` to set up reactive automation. Triggers listen for events and fire a skill or prompt when a matching event occurs.

**Available events:**
- `task:completed:{title-slug}` / `task:failed:{title-slug}` — when a scheduled task finishes
- `heartbeat:escalated:{name}` / `heartbeat:error:{name}` — when a heartbeat escalates or errors
- `notification:created:{kind}` — when a notification is broadcast (kind: info/success/warning/error)
- `workflow:completed:{name-slug}` / `workflow:failed:{name-slug}` — when a workflow finishes

Use `*` as a wildcard in patterns (e.g., `task:completed:*` matches all completed tasks).

**Example — notify on any task failure:**
```json
{
  "name": "alert_on_failure",
  "event_pattern": "task:failed:*",
  "action_type": "prompt",
  "action_config": { "prompt": "A scheduled task just failed. Check what happened and notify the user." }
}
```

## Multi-Step Workflows

Use `create_workflow` to build pipelines that execute multiple steps in sequence, passing data between them.

**Step types:**
| Type | Purpose | Config keys |
|---|---|---|
| `skill` | Run a skill | `skill_name`, `parameters` |
| `prompt` | Send to AI agent | `prompt` (supports `{{context.step_name}}` interpolation) |
| `condition` | Branch logic | `expression`, optional `skip_to` |
| `wait` | Pause for duration | `duration` (e.g., "5 minutes", "1 hour") |
| `notify` | Send notification | `title`, `body`, `kind` |
| `approval` | Wait for human approval | `title`, `description`, `timeout` |

**Example — morning briefing workflow:**
```json
{
  "name": "morning_routine",
  "steps": [
    { "name": "weather", "type": "skill", "config": { "skill_name": "fetch_weather" } },
    { "name": "news", "type": "skill", "config": { "skill_name": "fetch_news" } },
    { "name": "briefing", "type": "prompt", "config": { "prompt": "Create morning briefing from: {{context}}" } },
    { "name": "done", "type": "notify", "config": { "title": "Morning briefing ready", "kind": "success" } }
  ]
}
```

Workflows can also auto-start on an event by setting `trigger_event` (e.g., `"heartbeat:escalated:monitoring"`).
