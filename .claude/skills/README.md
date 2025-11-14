# Claude Skills for Laptop Tools

This directory contains Claude Code Skills that automate workflows for the laptop-tools project.

## Available Skills

### collaboration-health-check
**Purpose:** Periodic collaboration quality reviews

Triggers health check interviews to assess collaboration quality and identify improvements.

**When to use:** Every ~30 sessions (configured in config.json) or when requesting "How is our collaboration?"

**What it does:**
- Asks 3-5 questions about collaboration quality
- Identifies friction points before they compound
- Documents findings in session memory
- Suggests improvements to framework docs

### phase-documenter
**Purpose:** Document completed work in session memory

Updates session memory in README.md after completing major work.

**When to use:** End of session after significant accomplishments

**What it does:**
- Summarizes work completed
- Updates "Recent Work" section
- Documents "Next Steps"
- Records patterns learned

## How Skills Work

Skills are auto-discovered by Claude Code based on user requests. You don't need to explicitly call them - they activate when relevant.

**Examples:**
- "How is our collaboration?" → Triggers collaboration-health-check
- "Document this session" → Triggers phase-documenter

## Adding Custom Skills

To add project-specific skills:

1. Create new directory in `.claude/skills/`
2. Add skill.md file with instructions
3. Update config.json to list custom skill
4. Test by requesting skill functionality

See [Gordo Framework Skills documentation](https://github.com/jkraybill/gordo-framework/.claude/skills/README.md) for more details.

---

**Copied from:** [Gordo Framework](https://github.com/jkraybill/gordo-framework)
**Last Updated:** 2025-11-14
