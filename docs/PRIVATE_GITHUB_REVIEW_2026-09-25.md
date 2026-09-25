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
python3 -B tools/test_run_regression_suite.py
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
unchanged. The sibling `abyssal-bloom-private-review/repository/` is a separate
publishing copy with a fresh `main` history, made from the committed snapshot. Only that
repository is intended for GitHub. The tradeoff is that online review starts
with this snapshot rather than the earlier milestone history. The full old
history remains available in the original development repository. No force
push, history rewrite or replacement of the original `.git` is involved.

The original project remains the development workspace. The publishing copy
is a review snapshot; do not edit both copies independently. Later snapshots
must synchronize committed files, including removals, and be reviewed in the
publishing copy before committing and pushing. Never merge the development
ancestry into the publishing copy: that would reintroduce the oversized ZIPs.

The publishing repository, verification checkout, logs and helper downloads
are stored beside the project at `../abyssal-bloom-private-review/`. They are
outside the Godot project because the existing validator recursively scans
ignored folders too. `-B` on the Python runner tests prevents generated
`__pycache__` files from introducing an additional validator diagnostic.

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
background registry discrepancies (25 diagnostics). The normal regression
command stops at that prerequisite. These are preserved review findings,
not packaging fixes. All 47 directly executed Godot scripts passed in isolated
save/config/cache environments in the development project on 2026-09-25.

The development Main Menu headless smoke exited 0, with existing shutdown
warnings about five leaked ObjectDB instances and three resources still in
use. This is recorded as a known issue, not a warning-free runtime result.

The development change diff is whitespace-clean. Treating every existing file
as newly added in the fresh publishing root reveals 176 inherited whitespace
diagnostics (including Markdown hard breaks and existing script whitespace).
They are retained to preserve the source exactly; no formatting sweep was
mixed into this preparation.

Fresh-checkout verification completed on 2026-09-25 using a `git clone
--no-local` of the publishing repository, with no copied `.godot/` directory:

| Check | Development project | Fresh review checkout |
| --- | --- | --- |
| Godot version | 4.7.2 official | Same executable |
| Fresh headless editor import | Existing cache | Exit 0; shutdown warnings below |
| Python runner tests | 4/4 passed | 4/4 passed |
| Direct isolated Godot scripts | 47/47 passed | 47/47 passed |
| Structural validator | 25 diagnostics; exit 1 | Identical 25 diagnostics; exit 1 |
| Official cumulative runner | Stops at validator | Identical prerequisite failure |
| Main Menu headless smoke | Exit 0 | Exit 0 |

The fresh editor import also reports the existing five ObjectDB/three-resource
shutdown warnings, with no missing-resource or parse errors. Fresh-checkout
Godot import and tests leave tracked files unchanged. Runtime files and asset
bytes match the development snapshot. Two reference CSV files receive only
CRLF-to-LF normalization under the pre-existing `.gitattributes` rule.
The complete publishing tree is checked against the development commit tree.

All 14 excluded archives remain on disk with the same Git object hashes as
their historical originals. Publishing history has no blobs over 100 MiB;
the largest is 3,844,985 bytes. The 1,945-file snapshot includes 731 UID/import
sidecar files. No LFS pointers or missing LFS content are involved.

The sync helper passed five temporary-repository checks: first snapshot with
independent history, refusal of dirty development files, refusal of dirty
publishing files, correct add/change/removal synchronization, and subsequent
commits retaining independent history. Detailed local logs and the exact
checkpoint file manifest live in `../abyssal-bloom-private-review/evidence/`.

Interactive gameplay and the visual acceptance checklist in
`REVIEW_CHECKPOINT_2026-09-25.md` remain necessary. No new interactive
playthrough is claimed by these automated checks.

## Authentication and private destination

No destination is configured yet and nothing has been uploaded. GitHub CLI
2.101.0 was downloaded from the official release, checked against its published
SHA-256 list, and installed at `/home/fluffy56/.local/bin/gh`. It reports no
authenticated accounts. Use normal GitHub browser/device login via
`gh auth login --hostname github.com --git-protocol https --web` on the local
machine. Never paste access tokens or passwords into chat or project files.

Once the owner/repository is chosen, create or verify a **private** repository
and set `origin` only in the sibling `abyssal-bloom-private-review/repository/`.
Confirm its visibility before pushing `main`, then verify the remote commit
equals local `HEAD`.
Do not push all branches or use `--mirror` from the development repository.

For subsequent changes, review in the original project, run relevant checks,
then `git add` the intended files and `git commit -m "Describe the change"`.
Run `python3 tools/sync_private_review.py` in the original project to stage
that committed snapshot into the publishing copy. The tool refuses a dirty
source or publishing copy, checks file sizes and exports committed files only.
It also removes formerly tracked publishing files when the source commit
removed them; it never deletes files in the development project.

Then, from the sibling `abyssal-bloom-private-review/repository/`, review
`git diff --cached --stat` and `git diff --cached`, commit there, and run
`git push origin main`.
The two repositories deliberately have different commit IDs and histories.

Example update routine from the original project's terminal:

```bash
git status
git diff
# Run the relevant checks and inspect their output before committing.
git add path/to/the/files/you/intend/to/change
git diff --cached
git commit -m "Describe the change"
python3 tools/sync_private_review.py
git -C ../abyssal-bloom-private-review/repository diff --cached --stat
git -C ../abyssal-bloom-private-review/repository diff --cached
git -C ../abyssal-bloom-private-review/repository commit -m "Update review snapshot"
git -C ../abyssal-bloom-private-review/repository push origin main
```

The final push requires the private remote setup to be completed first. Use
specific file paths with `git add`; inspect unexpected files before including
them. A commit is a local checkpoint. A push uploads committed history.
Ignored local files are neither committed nor uploaded.
