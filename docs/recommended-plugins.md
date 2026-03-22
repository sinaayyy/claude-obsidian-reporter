# Recommended Obsidian Plugins

This tool uses the **Obsidian CLI plugin** to write files and **Dataview** for live queries. The following community plugins are recommended to unlock the full enterprise dashboard experience.

Install all community plugins via: Obsidian Settings → Community plugins → Browse.

---

## Required

### Obsidian CLI
**Why:** All vault writes go through this plugin. Without it, the skill cannot function.
**Install:** [Obsidian Community Plugins — "Obsidian CLI"](https://obsidian.md/plugins?id=obsidian-cli)
**Config:** Enable the plugin. No additional settings needed.

### Dataview
**Why:** Powers the live tables in the Dashboard (recent daily, weekly, monthly, yearly reports).
**Install:** [Obsidian Community Plugins — "Dataview"](https://obsidian.md/plugins?id=dataview)
**Config:** Settings → Dataview → Enable JavaScript queries: `on`.

---

## Strongly Recommended

### Homepage
**Why:** Opens the Dashboard automatically every time Obsidian launches. A manager opens Obsidian = they see the dashboard.
**Install:** [Obsidian Community Plugins — "Homepage"](https://obsidian.md/plugins?id=homepage)
**Config:**
- Settings → Homepage → Homepage: `Reports/Dashboard`
- Open on startup: `on`
- Open in new tab: `off`

---

### Breadcrumbs
**Why:** Reads the `parent` frontmatter field present on every report and renders a clickable breadcrumb trail at the top of each note: `Dashboard > ProjectAlpha > Y-2026 > M-03 > W-1 > D-19`. Also shows a "children" panel listing all notes that link to the current one — turning monthly reports into automatic portals to their weekly children.
**Install:** [Obsidian Community Plugins — "Breadcrumbs"](https://obsidian.md/plugins?id=breadcrumbs)
**Config:**
- Settings → Breadcrumbs → Hierarchy fields → Add field: `parent` (direction: `up`)
- Enable: Show breadcrumbs in reading view: `on`

---

### Charts
**Why:** Renders the commit velocity charts, project distribution pie, and activity bar charts embedded in the Dashboard and monthly reports. This is the single most impactful visual upgrade.
**Install:** [Obsidian Community Plugins — "Obsidian Charts"](https://obsidian.md/plugins?id=obsidian-charts)
**Config:** No configuration needed. Charts render automatically from ` ```chart ` code blocks.

Example of what you will see in the Dashboard:
- Bar chart: commits per day over the last 30 days, stacked by project
- Line chart: weekly velocity trend over 8 weeks
- Pie chart: commit distribution across projects

---

### Tracker
**Why:** Renders inline sparkline graphs from frontmatter numerical fields (`commits`, `files_changed`, `insertions`). Provides per-project activity trends directly inside the Dashboard without writing any extra data.
**Install:** [Obsidian Community Plugins — "Obsidian Tracker"](https://obsidian.md/plugins?id=obsidian-tracker)
**Config:** No configuration needed. Tracker reads frontmatter automatically from ` ```tracker ` blocks.

---

### Calendar
**Why:** Adds a calendar widget to the sidebar. Each day that has reports shows a dot. Clicking a day navigates to the daily reports for that date. Gives instant temporal navigation — "what happened on March 14th?" answered in one click.
**Install:** [Obsidian Community Plugins — "Calendar"](https://obsidian.md/plugins?id=calendar)
**Config:**
- Settings → Calendar → Start week on: Monday (or your preference)
- The calendar integrates with Periodic Notes (see below) to open daily reports directly.

---

### Periodic Notes
**Why:** Extends Calendar with weekly, monthly, and yearly note navigation. Adds prev/next period buttons so managers can navigate between W-11 and W-12 without touching the file tree.
**Install:** [Obsidian Community Plugins — "Periodic Notes"](https://obsidian.md/plugins?id=periodic-notes)
**Config:** Settings → Periodic Notes:
- Daily notes: Folder = `Reports/Current`, Format = leave default
- Weekly notes: Folder = `Reports`, Format = leave default
- Monthly notes: Folder = `Reports`, Format = leave default

---

### Meta Bind
**Why:** Renders interactive dropdowns and text fields directly inside the project index pages. Managers can set `project_status` (active/paused/archived), `priority` (high/medium/low), and `risk_notes` without editing raw frontmatter. These values are stored in frontmatter and queryable by Dataview.
**Install:** [Obsidian Community Plugins — "Meta Bind"](https://obsidian.md/plugins?id=obsidian-meta-bind)
**Config:** No configuration needed. The `INPUT[...]` widgets in project index pages activate automatically.

**How to use:** Open any project index (`Reports/PROJECT/PROJECT.md`) in reading view. The Status, Priority, and Risk notes fields are interactive.

---

## Plugins NOT Recommended

| Plugin | Reason |
|---|---|
| **Templater** | Redundant — Claude fills all templates directly. Adding Templater creates a parallel templating layer with no benefit. |
| **Kanban** | Commits are not tasks. Auto-generated Kanban boards from commit messages would be misleading. |
| **Excalidraw** | Too heavy for auto-generated content. Manual architecture diagrams are better created by humans. |
| **Buttons / Commander** | The skill is invoked from the Claude Code CLI, not from inside Obsidian. Buttons would create a false expectation. |
| **DB Folder** | Redundant with Dataview. More complexity for no additional benefit. |
| **Templater** | Already handled by the skill itself. |

---

## Plugin Install Order

For the smoothest setup:

1. Obsidian CLI (required first)
2. Dataview (required)
3. Homepage
4. Charts
5. Breadcrumbs
6. Calendar
7. Periodic Notes
8. Tracker
9. Meta Bind

Then run `/report-orchestrator` to generate your first reports and see everything in action.
