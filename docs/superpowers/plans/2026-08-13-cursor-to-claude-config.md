# Cursor → Claude Code Config Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the fork's AI rules load in Claude Code — always-on rules via an import in `CLAUDE.md`, path-scoped rules via `.claude/rules/` — while touching upstream files as little as possible.

**Architecture:** Two documented Claude Code mechanisms replace Cursor's two. `.claude/rules/*.md` with YAML `paths:` frontmatter replaces `.cursor/rules/*.mdc` with `globs:`, 1:1. A two-line `@NICEGRAM-AGENTS.md` import at the top of upstream's `CLAUDE.md` replaces Cursor's implicit always-on read of `AGENTS.md`. No content is rewritten and nothing moves out of upstream's `CLAUDE.md`.

**Tech Stack:** Markdown, YAML frontmatter, git, `.gitignore` pattern semantics. No code, no build, no tests.

**Spec:** [docs/superpowers/specs/2026-08-13-cursor-to-claude-config-design.md](../specs/2026-08-13-cursor-to-claude-config-design.md)

## Global Constraints

- **Upstream files are additions-only.** `CLAUDE.md`, `.gitignore` and `.cursorignore` arrive via `tg-merge` commits. Never modify or delete an existing line in them. Total permitted footprint for this change: **2 content lines in `CLAUDE.md`, 4 content lines in `.gitignore`, zero elsewhere.** Each block also adds one blank separator line, so `git diff --stat` reads 3 and 5 insertions respectively — with **zero deletions**, which is the constraint that actually matters. Both files currently end with a trailing newline, so the recipes below append and prepend cleanly; a non-zero deletion count means that changed and the last line was rewritten.
- **Every addition to an upstream file carries a Nicegram marker.** In Markdown that is `<!-- Nicegram AI rules -->`; in `.gitignore` it is `# Nicegram: track shared Claude Code rules`.
- **`.cursorignore` is upstream's file. Do not delete or edit it.**
- **Rule bodies move verbatim.** This migration changes where instructions live, not what they say. Use the byte-preserving `tail -n +6` recipes below rather than retyping content.
- **No tests exist in this repo.** Every task ends in explicit verification commands with stated expected output.
- **Commits go through the `jira-commit` skill**, which needs a Jira ticket key and produces a conventional-commit subject, a bullet body, and a `Task: NCG-XXXXX` trailer. Do not hand-write commits.
- All commands assume the repo root `/Users/denisshilovich/work/nicegram-ios` as the working directory.

---

## File Structure

**Created:**
- `.claude/rules/telegram-interop.md` — marker syntax + SSignalKit bridging; attaches on `submodules/**/*.swift`
- `.claude/rules/nicegram-modules.md` — `Nicegram/**` module layout, `NGUtils`, resources; attaches on `Nicegram/**`
- `.claude/rules/swift-conventions.md` — Swift style for our code; attaches on our Swift in both trees

**Renamed:**
- `AGENTS.md` → `NICEGRAM-AGENTS.md` — the fork's always-on doc

**Modified:**
- `NICEGRAM-AGENTS.md:60-65` — closing conventions section repointed at `.claude/rules/`
- `CLAUDE.md:1` — two lines inserted above the header (upstream file)
- `.gitignore` — four lines appended at EOF (upstream file)

**Deleted:**
- `.cursor/rules/{telegram-interop,nicegram-modules,swift-conventions}.mdc`

One rule file per topic, matching both the source layout and the sibling repo `nicegram-assistant-ios`, whose `.claude/rules/swift-conventions.md` shares this repo's filename for the same topic.

---

## Task 1: Port the three rules into `.claude/rules/`

Creates the rule files and makes git able to track them. Delivers path-scoped conventions in Claude Code. Independently reviewable: a reviewer can reject the frontmatter globs or the gitignore idiom without touching the rename in Task 2.

**Files:**
- Create: `.claude/rules/telegram-interop.md`, `.claude/rules/nicegram-modules.md`, `.claude/rules/swift-conventions.md`
- Modify: `.gitignore` (append 4 lines at EOF)
- Read-only source: `.cursor/rules/*.mdc` (deleted later, in Task 3)

**Interfaces:**
- Consumes: nothing.
- Produces: the three paths above. Task 2 names them in `NICEGRAM-AGENTS.md`'s conventions section; Task 3 verifies no stale `.cursor/rules` references remain.

- [ ] **Step 1: Confirm the source frontmatter is the shape the recipes assume**

All three `.mdc` files must have a 5-line frontmatter block with a blank line 6, so that `tail -n +6` yields the body starting with its blank separator.

