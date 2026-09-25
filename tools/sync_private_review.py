#!/usr/bin/env python3
"""Stage the current committed game in a separate, history-free review repo.

No network access, commits, pushes, or changes to the development repository.
Only the separate sibling abyssal-bloom-private-review/repository is written.
"""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile


ROOT = Path(__file__).resolve().parents[1]
WORKSPACE = ROOT.parent / "abyssal-bloom-private-review"
DESTINATION = WORKSPACE / "repository"
LIMIT = 100 * 1024 * 1024


def git(root: Path, *arguments: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), *arguments])


def safe_path(root: Path, name: str) -> Path:
    relative = Path(name)
    if relative.is_absolute() or ".." in relative.parts or ".git" in relative.parts:
        raise RuntimeError(f"Unsafe snapshot path: {name!r}")
    path = root / relative
    if not path.resolve().is_relative_to(root.resolve()):
        raise RuntimeError(f"Snapshot path escapes destination: {name!r}")
    return path


def main() -> None:
    if WORKSPACE.is_symlink() or DESTINATION.is_symlink():
        raise SystemExit("Refusing a symlinked publishing workspace.")
    if git(ROOT, "status", "--porcelain").strip():
        raise SystemExit("Commit or resolve development changes first; nothing was copied.")
    source_commit = git(ROOT, "rev-parse", "HEAD").decode().strip()
    rows = git(ROOT, "ls-tree", "-rlz", "HEAD").split(b"\0")
    source_names = set()
    for row in rows:
        if not row:
            continue
        metadata, raw_name = row.split(b"\t", 1)
        mode, kind, _oid, size = metadata.split()
        name = os.fsdecode(raw_name)
        safe_path(ROOT, name)
        if kind != b"blob" or mode not in (b"100644", b"100755"):
            raise SystemExit(f"Review unsupported snapshot entry before publishing: {name}")
        if int(size) > LIMIT or name.startswith(".review-publish/"):
            raise SystemExit(f"Ineligible publishing entry: {name}")
        source_names.add(name)

    existing = (DESTINATION / ".git").is_dir()
    old_names = set()
    if DESTINATION.exists() and not existing:
        raise SystemExit("Publishing destination exists without a Git repository; inspect it first.")
    if existing:
        if git(DESTINATION, "status", "--porcelain").strip():
            raise SystemExit("Publishing copy has changes; review/commit them before syncing again.")
        if git(DESTINATION, "branch", "--show-current").strip() != b"main":
            raise SystemExit("Publishing copy must be on main; no files changed.")
        old_names = {os.fsdecode(p) for p in git(DESTINATION, "ls-files", "-z").split(b"\0") if p}
        for name in old_names | source_names:
            safe_path(DESTINATION, name)

    WORKSPACE.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="snapshot-", dir=WORKSPACE) as temporary:
        extracted = Path(temporary)
        # git archive exports only committed content, never the old .git/history.
        process = subprocess.Popen(
            ["git", "-C", str(ROOT), "archive", "--format=tar", source_commit],
            stdout=subprocess.PIPE,
        )
        try:
            with tarfile.open(fileobj=process.stdout, mode="r|") as archive:
                for member in archive:
                    target = safe_path(extracted, member.name)
                    if member.isdir():
                        target.mkdir(parents=True, exist_ok=True)
                    elif member.isfile():
                        target.parent.mkdir(parents=True, exist_ok=True)
                        with archive.extractfile(member) as incoming, target.open("wb") as outgoing:
                            shutil.copyfileobj(incoming, outgoing)
                        target.chmod(0o755 if member.mode & 0o111 else 0o644)
                    else:
                        raise RuntimeError(f"Unsupported archive entry: {member.name}")
            if process.wait() != 0:
                raise RuntimeError("git archive failed")
        finally:
            process.stdout.close()
            if process.poll() is None:
                process.terminate()
                process.wait()

        extracted_names = {str(p.relative_to(extracted)) for p in extracted.rglob("*") if p.is_file()}
        if extracted_names != source_names:
            raise RuntimeError("Archive does not exactly match the committed tree (check export-ignore attributes).")
        if not existing:
            DESTINATION.mkdir()
            git(DESTINATION, "init", "-b", "main")
        # Only remove files tracked in this separate publishing copy that have
        # been explicitly removed from the new source commit. Originals stay.
        for name in sorted(old_names - source_names):
            target = safe_path(DESTINATION, name)
            if target.exists():
                target.unlink()
        for name in sorted(source_names):
            target = safe_path(DESTINATION, name)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(extracted / name, target)
        git(DESTINATION, "add", "-A")
        (DESTINATION / ".git" / "review-source-commit").write_text(source_commit + "\n")
    print(f"Source commit: {source_commit}")
    print(f"Publishing copy: {DESTINATION}")
    print(git(DESTINATION, "diff", "--cached", "--shortstat").decode())
    print("Review git diff --cached there, commit, then push only to a verified private repository.")


if __name__ == "__main__":
    main()
