---
inclusion: always
---

# Milestone Snapshots

Keep a small archive of major project milestones in `milestones/` (for resume / portfolio).

- Record ONLY major milestones: a new design passes its full test suite, a subsystem first works end-to-end, first FPGA boot, timing/DRC/LVS signoff. Not routine edits or small fixes.
- One subfolder per milestone: `milestones/YYYY-MM-DD_short-kebab-name/`
- Each subfolder contains only:
  - `wave.vcd` — the waveform that shows the milestone
  - `README.md` — ONE English sentence, starting with the bold date and time, e.g.
    `**2026-10-24 15:03** — <what was achieved> (<test name>, commit <hash>).`
- Everything in English. Keep it minimal; do not add extra files.
- When a milestone is reached, propose creating the snapshot to the user.
