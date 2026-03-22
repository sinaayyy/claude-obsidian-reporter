---
type: claude-reports-dashboard
updated: {{date}}
---

# Working

> [!summary] Overview
> {{workspace_summary}}

> [!check] This week across projects
> {{workspace_highlights}}

## Project Health

{{health_overview}}

## Activity — Last 30 days

```chart
type: bar
labels: {{chart_labels_30d}}
series:
{{chart_series_30d}}
stacked: true
```

## Velocity — Last 8 weeks

```chart
type: line
labels: {{chart_labels_8w}}
series:
  - title: Total commits
    data: {{chart_data_8w}}
tension: 0.3
fill: false
```

## Commits by project

```chart
type: pie
labels: {{chart_pie_labels}}
series:
  - title: Commits (30 days)
    data: {{chart_pie_data}}
```

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

## Contributor Activity

```dataview
TABLE WITHOUT ID
  project as "Project",
  contributors as "Contributors",
  commits as "Commits",
  files_changed as "Files",
  insertions as "Lines +"
FROM ""
WHERE type = "claude-weekly-report"
SORT date DESC
LIMIT 10
```