```bash
for f in .cursor/rules/*.mdc; do echo "== $f"; sed -n '1,7p' "$f" | nl -ba; done
```

Expected: for each file, lines 1 and 5 are `---`, lines 2–4 are `description:` / `globs:` / `alwaysApply:`, line 6 is empty, line 7 is a `#` heading. If any file differs, stop and adjust that file's `tail -n +N` offset rather than proceeding.

- [ ] **Step 2: Generate the three rule files**

New frontmatter carries only `paths:` — Claude Code has no equivalent of `description:` or `alwaysApply:`. The globs are copied from each source's `globs:` line, split into a YAML list.

```bash
mkdir -p .claude/rules

{ printf -- '---\npaths:\n  - "submodules/**/*.swift"\n---\n'; tail -n +6 .cursor/rules/telegram-interop.mdc; } > .claude/rules/telegram-interop.md

{ printf -- '---\npaths:\n  - "Nicegram/**"\n---\n'; tail -n +6 .cursor/rules/nicegram-modules.mdc; } > .claude/rules/nicegram-modules.md

{ printf -- '---\npaths:\n  - "Nicegram/**/*.swift"\n  - "submodules/**/Nicegram/**/*.swift"\n---\n'; tail -n +6 .cursor/rules/swift-conventions.mdc; } > .claude/rules/swift-conventions.md
```

- [ ] **Step 3: Verify the bodies are byte-identical to the sources**

Comparing from line 6 of each pair proves nothing in the body was altered.

The offset differs per file: the old frontmatter was always 5 lines, but the new one is 4 lines for a single-glob rule and 5 for `swift-conventions`, which has two. Do not loop with one shared offset — that reports a false `BODY DIFFERS` on `swift-conventions`.

```bash
diff <(tail -n +6 .cursor/rules/telegram-interop.mdc)  <(tail -n +5 .claude/rules/telegram-interop.md)  && echo "telegram-interop:  identical"
diff <(tail -n +6 .cursor/rules/nicegram-modules.mdc)  <(tail -n +5 .claude/rules/nicegram-modules.md)  && echo "nicegram-modules:  identical"
diff <(tail -n +6 .cursor/rules/swift-conventions.mdc) <(tail -n +6 .claude/rules/swift-conventions.md) && echo "swift-conventions: identical"
```

Expected: `identical` three times, with no diff output. As an offset-independent cross-check, the body byte counts should match too — 1811, 1092 and 2426 respectively:

```bash
for n in telegram-interop nicegram-modules swift-conventions; do
  a=$(tail -n +6 ".cursor/rules/$n.mdc" | wc -c | tr -d ' ')
  b=$(sed '1,/^---$/d;1,/^---$/d' ".claude/rules/$n.md" | wc -c | tr -d ' ')
  printf '%-20s source=%s new=%s\n' "$n" "$a" "$b"
done
```

- [ ] **Step 4: Verify the new frontmatter parses as intended**

```bash
head -6 .claude/rules/swift-conventions.md
```

Expected exactly:

```
---
paths:
  - "Nicegram/**/*.swift"
  - "submodules/**/Nicegram/**/*.swift"
---

```

- [ ] **Step 5: Confirm the rules are currently invisible to git**

Upstream's `.gitignore:92` is `/.claude/`, so before the next step git cannot see the new files. Establishing this first makes the fix's effect unambiguous.

```bash
git status --porcelain -uall .claude
```

Expected: no output.

- [ ] **Step 6: Append the un-ignore block to `.gitignore`**

A bare `!/.claude/rules/` does **not** work — git will not re-include a path whose parent directory is excluded, because it never descends into it. The parent must be re-included, its other contents re-excluded, then `rules/` re-included.

```bash
printf '\n# Nicegram: track shared Claude Code rules\n!/.claude/\n/.claude/*\n!/.claude/rules/\n' >> .gitignore
```

- [ ] **Step 7: Verify the rules are trackable and local files are still ignored**

```bash
git status --porcelain -uall .claude
git check-ignore -v .claude/settings.local.json
tail -5 .gitignore
```

Expected: three `??` lines for the rule files; `check-ignore` prints a matching rule for `settings.local.json` and exits 0 (still ignored); the tail shows the four appended lines preceded by a blank line.

- [ ] **Step 8: Verify upstream's existing `.gitignore` lines are untouched**

```bash
git diff --stat .gitignore
git diff .gitignore | grep -c '^-[^-]' || true
```

Expected: `1 file changed, 5 insertions(+)` and a removed-line count of `0`. Any removal means an upstream line was modified — revert and redo the append.

- [ ] **Step 9: Commit**

