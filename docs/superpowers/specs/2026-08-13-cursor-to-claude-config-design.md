# Migrating the Cursor AI config to Claude Code

**Date:** 2026-08-13
**Status:** approved, not yet implemented

## Problem

The repo's AI-assistant configuration was authored for Cursor and is almost
entirely invisible to Claude Code.

| File | Origin | Cursor behavior | Claude Code behavior |
| --- | --- | --- | --- |
| `AGENTS.md` (65 lines) | ours (`d70585bc74`) | always in context | **not loaded** |
| `.cursor/rules/telegram-interop.mdc` | ours (`d70585bc74`) | auto-attached on `submodules/**/*.swift` | not loaded |
| `.cursor/rules/nicegram-modules.mdc` | ours (`d70585bc74`) | auto-attached on `Nicegram/**` | not loaded |
| `.cursor/rules/swift-conventions.mdc` | ours (`d70585bc74`) | auto-attached on our Swift | not loaded |
| `.cursorignore` | **upstream** (`merge with source 11.8.1`) | indexing filter | ignored |
| `CLAUDE.md` (177 lines) | **upstream** (rewritten by `tg-merge` 11.11 / 12.7 / 12.8) | — | loaded every session |

The consequence is not cosmetic. `AGENTS.md` holds the fork's prime directive —
minimize upstream-merge conflicts, the three-step change ladder, the
host↔assistant split — and grepping upstream's `CLAUDE.md` for `marker`,
`AGENTS.md`, `TelegramBridge` or `nicegram-assistant` returns zero hits. Claude
Code currently works in this repo without knowing the single most important rule
governing it, and without the marker syntax that makes our edits survive a merge.

## Constraints

1. **Upstream files are near-immutable.** `CLAUDE.md`, `.gitignore` and
   `.cursorignore` all arrive via `tg-merge` commits. Every line we change there
   is a conflict at the next merge. Additions are cheaper than modifications;
   deletions of upstream files are the most expensive (delete/modify conflicts).
2. **Everything Nicegram-authored is free to restructure.**
3. This is a one-way migration: Cursor is being dropped, so cross-tool
   compatibility is not a requirement.
4. The sibling repo `nicegram-assistant-ios` already migrated. Where the two can
   agree, they should.

## Sibling-repo precedent

`nicegram-assistant-ios` uses the layout Anthropic documents:

- `CLAUDE.md` — 5 lines: `@AGENTS.md` plus a short `## Claude Code` section.
- `AGENTS.md` — the always-on doc, closing with a list of the rule files.
- `.claude/rules/*.md` — seven topic files, tracked in git, each with YAML
  frontmatter `paths:` globs; one file with no `paths:` loads every session.

Both mechanisms are documented Claude Code features: `.claude/rules/` with
`paths:` frontmatter is the direct equivalent of Cursor's `globs:`, and importing
an existing agents file via `@` is the recommended way to avoid duplicating it.

We adopt the same two mechanisms. The wiring differs in one place only, because
here `CLAUDE.md` belongs to upstream rather than to us.

## Design

### 1. Rename the fork's rules file

`AGENTS.md` → `NICEGRAM-AGENTS.md` (`git mv`).

Nothing in the repo reads it by name — `.pr_agent.toml` carries its own inlined
copy of the rules rather than referencing the file — so the rename is free. It
buys two things: the filename states that these are the fork's rules rather than
Telegram's, and it removes the risk of a head-on collision if upstream ever adds
a root `AGENTS.md`, which is plausible given they already ship `CLAUDE.md` and
`.cursorignore`.

Cost: other agent tools look for `AGENTS.md` specifically and will no longer find
it. Accepted under constraint 3.

### 2. Two added lines in upstream's `CLAUDE.md`

Inserted at line 1, above the `# CLAUDE.md` header:

```markdown
<!-- Nicegram AI rules -->
@NICEGRAM-AGENTS.md
```

- **Line 1, not EOF.** The end of the file is where upstream appends new sections
  (`tgcalls Testbench` is the most recent), so an insert there collides often. The
  header above line 1 has survived three merges unchanged.
- **The marker is required** by the change ladder — no unmarked edits in Telegram
  files. Claude Code strips block-level HTML comments before injecting the file,
  so the marker costs nothing in context.
- Trade-off accepted: content later in context carries slightly more weight, so
  placing our import first means upstream's 177 lines are read after it. The
  marker discipline is restated in `telegram-interop.md`, which attaches on
  `submodules/**/*.swift` and therefore lands much later in context anyway.

