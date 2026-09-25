# Private GitHub review preparation — 2026-09-25

## Open and run

Open `project.godot` in **Godot 4.7.2** and press F6 only for an individual
scene, or **F5 for the full game**. F5 opens the production Main Menu through
`res://scenes/app/application_root.tscn`. The project uses GL Compatibility.
The original author's Linux executable is `/home/fluffy56/.local/bin/godot4`.
Reviewers should use their own Godot 4.7.2 installation.

```bash
godot4 --editor --path .
godot4 --path .
python3 tools/validate_project.py --allow-generated-cache
python3 tools/test_run_regression_suite.py
python3 tools/run_regression_suite.py --godot /path/to/godot4
```

Import may take a little time on first opening. `.godot/` is regenerated from
the committed assets and import settings. `.uid` and adjacent `.import` files
are retained. No external asset download or LFS checkout is required.

## History and publishing decision

The development repository initially had no remotes, remote-tracking refs,
credential helper or discoverable GitHub CLI authentication. That provides no
evidence of previously published history; it cannot prove that no copy was
ever published elsewhere. Its branches and existing commits are preserved.

Initial disk usage was about 4.8 GiB, including 2.17 GiB of Git objects and
401 MiB of generated Godot cache. The current source/art tree, excluding Git
and generated cache, contained 2,328,099,074 bytes across 1,956 files.

Fourteen source packages account for 1,718,049,351 bytes. Nine character ZIPs
exceed GitHub's ordinary 100 MiB per-file limit, and are already in history.
Untracking a file only removes it from the new snapshot: it does **not** remove
the old blob from commits that a push would upload.

Consequently the development checkpoint remains local, with its ancestry
unchanged. `.review-publish/repository/` is a separate ignored publishing copy
with a fresh `main` history, made from the committed snapshot. Only that
repository is intended for GitHub. The tradeoff is that online review starts
with this snapshot rather than the earlier milestone history. The full old
history remains available in the original development repository. No force
push, history rewrite or replacement of the original `.git` is involved.

The original project remains the development workspace. The publishing copy
is a review snapshot; do not edit both copies independently. Later snapshots
must synchronize committed files, including removals, and be reviewed in the
publishing copy before committing and pushing. Never merge the development
ancestry into the publishing copy: that would reintroduce the oversized ZIPs.

## Included and excluded

Included: source, scenes, Resources, tests, tools, documentation, supplied
design/novel reference files, all loose artwork, `New Rooms+Props`, runtime
curated sprites, canonical item art, Godot UIDs and import configuration. No
loose image is excluded merely because a direct reference was not found.
There was no addon directory to exclude; future addons remain eligible.

The exact exclusions are in `.gitignore`:

- `.godot/`: generated imports, shader/editor cache and local editor state.
- Existing `/android/`: generated Godot Android build workspace.
- `/tools/__pycache__/`: generated Python bytecode from tooling.
- `/.review-publish/`: local publishing copy, fresh-checkout verification and
  evidence; nesting it here must not upload a second copy of the project.
- `/.env`, `/.env.local`, `/.env.*.local`, `/.godot/export_credentials.cfg`,
  `/export_credentials.cfg`: local secrets, if introduced later. No current
  credential file was discovered. Ordinary export settings are retained.
- The thirteen explicitly named character source ZIPs: archival art packages
  containing unused source variants as well as the selected art. Their
  extracted runtime PNGs and import settings are included. Runtime code has
  no ZIP-reader or archive-loading path. The ZIPs remain on disk and in old
  local history for future art work.
- `/assets/backgrounds.tar.gz`: every one of its 100 regular files matches an
  existing loose file byte-for-byte. The loose files remain included.

No exported builds or temporary output packages were found in the candidate
tree. There is no blanket exclusion of ZIPs, PNGs, art-source formats or save
fixtures. The tracked `save_test/` fixture files are retained.

## Size, LFS and secrets

After excluding those packages, the original candidate data is approximately
582 MiB. The largest retained asset is `jailer_boss_room.png`, 3,844,985 bytes.
LFS is unnecessary for this snapshot and has not been enabled. Future frequent
large binary revisions may warrant LFS, but doing so has separate storage and
download accounting and needs a deliberate plan.

GitHub blocks ordinary Git files over 100 MiB. GitHub's current LFS billing
documentation lists 10 GiB of storage and download bandwidth included for
Free/Pro accounts; excess usage depends on the owner's billing settings. No
paid storage, quota increase or billing setting was introduced.

Sources checked 2026-09-25:
- https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github
- https://docs.github.com/en/billing/concepts/product-billing/git-lfs

A redacted pattern scan checked current text, small text members in the
source ZIPs, and eligible blobs across every reachable Git branch. It found
no matches for private keys, common GitHub/API/cloud tokens, credential-bearing
URLs or long assigned secrets. File-name checks found no credential files.
This is a heuristic check, not a guarantee that arbitrary prose or binary
documents contain no sensitive information. No token values were printed.

## Verification and known issues

Before packaging, Python runner isolation tests passed 4/4 and `git diff
--check` was clean. Structural validation already failed on the legacy Quiet
Cell Blanket's omitted explicit false flag, room identity/order parsing and
background registry discrepancies. The normal regression command stops at
that prerequisite. These are preserved review findings, not packaging fixes.

Fresh import, isolated Godot script results and source/checkout equality will
be recorded after the clean publishing checkout is tested. Interactive
gameplay and the visual acceptance checklist in `REVIEW_CHECKPOINT_2026-09-25.md`
remain necessary.

## Authentication and private destination

No destination is configured yet. Use normal GitHub browser/device login via
`gh auth login --hostname github.com --git-protocol https --web` on the local
machine. Never paste access tokens or passwords into chat or project files.

Once the owner/repository is chosen, create or verify a **private** repository
and set `origin` only in `.review-publish/repository/`. Confirm its visibility
before pushing `main`, then verify the remote commit equals local `HEAD`.
Do not push all branches or use `--mirror` from the development repository.

For subsequent changes, review in the original project, run relevant checks,
then `git add` the intended files and `git commit -m "Describe the change"`.
Run `python3 tools/sync_private_review.py` in the original project to stage
that committed snapshot into the publishing copy. The tool refuses a dirty
source or publishing copy, checks file sizes and exports committed files only.
It also removes formerly tracked publishing files when the source commit
removed them; it never deletes files in the development project.

Then, from `.review-publish/repository/`, review `git diff --cached --stat`
and `git diff --cached`, commit there, and run `git push origin main`.
The two repositories deliberately have different commit IDs and histories.
