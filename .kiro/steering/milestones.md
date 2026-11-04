---
inclusion: always
---

# Milestone Snapshots

Keep a small archive of major project milestones in `milestones/` (for resume / portfolio).

- Record ONLY major milestones: a new design passes its full test suite, a subsystem first works end-to-end, first FPGA boot, timing/DRC/LVS signoff. Not routine edits or small fixes.
- One subfolder per milestone: `milestones/YYYY-MM-DD_short-kebab-name/`
- Each subfolder contains only:
  - `wave.vcd` — the waveform that shows the milestone (for an in-progress milestone: from the latest completed stage)
  - `README.md` — starts with ONE English sentence with the bold date and time, e.g.
    `**2026-10-24 15:03** — <what was achieved> (<test name>, commit <hash>).`
    A small English Mermaid diagram (FSM or system architecture) may follow the sentence.
- Everything in English. Keep it minimal; do not add extra files.
- When a milestone is reached, propose creating the snapshot to the user.

## Multi-stage milestones (tracked while in progress)

A milestone that takes several steps is created when work starts and updated as it goes:

- First line: `**Status: 🚧 IN PROGRESS — Stage N of M done**`, changed to `**Status: ✅ DONE**` when finished.
- Then the one-sentence goal (date + what it achieves), then an English Mermaid system-architecture diagram of the target design.
- A stage table: `| Stage | Goal | Status |` with ✅ / ⏳.
- A `## Movements` section: one entry per meaningful step (stage finished, key fix, test result, commit hash). Append an entry every time a stage completes or a notable step lands. Each entry is:
  - a `### YYYY-MM-DD HH:MM — <step name>` heading,
  - a short English paragraph (what changed, test result, commit hash),
  - a small English Mermaid diagram showing the design at that step (always include one).
- Replace `wave.vcd` with the newest waveform whenever a stage completes.