No content moves out of upstream's `CLAUDE.md`. Its build, watch-app, view-frame,
InstantPage, Postbox-refactor and tgcalls sections stay exactly where they are —
splitting them into rules would conflict on every merge for no benefit.

### 3. Port the three rules to `.claude/rules/`

Bodies move verbatim. Frontmatter converts: `globs:` (comma-separated) becomes
`paths:` (YAML list); `description:` and `alwaysApply:` are dropped, having no
Claude Code equivalent.

| New file | `paths:` |
| --- | --- |
| `.claude/rules/telegram-interop.md` | `submodules/**/*.swift` |
| `.claude/rules/nicegram-modules.md` | `Nicegram/**` |
| `.claude/rules/swift-conventions.md` | `Nicegram/**/*.swift`, `submodules/**/Nicegram/**/*.swift` |

Example of the converted frontmatter:

```markdown
---
paths:
  - "Nicegram/**/*.swift"
  - "submodules/**/Nicegram/**/*.swift"
---
```

Filenames match the sibling repo where the topics overlap (`swift-conventions.md`).

### 4. Repoint the "Detailed conventions" section

In `NICEGRAM-AGENTS.md`, the closing section (currently lines 60–65) changes from
`.cursor/rules/` `.mdc` files to `.claude/rules/` `.md` files. The in-body
references to "the `telegram-interop` rule" and "the `nicegram-modules` rule"
elsewhere in the file stay valid as written.

The section also gains one sentence recording that upstream's `CLAUDE.md` is
Telegram's file and remains the authority on the build system, the embedded watch
app, the Postbox→TelegramEngine refactor and the tgcalls testbench.

### 5. Un-ignore the rules directory

Upstream's `.gitignore:92` is `/.claude/`, which would keep the rules untracked
and unshared. A bare `!/.claude/rules/` does **not** work: git will not re-include
a path whose parent directory is excluded, because it never descends into it. The
working idiom re-includes the parent, then re-excludes its other contents:

```gitignore
# Nicegram: track shared Claude Code rules
!/.claude/
/.claude/*
!/.claude/rules/
```

Appended at EOF. These are additions only — upstream's `/.claude/` line is left
intact, so local settings, history and lock files stay ignored, as does
`**/.claude/settings.local.json` on line 93. Verified in a throwaway repo with
both `.gitignore` variants: before the block `git status -uall` shows nothing
under `.claude/`; after it, `.claude/rules/telegram-interop.md` is untracked-and-
addable while `.claude/settings.local.json` and `.claude/history.jsonl` remain
ignored. Line 72
(`!Telegram/Telegram-iOS/Resources/Nicegram/**/*.mp4`) is precedent for a Nicegram
negation in this file.

### 6. Clean up

- `git rm -r .cursor/rules/` — ours, now superseded.
- Remove the leftover untracked `.cursor/` directory locally (`plans/` is empty;
  `.DS_Store`).
- **Keep `.cursorignore`.** It is upstream's, and deleting an upstream file causes
  a delete/modify conflict at the next merge. Its single entry `spm-files` is
  already covered by `.gitignore:88`, and Claude Code does not index, so it is
  inert rather than harmful.

## Result

| | Before | After |
| --- | --- | --- |
| Prime directive loaded | no | yes, every session |
| Path-scoped conventions | Cursor only | 1:1 in Claude Code |
| Upstream-file footprint | — | 2 lines in `CLAUDE.md`, 4 appended in `.gitignore` |
| Shared with the team | Cursor users only | yes, via `.claude/rules/` in git |

## Verification

1. `git check-ignore -v .claude/rules/swift-conventions.md` exits non-zero (not ignored).
2. `git status` shows the three rule files as tracked additions.
3. In a fresh session, `/context` lists `CLAUDE.md` and the expanded
   `NICEGRAM-AGENTS.md` under **Memory files**.
4. After reading a file under `submodules/**/*.swift`, `telegram-interop.md` is
   in context; it is absent in a session that never touches one.
5. `grep -rn "\.cursor/rules" --exclude-dir=.git .` returns nothing outside
   `docs/`.

## Out of scope

- **Rule triplication.** The marker/change-ladder rules now exist in three places:
  `NICEGRAM-AGENTS.md`, `.pr_agent.toml`'s `extra_instructions`, and
  `telegram-interop.md`. They will drift. Collapsing them needs a decision about
  whether pr-agent can read a file from the repo, which is a separate piece of work.
- **Rewriting rule content.** Bodies move verbatim; this migration changes where
  instructions live, not what they say.
- **Hooks.** A `PostToolUse` hook enforcing markers on `submodules/**/*.swift`
  edits was considered and explicitly declined.
