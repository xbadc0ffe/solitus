# Mockups (reference only)

These are the source files of the design canvas from the planning session, sixth pass.

| File | Screen | DESIGN.md |
|---|---|---|
| `Main.dc.html` | Track | 7.2 |
| `Detail.dc.html` | Task details | 7.3 |
| `EditTask.dc.html` | Add / Edit task (drawn full screen; build it as a sheet) | 7.4 |
| `Trends.dc.html` | Trends | 7.5 |
| `TrendSheet.dc.html` | Trend graph sheet | 7.6 |
| `canvas.json` | Canvas layout index | |

**They do not open in a browser on their own.** Each file depends on the canvas host's runtime (`support.js`), which is not included. Read them as text.

What they are good for:

- **Exact values.** Every size, radius, colour, gradient and shadow is written inline in the `style` attributes.
- **Layout.** The element order in each file is the screen's top-to-bottom order.
- **Sample logic.** The script block at the end of each file computes the heat steps, the running-average series, the seams and the motion values used in the mockup. It is illustration, not the specification: DESIGN.md section 6 defines the real rules.
- **Both looks.** Each script has an `effects` flag. With it on, the values describe the 3D glass style (DESIGN.md 9.4). With it off, they describe the flat style to build first (9.1).

What to ignore:

- All task names and numbers are invented sample data.
- The Inter font is a stand-in for the system font.
- The mouse-move handler stands in for device tilt.

If `design/screens/` exists, it holds image exports of the same screens.
