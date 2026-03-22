---
type: claude-monthly-report
project: {{project}}
month: {{month}}
year: {{year}}
commits: {{nb_commits}}
files_changed: {{files_changed}}
insertions: {{insertions}}
deletions: {{deletions}}
contributors: {{contributors}}
branches: {{branches}}
status: {{status}}
tags: {{tags}}
parent: "[[{{parent_yearly}}]]"
generated_at: {{generated_at}}
generator_version: "3.1.0"
---

## Monthly Summary – {{project}} – {{month}}

> [!summary] Summary
> {{resume_taches}}

> [!check] Highlights
> {{highlights}}

## Daily activity this month

```chart
type: bar
labels: {{chart_monthly_labels}}
series:
  - title: Commits
    data: {{chart_monthly_data}}
```

### Weekly Reports

{{weekly_links}}

### Commits This Month

{{liste_commits}}
