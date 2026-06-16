---
name: create-branch
description: Create a new git branch in one or more repos discovered under the current working directory. Each repo's branch name follows a per-repo template (configurable via `git config branch.naming.template`), with sensible defaults. Branches are created from `origin/main` (fetched fresh) and stay local — no push. Use when the user says "create branch", "new branch", "start a feature", or wants to spin up parallel branches across services for a cross-service change.
thinking: low
---

# Skill: Create Branch

Scan every git repo under the **current working directory** for a multi-select, then create the same logically-named branch in each selected repo. Each repo resolves its own naming template (defaulting to a sensible default) and produces its own concrete branch name from the shared inputs.

**Never guess — always show the proposed branch names per repo and get explicit confirmation before creating.**

---

## Step 1 — Discover repos

The workspace is the directory you were invoked in. Find every git repo using `find` with `-prune` so vendored / submodule git dirs inside a repo are NOT scanned independently:

```bash
WORKSPACE="$(pwd)"

find "$WORKSPACE" -type d -name .git -prune | while read -r gitdir; do
  repo="$(dirname "$gitdir")"
  rel="${repo#$WORKSPACE/}"
  echo "$rel"
done
```

### Edge cases

- **No repos found** — print and stop:
  ```
  ℹ️  No git repos found under <workspace>.
  ```

---

## Step 2 — Select repos

Print the discovered repos with a single global numbering. Example:

```
Found 3 repo(s):
   1. service-a
   2. service-b
   3. shared/lib-c
```

Then ask:

> "Create a branch in which repos?"
>
> Choices: **All** | **Let me pick** | **Cancel**

### If "Let me pick":

Ask: `Which numbers? (e.g., 1,3 or "all")`. Parse into a set of selected indices.

### If "Cancel":

Stop immediately. Print: `🚫 Cancelled.`

---

## Step 3 — Resolve each repo's template

For each selected repo, read its naming template:

```bash
cd "$WORKSPACE/<repo>"
template="$(git config --get branch.naming.template)"
template="${template:-{type}/{week}-{year}-{work_item}-{desc}}"
```

A template is a string with `{placeholder}` slots. Known placeholders:

| Placeholder    | Source                                                       |
| -------------- | ------------------------------------------------------------ |
| `{type}`       | Always asked from the user (e.g. `feat`, `fix`, `chore`, `docs`) |
| `{week}`       | Auto: `date +%V` (zero-padded ISO week)                      |
| `{year}`       | Auto: `date +%Y`                                             |
| `{work_item}`  | Asked only if at least one selected repo's template uses it  |
| `{desc}`       | Asked only if at least one selected repo's template uses it  |

Build a list `(repo, template)` for downstream steps.

---

## Step 4 — Collect inputs (only what's needed)

Compute the union of placeholders across all selected repos' templates. Always ask for `{type}` regardless. Ask the rest only if present in that union.

```bash
# pseudo-logic
needed=(type)
for tpl in "${templates[@]}"; do
  [[ "$tpl" == *"{work_item}"* ]] && needed+=(work_item)
  [[ "$tpl" == *"{desc}"* ]]      && needed+=(desc)
done
```

Ask the user (in one message) for the needed inputs:

- **type** — branch type (`feat` / `fix` / `chore` / `docs` are common, but accept any non-empty string)
- **work-item** — issue / work-item identifier (if needed)
- **short-desc** — short description (if needed); auto-normalize to lowercase + dashes

Auto-compute:

```bash
WEEK="$(date +%V)"
YEAR="$(date +%Y)"
```

---

## Step 5 — Resolve branch names per repo and confirm

Substitute the inputs into each repo's template. Print the proposed result as a table:

```
┌────────────────────┬──────────────────────────────────────────────────┐
│ Repo               │ Proposed branch                                  │
├────────────────────┼──────────────────────────────────────────────────┤
│ service-a          │ feat/09-2026-501962-search-candidate-assignment  │
│ service-b          │ feat/09-2026-501962-search-candidate-assignment  │
│ shared/lib-c       │ feat/search-candidate-assignment                 │
└────────────────────┴──────────────────────────────────────────────────┘
```

If any resolved name still contains an unresolved `{placeholder}`, abort with a clear error pointing at the repo and missing variable.

Ask:

> "Create these branches from `origin/main`?"
>
> Choices: **Yes** | **Cancel**

---

## Step 6 — Create the branches

For each (repo, branch) in sequence:

```bash
cd "$WORKSPACE/<repo>"

# Fetch latest main from origin
git fetch origin main 2>&1 \
  || { echo "❌ <repo>: failed to fetch origin/main"; continue; }

# Create new branch from origin/main and switch to it
git checkout -b <branch> origin/main 2>&1 \
  && echo "✅ <repo>: <branch> created" \
  || echo "❌ <repo>: failed to create <branch>"
```

Process all selected repos. Do NOT stop on a single failure — continue and collect errors.

---

## Step 7 — Summary report

After processing, print:

```
🌱 Branch Creation Complete

┌────────────────────┬──────────────────────────────────────────────────┬────────┐
│ Repo               │ Branch                                           │ Result │
├────────────────────┼──────────────────────────────────────────────────┼────────┤
│ service-a          │ feat/09-2026-501962-search-candidate-assignment  │ ✅     │
│ service-b          │ feat/09-2026-501962-search-candidate-assignment  │ ✅     │
│ shared/lib-c       │ feat/search-candidate-assignment                 │ ❌     │
└────────────────────┴──────────────────────────────────────────────────┴────────┘

✅ Created: N   ❌ Failed: M
```

Legend:

- ✅ = created locally from `origin/main`
- ❌ = creation failed (fetch error, branch already exists, missing remote, etc. — report the error)

---

## Rules

| Rule | Detail |
|------|--------|
| **CWD is the workspace** | Always scan the directory you were invoked in. Never accept or infer a path argument. |
| **Auto-discover repos** | Use `find -type d -name .git -prune` — `-prune` is required so a repo's vendored / submodule git dirs are NOT treated as independent repos. |
| **Per-repo template** | Read `git config branch.naming.template` in each repo. Default fallback: `{type}/{week}-{year}-{work_item}-{desc}`. |
| **Global inputs** | `type`, `work-item`, `desc` are asked once and applied to all selected repos. |
| **Ask only what's needed** | Parse all selected repos' templates first; ask only for placeholders that actually appear. `{type}` always asked. |
| **`origin/main` is the base** | Always `git fetch origin main` then `git checkout -b <branch> origin/main`. If a repo has no `origin/main`, that repo fails and is logged — others continue. |
| **Local only** | Never push. The user runs `git push -u origin <branch>` themselves when ready. |
| **Confirm before creating** | Always show the resolved-name table and get explicit confirmation. |
| **Never stop on error** | Log failures, continue processing remaining repos. |
| **No auto-pull on existing branches** | Do not run `git pull` on `main` or any other branch. The fetch in Step 6 only updates `origin/main`. |
