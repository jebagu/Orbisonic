# Orbisonic App Family Design Language

This app family should feel like a technical control surface: compact, precise, visual, and work-focused. The style is dark, glassy, and instrument-like, with restrained neon accents used to show active states, warnings, and important values. It should feel like a serious parametric tool, not a marketing site and not a generic SaaS dashboard.

The overall layout should usually follow this structure:

- A top bar used either for live metrics or primary navigation tabs.
- A left control panel for parameters, filters, configuration, and mode selection.
- A right workspace panel for the main visual, data view, document, editor, canvas, table, or report.
- Floating controls may appear over the workspace only when they directly manipulate that workspace.

The layout should preserve a strong "lab bench" feeling: controls on the left, work surface on the right, status across the top.

## Visual Style

Use a dark technical palette with cold neutral text and one strong accent color. Panels should feel slightly translucent, with soft borders and subtle blur. Avoid flat black, pure gray dashboards, and loud multicolor UI.

Recommended direction:

```css
--bg: #071014;
--panel: rgba(13, 24, 29, 0.88);
--panel-floating: rgba(5, 12, 15, 0.68);
--line: rgba(217, 251, 255, 0.14);
--text: #effcff;
--text-soft: #9fb9bd;
--accent: #5eead4;
--blue: #60a5fa;
--warning: #facc15;
--danger: #fb7185;
```

Use the accent color sparingly. It should mark active controls, important totals, selected objects, and primary statuses. Secondary colors should support meaning, not decorate.

Panels should generally use:

```css
border: 1px solid var(--line);
border-radius: 8px;
background: var(--panel);
backdrop-filter: blur(18px);
box-shadow: 0 18px 55px rgba(0, 0, 0, 0.36);
```

Floating workspace controls can be slightly more transparent, but should still have clear boundaries.

## Typography

Use compact, high-legibility interface typography. The type should support scanning and repeated use.

Recommended approach:

- Primary font: `Inter`, system sans fallback.
- Monospace only for logs, code, coordinates, IDs, or debug output.
- Labels: small, uppercase, bold, muted color.
- Section titles: compact, not oversized.
- Metric values: slightly larger and brighter than labels.
- Avoid hero-sized text inside tool panels.

Suggested scale:

```css
app title: 18px;
section title: 16px;
metric value: 14px;
body/control text: 12px;
labels: 11px uppercase;
debug/technical text: 11px monospace;
```

Keep letter spacing at `0`. Do not use negative letter spacing. Do not scale font size with viewport width.

## Buttons And Controls

Buttons should be compact, rectangular, and consistent. They should feel like instrument controls, not large call-to-action blocks.

Default button style:

```css
min-height: 34px;
border: 1px solid var(--line);
border-radius: 7px;
background: rgba(255, 255, 255, 0.045);
color: var(--text);
padding: 7px 9px;
```

Active state:

```css
border-color: rgba(94, 234, 212, 0.55);
background: rgba(94, 234, 212, 0.14);
```

Use segmented controls for mutually exclusive modes. Use checkboxes/toggles for binary choices. Use sliders for continuous values. Use selects for long option sets. Use icon buttons where the action is universal and recognizable.

Controls should be dense but not cramped. The user should be able to scan a panel quickly and understand what is editable.

## Layout Rules

The top bar should have a fixed rhythm. It can be either:

- metric chips showing current state and important values
- tabs for high-level workspace navigation

Avoid mixing too many unrelated interaction types in the top bar. If it is a metric bar, make the metrics clickable only when they navigate to relevant detail. If it is a tab bar, keep the tabs visually uniform.

The left panel should be the configuration area. It should contain grouped controls, short section headings, and contextual options. It should not become a report area or a document viewer.

The right panel should be the work area. It should hold the main canvas, table, document, preview, chart, or editor. It can have floating controls, but those controls should be narrow, aligned, and predictable.

## Things To Watch Out For

1. Fixed boundaries are important. Boxes, metric chips, buttons, tabs, and toolbar items should not resize just because text changes. Use fixed grid tracks, min/max widths, ellipsis, stable heights, and predictable wrapping rules.

2. Between tabs, horizontal and vertical alignment should remain stable. Section titles, control grids, workspace edges, and major content anchors should line up from tab to tab. Switching tabs should not feel like the app is reassembling itself.

3. Avoid layout jump. Active states, loading text, warnings, and selected states should not change the size of their containers. Reserve space for status text when needed.

4. Keep border radii consistent. Use 7-8px for most interface surfaces. Avoid mixing pill buttons, heavy rounding, and sharp boxes unless there is a clear hierarchy.

5. Do not overuse the accent color. If everything is cyan, nothing is active. Most UI should be quiet; accent belongs to active, selected, primary, or important states.

6. Keep panels aligned to a shared grid. The left panel, top bar, workspace panel, and floating toolbars should share margins and gaps, typically 8-12px.

7. Avoid nested cards. A panel can contain controls, rows, summaries, or repeated items, but do not stack decorative cards inside decorative cards.

8. Text must fit. Long labels should truncate, wrap intentionally, or be shortened. Never allow text to overflow buttons, metric chips, tabs, or control rows.

9. Workspace controls should not obscure the work. Floating toolbars should be narrow, single-column when needed, and placed consistently.

10. Responsive behavior should preserve the same mental model. On smaller screens, stack the panels, but keep the sequence: status/navigation first, controls, then workspace.

11. Use warnings and errors sparingly but clearly. Amber for warnings, red/pink for errors, cyan/white for normal status. Do not invent new warning colors per app.

12. Preserve interaction semantics across the app family. A segmented button should always mean mode selection. A metric chip should always show state. A toolbar should always affect the current workspace.

## Coherence Principle

Every app in the family should feel like a different instrument from the same lab: same dark glass materials, same compact control rhythm, same accent logic, same panel geometry, same typography scale, and the same top-left-to-right workbench structure. The content can change, but the operating grammar should stay familiar.