Invoke the `jira-commit` skill with the ticket key for this work. The commit covers `.gitignore` and the three files under `.claude/rules/`. Suggested subject: `chore(ai): port Cursor rules to .claude/rules`.

---

## Task 2: Rename the fork's rules file and wire it into `CLAUDE.md`

Delivers the always-on half: the prime directive and change ladder load in every session. Independently reviewable — the naming decision and the upstream `CLAUDE.md` edit can be rejected without disturbing Task 1's rule files.

**Files:**
- Rename: `AGENTS.md` → `NICEGRAM-AGENTS.md`
- Modify: `NICEGRAM-AGENTS.md:60-65`
- Modify: `CLAUDE.md` (insert 2 lines above line 1 — upstream file)

**Interfaces:**
- Consumes: the three `.claude/rules/*.md` paths created in Task 1, named in the conventions section.
- Produces: `NICEGRAM-AGENTS.md` at the repo root, imported by `CLAUDE.md`. Task 3 verifies no stale references to the old name.

- [ ] **Step 1: Rename the file, preserving history**

```bash
git mv AGENTS.md NICEGRAM-AGENTS.md
```

- [ ] **Step 2: Confirm nothing else in the repo referenced the old name**

`.pr_agent.toml` inlines its own copy of the rules rather than reading the file, and the `build-system/bazel-rules/sourcekit-bazel-bsp/` hits are a vendored dependency's own `AGENTS.md` files — both unrelated. But the rule bodies themselves cite the file in prose, so this grep is **expected to find hits that must be fixed**, not to come back clean.

```bash
grep -rn "AGENTS\.md" --exclude-dir=.git --exclude-dir=submodules --exclude-dir=third-party --exclude-dir=build-system --exclude-dir=docs . || echo "no references"
```

Expected hits, all to be updated to `NICEGRAM-AGENTS.md`:

- `.claude/rules/telegram-interop.md:9` — "ladder in `AGENTS.md`"
- `.claude/rules/nicegram-modules.md:17` — "the assistant consumes (see `AGENTS.md`)"

Ignore the `.cursor/rules/*.mdc` hits; Task 3 deletes those files. Note this edits two files Task 1 committed as byte-identical to their sources — intended, and the only place the ported bodies diverge from the originals.

Re-run the grep after fixing, adding `--exclude-dir=.cursor` and piping through `grep -v NICEGRAM-AGENTS`; that must print `no stale references`.

- [ ] **Step 3: Repoint the conventions section**

Replace lines 60–65 of `NICEGRAM-AGENTS.md` — the entire `## Detailed conventions` section — with the text below. The `.mdc` extensions become `.md`, the directory changes, and a closing paragraph records the division of labour with upstream's file.

