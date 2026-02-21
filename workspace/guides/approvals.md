# Approvals Guide

Human-in-the-loop approval gates — standalone or as workflow steps. The approver sees a notification and can approve/reject via the UI or API.

## Standalone approvals
Use `create_approval` to pause and wait for human input:
```json
{
  "title": "Deploy to production",
  "description": "Version 2.3.1 is ready. 47 tests passing.",
  "timeout": "2 hours"
}
```
A notification is sent immediately. If `timeout` is set, the approval auto-expires after the duration.

## Workflow approval steps
Add an `approval` step to a workflow:
```json
{
  "name": "deploy_pipeline",
  "steps": [
    {"name": "tests", "type": "skill", "config": {"skill_name": "run_tests"}},
    {"name": "approve", "type": "approval", "config": {"title": "Deploy to production?", "timeout": "1 hour"}},
    {"name": "deploy", "type": "skill", "config": {"skill_name": "deploy"}}
  ]
}
```
The workflow pauses at the approval step. On approve, it continues. On reject or expire, the workflow fails.

## Resolving approvals
Use `resolve_approval` with `decision: "approve"` or `decision: "reject"` and optional `notes`.

## Events
- `approval:approved:{title-slug}` — fired when approved
- `approval:rejected:{title-slug}` — fired when rejected
- `approval:expired:{title-slug}` — fired when expired
