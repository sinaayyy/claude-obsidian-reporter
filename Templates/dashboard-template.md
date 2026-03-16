---
type: claude-reports-dashboard
---

# Reports Dashboard

## Recent Daily Reports

```dataview
TABLE WITHOUT ID
  file.link as "Report",
  project as "Project",
  date as "Date",
  commits as "Commits"
FROM "Reports"
WHERE type = "claude-daily-report"
SORT date DESC
LIMIT 14
```

## Weekly Summaries

```dataview
TABLE WITHOUT ID
  file.link as "Report",
  project as "Project",
  "W" + week + " · " + year as "Period",
  commits as "Commits"
FROM "Reports"
WHERE type = "claude-weekly-report"
SORT file.mtime DESC
LIMIT 8
```

## Monthly Summaries

```dataview
TABLE WITHOUT ID
  file.link as "Report",
  project as "Project",
  month as "Month",
  commits as "Commits"
FROM "Reports"
WHERE type = "claude-monthly-report"
SORT month DESC
```
