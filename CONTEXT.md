# my-configs

Personal dotfiles, editor configs, and Claude Code skills. The `skills/` tree is the active area of work.

## Language

### Branch cleanup

**Workspace**:
The directory tree rooted at the current working directory when `/cleanup-branches` is invoked. The skill scans the workspace for repos; no path argument is ever passed.
_Avoid_: Root, project root, monorepo

**Repo**:
A directory containing a `.git/` folder, discovered by walking the workspace with `find -type d -name .git -prune`. `-prune` stops descent at each match so vendored or submodule checkouts are not treated as independent repos.
_Avoid_: Project, package, folder

**Local branch**:
A branch present in a repo's local git state (`git branch`). The unit `/cleanup-branches` operates on.

**Server branch**:
The same-named branch on the `origin` remote of a repo. Never enumerated or queried — the skill blindly attempts `git push origin --delete <branch>` as a side-effect of local deletion and tolerates the "remote ref does not exist" failure.
_Avoid_: Remote branch, origin branch

**Protected branch**:
A branch the skill refuses to touch: `main`, `master`, `develop`, and the branch currently checked out in each repo.

### Branch creation

**Naming template**:
A string with `{placeholder}` slots that resolves to a concrete branch name. Lives per-repo in `git config branch.naming.template`. Known placeholders: `{type}`, `{week}`, `{year}`, `{work_item}`, `{desc}`. Resolved at branch-creation time using global user inputs and auto-computed values.
_Avoid_: Pattern, format, scheme

**Default template**:
The fallback used when a repo has no `branch.naming.template` configured: `{type}/{week}-{year}-{work_item}-{desc}`. Not specific to any project — just a sensible default.

**Global input**:
A value (`type`, `work-item`, `desc`) the user provides once and that applies uniformly to every selected repo. Distinguished from auto-computed values (`week`, `year`) and from per-repo state (the template itself).
_Avoid_: Parameter, argument, variable

**Base ref**:
The fixed commit that every new branch is created from: `origin/main`, fetched fresh at creation time. A repo without `origin/main` fails for that repo only — others continue.
