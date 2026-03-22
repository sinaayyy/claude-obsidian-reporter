---
type: claude-project-index
project: {{project}}
tags: {{tags}}
parent: "[[Dashboard]]"
first_commit: {{first_commit}}
total_commits: {{total_commits}}
active_years: {{active_years}}
contributors: {{contributors}}
health: {{health}}
health_details: "{{health_details}}"
project_status: active
priority: medium
risk_notes: ""
generated_at: {{generated_at}}
generator_version: "3.1.0"
---

# {{project}}

> [!summary] Overview
> {{resume_taches}}

> [!check] Key Milestones
> {{highlights}}

> [!info] Stats
> - **Active since:** {{first_commit}}
> - **Total commits:** {{total_commits}}
> - **Active years:** {{active_years}}
> - **Contributors:** {{contributors}}

## Management

**Status:** `INPUT[select(option(active), option(paused), option(archived)):project_status]`
**Priority:** `INPUT[select(option(high), option(medium), option(low)):priority]`
**Risk notes:** `INPUT[text:risk_notes]`

## Activity (lifetime)

```chart
type: line
labels: {{chart_lifetime_labels}}
series:
  - title: Commits/month
    data: {{chart_lifetime_data}}
tension: 0.3
fill: false
```

## Yearly Reports

{{yearly_links}}
