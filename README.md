# Laptop Tools
**Assorted scripts and utilities to make JK's laptop better**

Personal collection of cleanup tools, cataloguing scripts, and system utilities.

---

## Current Status

**Last Updated:** 2025-11-14

Just getting started! Framework initialized, ready for first tools.

---

## Session Start Prompt

**Copy-paste this at the start of every session:**

```
Please complete these steps in order:

1. **Read framework files:**
   - COLLABORATION.md (WWGD signals and communication patterns)
   - Check for any new scripts or tools added

2. **Check repository status:**
   - Run: `git log --oneline -5` (recent commits)
   - Run: `git status` (current state)

3. **Review session memory below:**
   - What did we work on last?
   - Any pending tasks or open questions?

4. **Provide session start summary:**
   - Recent work: [summary]
   - Current focus: [what's next]
   - Ready to proceed

Then await instructions using WWGD signals.
```

---

## Session End Prompt

**Copy-paste this at the end of every session:**

```
Complete these steps before ending:

1. **Verify work quality:**
   - Test any new scripts manually
   - Check for secrets/credentials (none in git!)
   - Verify .gitignore patterns working

2. **Commit work:**
   - Commit with descriptive message
   - Push immediately: `git push`

3. **Update session memory below:**
   - What was accomplished this session?
   - What's next for future sessions?
   - Any patterns or learnings?

4. **Clean state check:**
   - No uncommitted changes: `git status`
   - No temp files or secrets exposed

5. **Session close:**
   Provide brief summary:
   - Work completed: [description]
   - Scripts added/modified: [list]
   - Next session: [what's next]

Then end with: "Catch ya on the flipside!"
```

---

## Session Memory

**Last Session:** 2025-11-15 (Session 2 - Post-Debloat Verification & First Scripts)

**Recent Work:**
- Verified debloat effectiveness post-restart (DiagTrack disabled, WSL functional)
- Created first utility scripts in /scripts directory:
  - `optimize-wsl-config.sh` - WSL2 performance configuration generator
  - `configure-defender-exclusions.ps1` - Defender exclusions for dev performance
  - `configure-defender-exclusions.sh` - WSL helper for Defender script
  - `scripts/README.md` - Documentation for all scripts
- All scripts tested-safe with backups and idempotent design

**Previous Session:** 2025-11-14 (Session 1 - Laptop Debloat Research & Execution)
- Framework initialized, Chris Titus Tech utility applied
- Balanced debloat (Desktop preset + telemetry disable)

**Next Steps:**
- Run the new optimization scripts (WSL config, Defender exclusions)
- Monitor performance improvements
- Consider: Registry tweaks for UI performance
- Consider: O&O ShutUp10++ for additional privacy hardening
- Add HDD cleanup/cataloguing tools when needed

**Patterns Learned:**
- WWGD+ trust level working excellently - high autonomy execution
- Script creation benefits from defensive coding (backups, checks, clear output)
- Dev laptop optimization: WSL performance and Defender exclusions are critical
- User prefers balanced, safe approach over aggressive optimization

---

## Project Overview

Personal laptop maintenance and utility scripts. Low-stakes, high-quality tools for:
- HDD cleanup and cataloguing
- System maintenance
- File organization
- Whatever else makes the laptop better

**Philosophy:** Keep it simple. Scripts should be readable, safe, and useful. Quality matters even for personal tools.

---

## Tech Stack

**TBD per tool** - will choose best tool for each job:
- Bash for simple system tasks
- Python for data processing
- Go for performance-critical tools
- Whatever makes sense

---

## Development Standards

**Quality (Even for Personal Tools):**
- Test manually before committing
- Handle errors gracefully (don't break the laptop!)
- Document what each script does
- Keep secrets in .env (never commit)

**Safety First:**
- Destructive operations require confirmation prompts
- Backup before cleanup operations
- Never delete without user confirmation
- Log actions for audit trail

**Code Style:**
- Readable > clever
- Comments explain "why" not "what"
- Keep it simple

---

## Communication Patterns

See [COLLABORATION.md](COLLABORATION.md) for full WWGD signal documentation.

**Quick Reference:**
- **WWGD?** - Answer the question, don't execute
- **WWGD** - Green light, proceed
- **WWGD+** - Green light + trust upgrade
- **WWGD++** - Max autonomy for current task
- **! and !!** - Emphasis modifiers

---

## Collaboration Identity

**AI Name:** Gordo
**Human Name:** JK

This is JK's laptop-tools project using Gordo Framework patterns adapted from home-server.

---

## Directory Structure

```
laptop-tools/
├── README.md (this file)
├── COLLABORATION.md (communication patterns)
├── .gitignore (secrets, temp files)
├── .env.example (template for secrets)
├── config.json (project metadata)
├── scripts/ (utility scripts - TBD)
└── docs/ (documentation - TBD)
```

---

## Getting Started

1. Clone this repo
2. Copy `.env.example` to `.env` if needed
3. Start a session with Session Start Prompt above
4. Build tools as needed

---

**Part of [Gordo Framework](https://github.com/jkraybill/gordo-framework)** - Session continuity for AI collaboration.