```markdown
## Detailed conventions (`.claude/rules/`, auto-attached by path)

- `telegram-interop.md` — editing `submodules/**`: marker syntax + SSignalKit
  bridges.
- `nicegram-modules.md` — `Nicegram/**` modules, `NGUtils`, resources.
- `swift-conventions.md` — Swift style for our code.

`CLAUDE.md` at the repo root is upstream Telegram's own file, not ours. It stays
the authority on the Bazel build, the embedded watch app, the Postbox →
TelegramEngine refactor and the tgcalls testbench. This file covers only what the
fork adds, and is pulled into Claude Code by a marked two-line import at the top
of `CLAUDE.md`.
```

- [ ] **Step 4: Verify the body above the section is unchanged**

Only the tail of the file should differ from the original.

```bash
diff <(git show HEAD:AGENTS.md | sed -n '1,59p') <(sed -n '1,59p' NICEGRAM-AGENTS.md) && echo "lines 1-59 unchanged"
```

Expected: `lines 1-59 unchanged`.

- [ ] **Step 5: Insert the marked import at the top of upstream's `CLAUDE.md`**

Line 1, not EOF: upstream appends new sections at the end of this file, so an insert there collides on most merges, while the header above line 1 has survived three. The HTML comment satisfies the change ladder's no-unmarked-edits rule and is stripped by Claude Code before injection, so it costs nothing in context.

```bash
printf '<!-- Nicegram AI rules -->\n@NICEGRAM-AGENTS.md\n\n' | cat - CLAUDE.md > CLAUDE.md.tmp && mv CLAUDE.md.tmp CLAUDE.md
```

- [ ] **Step 6: Verify exactly three lines were added and none removed**

```bash
head -4 CLAUDE.md
git diff --stat CLAUDE.md
git diff CLAUDE.md | grep -c '^-[^-]' || true
```

Expected: the head shows the comment, the import, a blank line, then `# CLAUDE.md`; the stat reads `1 file changed, 3 insertions(+)`; the removed-line count is `0`. (Three insertions, of which the blank separator is one — the two content lines are the budgeted footprint.)

- [ ] **Step 7: Verify the import resolves**

An `@` import silently no-ops if the path is wrong, so check the target exists at the path as written, relative to the importing file.

```bash
test -f NICEGRAM-AGENTS.md && echo "import target exists"
head -1 NICEGRAM-AGENTS.md
```

Expected: `import target exists`, then `# nicegram-ios`.

- [ ] **Step 8: Commit**

Invoke the `jira-commit` skill with the ticket key for this work. The commit covers the rename, `NICEGRAM-AGENTS.md` and `CLAUDE.md`. Suggested subject: `chore(ai): load fork rules in Claude Code via NICEGRAM-AGENTS.md`.

---

## Task 3: Remove the Cursor rules and verify end to end

Delivers the cleanup and the whole-change verification. Split from Task 1 so the new rules can be reviewed while the old ones are still on disk for comparison.

**Files:**
- Delete: `.cursor/rules/telegram-interop.mdc`, `.cursor/rules/nicegram-modules.mdc`, `.cursor/rules/swift-conventions.mdc`
- Untouched, deliberately: `.cursorignore`

**Interfaces:**
- Consumes: everything from Tasks 1 and 2.
- Produces: nothing downstream.

- [ ] **Step 1: Confirm the replacements are committed before deleting the sources**

```bash
git ls-files .claude/rules
```

Expected: the three `.md` paths. If empty, Task 1 did not commit — stop.

- [ ] **Step 2: Delete the tracked Cursor rules**

```bash
git rm -r --quiet .cursor/rules
```

- [ ] **Step 3: Remove leftover untracked Cursor files**

`.cursor/plans/` is empty and was never tracked; `.DS_Store` is noise. This clears the directory without touching `.cursorignore`, which lives at the repo root and belongs to upstream.

```bash
rm -rf .cursor
ls -d .cursor 2>/dev/null || echo ".cursor removed"
```

Expected: `.cursor removed`.

- [ ] **Step 4: Verify `.cursorignore` survived**

```bash
git status --porcelain .cursorignore
test -f .cursorignore && echo ".cursorignore intact"
```

Expected: no status output (unmodified), then `.cursorignore intact`. Any status line here is a constraint violation — restore it with `git checkout -- .cursorignore`.

- [ ] **Step 5: Verify no stale references remain**

```bash
grep -rn "\.cursor/rules\|\.mdc" --exclude-dir=.git --exclude-dir=submodules --exclude-dir=third-party --exclude-dir=docs . || echo "no stale references"
```

Expected: `no stale references`. (`docs/` is excluded because the spec and this plan describe the old layout on purpose.)

- [ ] **Step 6: Verify the total upstream footprint across the whole change**

This assumes one commit per task, so the three commits are `HEAD~3..HEAD`. If any were squashed or split, adjust the range to start at the commit before Task 1's.

```bash
git diff --stat HEAD~3..HEAD -- CLAUDE.md .gitignore .cursorignore
git diff HEAD~3..HEAD -- CLAUDE.md .gitignore .cursorignore | grep -c '^-[^-]' || true
```

Expected: `CLAUDE.md` +3, `.gitignore` +5, `.cursorignore` absent from the output entirely, and a removed-line count of `0`.

- [ ] **Step 7: Commit**

Invoke the `jira-commit` skill with the ticket key for this work. Suggested subject: `chore(ai): drop Cursor rules superseded by .claude/rules`.

- [ ] **Step 8: Verify loading in a fresh Claude Code session**

The only check that proves the mechanisms actually fire; it cannot be scripted, so run it by hand.

1. Start a new session at the repo root and run `/context`. Under **Memory files**, `CLAUDE.md` must be listed, and the fork's content (the "Prime directive" heading from `NICEGRAM-AGENTS.md`) must be present in the loaded instructions.
2. In the same session, read any file under `submodules/` ending in `.swift`, then confirm the `telegram-interop` rule's content is now in context. Path-scoped rules attach when Claude reads a matching file, not at launch.
3. In a separate session that touches no Swift file, confirm `telegram-interop` is *not* loaded — this is what distinguishes a working `paths:` scope from an always-on rule.

If step 2 fails, the likely cause is a `paths:` glob mismatch; re-check the frontmatter written in Task 1 Step 2 against the table in the spec.

---

## Rollback

Every task is a single commit touching only documentation and ignore rules; no build artifacts or code are involved. `git revert` of the three commits restores the Cursor layout exactly, including `AGENTS.md`'s original name and path.
