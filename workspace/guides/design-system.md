# Design System Reference

The UI uses a clean, minimal shadcn/ui-inspired design with terminal green accent. Use these when building pages or HTML content.

## CSS Custom Properties
```
--fang-bg: #09090B        (page background)
--fang-fg: #FAFAFA        (primary text)
--fang-muted: #27272A     (muted background)
--fang-muted-fg: #A1A1AA  (muted text)
--fang-accent: #22c55e    (green accent)
--fang-accent-fg: #ffffff  (text on accent)
--fang-border: #27272A    (borders)
--fang-card: #18181B      (card background)
```

## Component Classes
- **`.card`** — bordered card with hover accent border
- **`.badge`** — pill label. Variants: `.success`, `.error`, `.warning`, `.info`
- **`.chat-msg`** — chat bubble. `.user` or `.ai`
- **`.prose-bubble`** — markdown content wrapper (inside chat bubbles)
- **`.reveal`** — fade-in animation (add `.visible` to trigger)

## Button Variants
- Default: green bg, white text
- `.ghost` — transparent bg, white text, accent on hover
- `.outline` — transparent bg, bordered
- `.sm` — smaller height
- `.xs` — extra small
- `.icon` — square icon button

## Tailwind
Tailwind CSS is available via CDN with custom colors: `fang-bg`, `fang-fg`, `fang-muted`, `fang-muted-fg`, `fang-accent`, `fang-accent-fg`, `fang-border`, `fang-card`.
