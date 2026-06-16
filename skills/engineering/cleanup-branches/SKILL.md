---
name: cleanup-branches
description: Delete unwanted local branches from every git repo found under the current working directory. Discovers repos with `find -type d -name .git -prune`, lists all non-protected local branches, gets explicit confirmation, then deletes each from origin and locally. Use when the user says "cleanup branches", "delete local branches", "clean up all branches", or "remove stale branches".
thinking: low
---

# Skill: Cleanup Branches

Scan every git repo under the **current working directory** for local branches (excluding `main`/`master`/`develop` and the branch currently checked out in each repo), show the full list, confirm, then delete each from origin and locally.

**Never guess — always show the list and get explicit confirmation before deleting.**

---

## Step 1 — Discover repos and collect branches

The workspace is the directory you were invoked in. Find every git repo under it using `find` with `-prune` so vendored / submodule git dirs inside a repo are NOT scanned independently:

```bash
WORKSPACE="$(pwd)"

find "$WORKSPACE" -type d -name .git -prune | while read -r gitdir; do
  repo="$(dirname "$gitdir")"
  rel="${repo#$WORKSPACE/}"
  ( cd "$repo" \
      && git branch \
      | grep -v '^\*' \
      | sed 's/^[[:space:]]*//' \
      | grep -Ev '^(main|master|develop)$' \
      | while read -r branch; do
          echo "$rel | $branch"
        done )
done
```

Build an in-memory table:

| # | Repo (relative)   | Branch                |
|---|-------------------|-----------------------|
| 1 | `repo-a`          | `feat/foo`            |
| 2 | `repo-a`          | `fix/bar`             |
| 3 | `group/repo-b`    | `experiment/baz`      |

### Edge cases

- **No repos found** — print and stop:
  ```
  ℹ️  No git repos found under <workspace>.
  ```
- **Repos found but no deletable branches** — print and stop:
  ```
  ✅ All repos are clean — no deletable local branches found.
  ```

---

## Step 2 — Show list and ask for confirmation

Print the collected branches **grouped by repo for readability** but with **a single global numbering** so the user's picks are unambiguous. Example:

```
repo-a
   1. feat/foo
   2. fix/bar

group/repo-b
   3. experiment/baz
```

Then ask:

> "Found **N** branch(es) across **M** repo(s). Delete all from origin and locally?"
>
> Choices: **Yes, delete all** | **Let me pick** | **Cancel**

### If "Let me pick":

Ask: `Which numbers to delete? (e.g., 1,3,5-8 or "all")`. Parse the reply into a set of selected indices. Only delete those.

### If "Cancel":

Stop immediately. Print: `🚫 Cleanup cancelled.`

---

## Step 3 — Delete branches

For each confirmed branch, run in sequence (origin first, then local):

```bash
cd "$WORKSPACE/<repo>"

# Delete from origin — tolerate "remote ref does not exist"
git push origin --delete <branch> 2>&1 \
  && echo "✅ origin/<branch> deleted" \
  || echo "⚠️  origin/<branch> not found on remote (skipped)"

# Delete locally — force, since the branch may not be merged
git branch -D <branch> \
  && echo "✅ local <branch> deleted" \
  || echo "❌ Failed to delete local <branch>"
```

Process all branches. Do NOT stop on a single failure — continue and collect errors.

---

## Step 4 — Summary report

After processing all branches, print:

```
🧹 Branch Cleanup Complete

┌────────────────────────────────┬──────────────────────┬────────┐
│ Repo                           │ Branch               │ Result │
├────────────────────────────────┼──────────────────────┼────────┤
│ repo-a                         │ feat/foo             │ ✅     │
│ repo-a                         │ fix/bar              │ ✅     │
│ group/repo-b                   │ experiment/baz       │ ⚠️     │
└────────────────────────────────┴──────────────────────┴────────┘

✅ Deleted: N   ⚠️ Skipped (not on remote): M   ❌ Failed: 0
```

Legend:
- ✅ = deleted from both origin and local
- ⚠️ = branch not found on origin, only deleted locally
- ❌ = local deletion failed (report the error)

---

## Rules

| Rule | Detail |
|------|--------|
| **CWD is the workspace** | Always scan the directory you were invoked in. Never accept or infer a path argument. |
| **Auto-discover repos** | Use `find -type d -name .git -prune` — `-prune` is required so a repo's vendored / submodule git dirs are NOT treated as independent repos. |
| **Local branches only** | Never run `git fetch`, `git branch -r`, or iterate remote branches. |
| **Protected branches** | Never delete `main`, `master`, `develop`, or the branch currently checked out (`*`) in any repo. |
| **Confirm before delete** | Always show the full list and get explicit user confirmation. |
| **Origin first** | Always attempt remote delete before local delete. |
| **Force local delete** | Use `git branch -D`, not `-d` — branches may be unmerged. |
| **Never stop on error** | Log failures, continue processing remaining branches. |
| **No auto-fetch** | Do not run `git fetch` or `git pull` at any point. |
