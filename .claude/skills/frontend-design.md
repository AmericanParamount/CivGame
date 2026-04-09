---
name: frontend-design
description: Design philosophy for distinctive UI — reject generic AI aesthetics, commit to intentional direction
---

# Frontend Design Skill (adapted from anthropics/skills)

## Core Question
"What makes this UNFORGETTABLE?"

Before building any UI, establish:
- **Purpose**: What problem does this solve? Who sees it?
- **Tone**: Specific aesthetic direction (for this project: bronze-age antiquity, dark teal + gold)
- **Constraints**: Roblox ScreenGui, UIListLayout/UIGridLayout, TweenService, 9-slice panels
- **Differentiation**: The memorable element (for this project: archaeological pottery aesthetic, gold meander borders)

## Design Principles

### Typography
- Prioritize distinctive fonts over generic choices
- In Roblox: GothamBold for headers, Gotham for body is acceptable — but consider SourceSansPro for a softer feel
- Pair font weights intentionally: bold titles, regular body, light hints

### Color & Theme
- Build cohesive palettes with CSS variables (or Lua palette tables)
- Use dominant color + sharp accent, not timid even distribution
- HSB color variation: darker = lower brightness + higher saturation, lighter = inverse
- Never use pure gray — tint shadows toward the dominant hue

### Motion
- Orchestrate page-load reveals (fade + scale on open)
- Hover states are feedback, not decoration
- Use Back easing for bouncy pop, Quad for smooth settle
- Match easing to emotional intent: Back = playful, Quad = professional, Elastic = attention

### Composition
- Embrace asymmetry where it serves hierarchy
- Generous negative space > cramming elements
- Progressive disclosure: show detail only when needed (detail strip pattern)
- Group related items spatially (Law of Proximity)

### Details
- Layer: background panel + border stroke + inner highlight + content
- Gold dividers to separate sections (not plain lines)
- UICorner on everything (rounded = approachable)
- UIStroke for borders, not BackgroundColor tricks

## Critical Restrictions

AVOID:
- Generic gray-on-white interfaces
- Purple gradients, neon accents (breaks bronze-age theme)
- Predictable symmetric layouts with no hierarchy
- Cookie-cutter patterns lacking project-specific character
- Mixing warm parchment and cool teal palettes (pick one, commit)

## Project-Specific Palette (Ecosystem / CivGame)

```
Panel:      rgb(15, 30, 30)      -- deep teal, primary background
PanelTop:   rgb(18, 36, 36)      -- slightly lighter variant
SlotTop:    rgb(22, 40, 40)      -- interactive element background
SlotHover:  rgb(28, 48, 48)      -- hover state (HSB: brightness up, sat down)
Gold:       rgb(184, 148, 62)    -- primary accent
GoldDim:    rgb(107, 90, 42)     -- borders, dividers
GoldTxt:    rgb(212, 184, 106)   -- readable text on dark bg
GoldWarm:   rgb(212, 170, 74)    -- selected/active states
Label:      rgb(138, 154, 138)   -- muted secondary text
Key:        rgb(90, 106, 90)     -- disabled/hint text
Danger:     rgb(160, 64, 40)     -- errors, locked states
Green:      rgb(70, 150, 65)     -- success, available
```
