# TimeTracker Design System

## Direction
Warm, matte, earthy. Like watercolor on linen paper. Dense but calm — a watch face you glance at, not a dashboard you study. Terracotta as the single accent color.

## Appearance
Three modes: Light / Dark / System (follows macOS). Stored in `@AppStorage("appearance")`.

## Surfaces

| Token | Light | Dark |
|-------|-------|------|
| background | #f7f5f2 | #242220 |
| backgroundSecondary | #f2efec | #1e1c1a |
| border | rgba(0,0,0,0.06) | rgba(255,255,255,0.05) |
| borderSubtle | rgba(0,0,0,0.04) | rgba(255,255,255,0.04) |

## Typography

| Token | Light | Dark |
|-------|-------|------|
| primary | #1a1a1a | #f0ede8 |
| secondary | #3a3a3a | #c8c3bb |
| tertiary | #9a958e | #6b665f |
| quaternary | #b5b0a8 | #4a4540 |

## Category Colors

| Category | Light | Dark |
|----------|-------|------|
| Coding | #7b8db8 (dusty blue) | #6878a0 |
| Email | #c9956a (warm clay) | #b0845e |
| Browsing | #6da89a (sage) | #5e9487 |
| Communication | #5a9a6e (matte green) | #4e8760 |
| Design | #a07cba (dusty purple) | #8a6ca3 |
| Writing | #c47878 (matte rose) | #a86868 |
| Other | #9a958e (warm gray) | #6b665f |
| Accent (terracotta) | #c06040 | #c06040 (same both modes) |

Overflow palette: #c4a84e (ochre), #5e9487 (teal), #8a7560 (umber), #7aaa8a (mint)

## Depth Strategy
Borders only. No shadows except the dropdown itself (0 1px 3px rgba(0,0,0,0.04) light / 0 2px 8px rgba(0,0,0,0.3) dark).

## Spacing
Base unit: 8px. Padding: 14-16px for dropdown body. Gaps: 6-8px between rows. 2px between pulse bars/timeline segments.

## Border Radius
- Dropdown: 14px
- Cards/goal: 10px
- Timeline segments: 3px
- Category dots: 3px
- Buttons/badges: 3px

## Components
- **Hero timer:** 44px bold, monospacedDigit, -3px letter-spacing
- **Section labels:** 9px uppercase, 0.5px letter-spacing, quaternary color
- **Progress bars:** 4px height, quaternary track, category color fill
- **Timeline:** 18px height, 2px gaps between segments, 3px radius
- **Pulse bars:** 26px max height, 2px gaps, 2px radius
- **Focus ring:** 32x32, 2.5px stroke, terracotta accent
- **Tab underline:** 2px terracotta
