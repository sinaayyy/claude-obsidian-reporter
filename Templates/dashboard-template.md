---
type: claude-reports-dashboard
updated: {{date}}
---

# Working

> [!summary] Overview
> {{workspace_summary}}

> [!check] This week across projects
> {{workspace_highlights}}

## Projects

{{projects_overview}}

## Recent Daily Reports

```dataview
TABLE WITHOUT ID
  file.link as "Report",
  project as "Project",
  date as "Date",
  commits as "Commits"
FROM ""
WHERE type = "claude-daily-report"
SORT date DESC
LIMIT 14
```

## Weekly Summaries

```dataview
TABLE WITHOUT ID
  file.link as "Report",
  project as "Project",
  "W" + string(week) + " – " + month as "Period",
  commits as "Commits"
FROM ""
WHERE type = "claude-weekly-report"
SORT year DESC, week DESC
LIMIT 8
```

## Monthly Summaries

```dataview
TABLE WITHOUT ID
  file.link as "Report",
  project as "Project",
  month as "Month",
  commits as "Commits"
FROM ""
WHERE type = "claude-monthly-report"
SORT month DESC
```

## Yearly Summaries

```dataview
TABLE WITHOUT ID
  file.link as "Report",
  project as "Project",
  year as "Year",
  commits as "Commits"
FROM ""
WHERE type = "claude-yearly-report"
SORT year DESC
```
