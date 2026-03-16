---
type: claude-daily-report
project: {{project}}
date: {{date}}
week: {{week}}
month: {{month}}
commits: {{nb_commits}}
status: {{status}}
tags: [report/daily, "project/{{project}}"]
parent: "[[{{parent_weekly}}]]"
---

## Daily Progress – {{project}} – {{date}}

> [!summary] Summary
> {{resume_taches}}

## Commits

{{liste_commits}}
