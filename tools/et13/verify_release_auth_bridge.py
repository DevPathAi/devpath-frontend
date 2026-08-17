#!/usr/bin/env python3
"""Fail-closed verification for the ET13 authenticated-input bridge."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import sys
import zipfile


MAX_ARCHIVE_BYTES = 512 * 1024 * 1024
MAX_ENTRY_BYTES = 16 * 1024 * 1024
MAX_JSON_BYTES = 1024 * 1024
SHA1 = re.compile(r"^(?!0{40}$)[0-9a-f]{40}$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
SAFE_NAME = re.compile(r"^[A-Za-z0-9._-]{1,256}$")
RELEASE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")


class BridgeError(RuntimeError):
    """A release-auth bridge invariant failed."""


def fail(message: str) -> None:
    raise BridgeError(f"ET13 release-auth bridge failed: {message}")


def _regular_size(path: Path, name: str, maximum: int) -> int:
    try:
        info = path.lstat()
    except OSError as error:
        fail(f"{name} is absent: {error}")
    if not stat.S_ISREG(info.st_mode) or path.is_symlink():
        fail(f"{name} must be one regular non-link file")
    if info.st_size < 1 or info.st_size > maximum:
        fail(f"{name} byte size is outside the bounded range")
    return info.st_size


def _regular_file(path: Path, name: str, maximum: int) -> bytes:
    _regular_size(path, name, maximum)
    try:
        return path.read_bytes()
    except OSError as error:
        fail(f"cannot read {name}: {error}")


def _file_sha256(path: Path, name: str, maximum: int) -> str:
    remaining = _regular_size(path, name, maximum)
    digest = hashlib.sha256()
    try:
        with path.open("rb") as source:
            while remaining:
                chunk = source.read(min(1024 * 1024, remaining))
                if not chunk:
                    fail(f"{name} was truncated while hashing")
                digest.update(chunk)
                remaining -= len(chunk)
            if source.read(1):
                fail(f"{name} grew while hashing")
    except OSError as error:
        fail(f"cannot hash {name}: {error}")
    return digest.hexdigest()


def _json_no_duplicates(bytes_value: bytes, name: str) -> object:
    def pairs(items: list[tuple[str, object]]) -> dict[str, object]:
        result: dict[str, object] = {}
        for key, value in items:
            if key in result:
                fail(f"{name} contains duplicate key {key!r}")
            result[key] = value
        return result

    try:
        text = bytes_value.decode("utf-8", errors="strict")
        return json.loads(text, object_pairs_hook=pairs)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        fail(f"{name} is not strict UTF-8 JSON: {error}")


def _positive_integer(value: object, name: str) -> int:
    if type(value) is not int or value < 1 or value > 9_007_199_254_740_991:
        fail(f"{name} must be a positive safe JSON integer")
    return value


def _exact_keys(value: object, expected: list[str], name: str) -> dict[str, object]:
    if not isinstance(value, dict) or list(value) != sorted(expected):
        fail(f"{name} keys/order mismatch")
    return value


def _exact_string(value: object, expected: str, name: str) -> str:
    if type(value) is not str or value != expected:
        fail(f"{name} mismatch")
    return value


def _pattern(value: object, pattern: re.Pattern[str], name: str) -> str:
    if type(value) is not str or pattern.fullmatch(value) is None:
        fail(f"{name} has an invalid value")
    return value


def _canonical_json(value: object) -> bytes:
    return (
        json.dumps(
            value,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
        + "\n"
    ).encode("utf-8")


def _safe_member_name(name: str) -> tuple[PurePosixPath, bool]:
    if not name or "\\" in name or "\x00" in name or name.startswith("/"):
        fail(f"unsafe archive entry {name!r}")
    is_directory = name.endswith("/")
    normalized = name[:-1] if is_directory else name
    path = PurePosixPath(normalized)
    if (
        not normalized
        or path.is_absolute()
        or any(part in ("", ".", "..") for part in path.parts)
    ):
        fail(f"unsafe archive entry {name!r}")
    return path, is_directory


def safe_extract(archive: Path, destination: Path) -> None:
    _regular_size(archive, "release-auth archive", MAX_ARCHIVE_BYTES)
    if destination.exists() or destination.is_symlink():
        fail("archive extraction root already exists")
    try:
        destination.mkdir(mode=0o700)
        with zipfile.ZipFile(archive) as source:
            entries = source.infolist()
            if not entries:
                fail("release-auth archive is empty")
            seen: set[str] = set()
            total = 0
            for entry in entries:
                relative, is_directory = _safe_member_name(entry.filename)
                normalized = relative.as_posix()
                if normalized in seen:
                    fail(f"duplicate archive entry {entry.filename!r}")
                seen.add(normalized)
                if entry.flag_bits & 0x1:
                    fail(f"encrypted archive entry {entry.filename!r}")
                file_type = stat.S_IFMT((entry.external_attr >> 16) & 0xFFFF)
                expected_type = stat.S_IFDIR if is_directory else stat.S_IFREG
                if file_type not in (0, expected_type):
                    fail(f"archive link/special entry {entry.filename!r}")
                if entry.file_size < (0 if is_directory else 1):
                    fail(f"archive entry has invalid size {entry.filename!r}")
                if entry.file_size > MAX_ENTRY_BYTES:
                    fail(f"archive entry is oversized {entry.filename!r}")
                total += entry.file_size
                if total > MAX_ARCHIVE_BYTES:
                    fail("release-auth archive expands beyond the total limit")

                target = destination.joinpath(*relative.parts)
                try:
                    target.relative_to(destination)
                except ValueError:
                    fail(f"archive entry escapes extraction root {entry.filename!r}")
                if is_directory:
                    target.mkdir(parents=True, exist_ok=True)
                    if target.is_symlink() or not target.is_dir():
                        fail(f"archive directory collision {entry.filename!r}")
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                if target.exists() or target.is_symlink():
                    fail(f"archive file collision {entry.filename!r}")
                remaining = entry.file_size
                with source.open(entry, "r") as source_file, target.open("xb") as output:
                    while remaining:
                        chunk = source_file.read(min(1024 * 1024, remaining))
                        if not chunk:
                            fail(f"truncated archive entry {entry.filename!r}")
                        output.write(chunk)
                        remaining -= len(chunk)
                    if source_file.read(1):
                        fail(f"overlong archive entry {entry.filename!r}")
    except BridgeError:
        raise
    except (OSError, zipfile.BadZipFile, RuntimeError) as error:
        fail(f"cannot safely extract release-auth archive: {error}")
    finally:
        # Keep the extraction for byte comparison on success. On an exception,
        # remove only the exact newly-created scratch root.
        if sys.exc_info()[0] is not None and destination.exists():
            shutil.rmtree(destination)


def _tree(root: Path, name: str) -> tuple[list[str], list[str]]:
    try:
        root_info = root.lstat()
    except OSError as error:
        fail(f"{name} root is absent: {error}")
    if not stat.S_ISDIR(root_info.st_mode) or root.is_symlink():
        fail(f"{name} root must be one regular non-link directory")
    directories: list[str] = []
    files: list[str] = []
    for current, directory_names, file_names in os.walk(root, followlinks=False):
        current_path = Path(current)
        for child_name in sorted(directory_names):
            child = current_path / child_name
            info = child.lstat()
            if not stat.S_ISDIR(info.st_mode) or child.is_symlink():
                fail(f"{name} contains a link/special directory")
            directories.append(child.relative_to(root).as_posix())
        for child_name in sorted(file_names):
            child = current_path / child_name
            info = child.lstat()
            if not stat.S_ISREG(info.st_mode) or child.is_symlink():
                fail(f"{name} contains a link/special file")
            if info.st_size < 1 or info.st_size > MAX_ENTRY_BYTES:
                fail(f"{name} file has an invalid bounded size")
            files.append(child.relative_to(root).as_posix())
    return sorted(directories), sorted(files)


def _compare_trees(left: Path, right: Path) -> None:
    left_directories, left_files = _tree(left, "raw archive")
    right_directories, right_files = _tree(right, "action download")
    if left_directories != right_directories or left_files != right_files:
        fail("raw archive and action download layouts differ")
    for relative in left_files:
        left_bytes = _regular_file(left / relative, "raw archive member", MAX_ENTRY_BYTES)
        right_bytes = _regular_file(
            right / relative,
            "action download member",
            MAX_ENTRY_BYTES,
        )
        if left_bytes != right_bytes:
            fail(f"raw archive and action download bytes differ for {relative}")


def _catalog_files(catalog_path: Path) -> list[str]:
    catalog = _json_no_duplicates(
        _regular_file(catalog_path, "visual case catalog", MAX_JSON_BYTES),
        "visual case catalog",
    )
    if not isinstance(catalog, dict) or not isinstance(catalog.get("cases"), list):
        fail("visual case catalog has no cases array")
    result = ["baseline-approval.v1.json", "review-candidate.v1.json"]
    for case in catalog["cases"]:
        if not isinstance(case, dict):
            fail("visual case catalog entry is not an object")
        artifact_path = case.get("artifact_path")
        if type(artifact_path) is not str:
            fail("visual case artifact_path is absent")
        path, is_directory = _safe_member_name(artifact_path)
        if is_directory:
            fail("visual case artifact_path cannot be a directory")
        result.append(path.as_posix())
    if len(result) != len(set(result)):
        fail("visual case catalog contains duplicate artifact paths")
    return sorted(result)


def validate_metadata(
    metadata_path: Path,
    *,
    artifact_id: int,
    artifact_name: str,
    artifact_digest: str,
    run_id: int,
    source_sha: str,
) -> None:
    metadata = _json_no_duplicates(
        _regular_file(metadata_path, "artifact metadata", MAX_JSON_BYTES),
        "artifact metadata",
    )
    if not isinstance(metadata, dict):
        fail("artifact metadata root is not an object")
    if _positive_integer(metadata.get("id"), "artifact metadata id") != artifact_id:
        fail("artifact metadata id mismatch")
    _exact_string(metadata.get("name"), artifact_name, "artifact metadata name")
    _exact_string(
        metadata.get("digest"),
        f"sha256:{artifact_digest}",
        "artifact metadata digest",
    )
    if metadata.get("expired") is not False:
        fail("artifact metadata is expired or ambiguous")
    workflow_run = metadata.get("workflow_run")
    if not isinstance(workflow_run, dict):
        fail("artifact metadata workflow_run is absent")
    if _positive_integer(workflow_run.get("id"), "artifact workflow run id") != run_id:
        fail("artifact workflow run id mismatch")
    _exact_string(workflow_run.get("head_sha"), source_sha, "artifact head SHA")
    _exact_string(workflow_run.get("head_branch"), "main", "artifact head branch")


def validate_auth(
    root: Path,
    *,
    catalog_path: Path,
    release_id: str,
    source_sha: str,
    producer_run_id: int,
    candidate_run_id: int,
    candidate_run_attempt: int,
    candidate_artifact_id: int,
    candidate_spec_sha256: str,
    baseline_run_id: int,
    baseline_run_attempt: int,
    baseline_artifact_id: int,
) -> None:
    _, actual_files = _tree(root, "release-auth action download")
    baseline_files = _catalog_files(catalog_path)
    expected_files = sorted(
        ["auth.json", "candidate/candidate-spec.json"]
        + [f"baseline/{path}" for path in baseline_files]
    )
    if actual_files != expected_files:
        fail("release-auth file allowlist mismatch")

    auth_bytes = _regular_file(root / "auth.json", "auth.json", MAX_JSON_BYTES)
    auth = _json_no_duplicates(auth_bytes, "auth.json")
    if auth_bytes != _canonical_json(auth):
        fail("auth.json is not canonical sorted compact JSON")
    auth_object = _exact_keys(
        auth,
        [
            "baseline",
            "candidate",
            "frontend_source_sha",
            "producer_run_attempt",
            "producer_run_id",
            "release_id",
            "schema_version",
        ],
        "auth.json",
    )
    _exact_string(auth_object["schema_version"], "leva.et13.release-auth.v1", "schema")
    _exact_string(auth_object["release_id"], release_id, "release_id")
    _exact_string(auth_object["frontend_source_sha"], source_sha, "frontend source")
    if _positive_integer(auth_object["producer_run_id"], "producer_run_id") != producer_run_id:
        fail("producer_run_id mismatch")
    if _positive_integer(auth_object["producer_run_attempt"], "producer_run_attempt") != 1:
        fail("producer_run_attempt must be exactly 1")

    candidate = _exact_keys(
        auth_object["candidate"],
        [
            "artifact_archive_sha256",
            "artifact_id",
            "artifact_name",
            "base_sha",
            "head_branch",
            "head_sha",
            "run_attempt",
            "run_id",
            "source_path",
            "spec_sha256",
            "workflow_sha256",
        ],
        "candidate",
    )
    if _positive_integer(candidate["run_id"], "candidate.run_id") != candidate_run_id:
        fail("candidate.run_id mismatch")
    if _positive_integer(candidate["run_attempt"], "candidate.run_attempt") != candidate_run_attempt or candidate_run_attempt != 1:
        fail("candidate.run_attempt mismatch")
    if _positive_integer(candidate["artifact_id"], "candidate.artifact_id") != candidate_artifact_id:
        fail("candidate.artifact_id mismatch")
    _exact_string(candidate["spec_sha256"], candidate_spec_sha256, "candidate spec SHA")
    _pattern(candidate["artifact_archive_sha256"], SHA256, "candidate archive SHA")
    _pattern(candidate["workflow_sha256"], SHA256, "candidate workflow SHA")
    _pattern(candidate["head_sha"], SHA1, "candidate head SHA")
    _pattern(candidate["base_sha"], SHA1, "candidate base SHA")
    _pattern(candidate["artifact_name"], SAFE_NAME, "candidate artifact name")
    _exact_string(
        candidate["source_path"],
        f"release-manifests/candidates/{release_id}.candidate-spec.json",
        "candidate source path",
    )
    if type(candidate["head_branch"]) is not str or candidate["head_branch"] == "main":
        fail("candidate head branch is absent or points at main")

    baseline = _exact_keys(
        auth_object["baseline"],
        [
            "artifact_archive_sha256",
            "artifact_id",
            "artifact_name",
            "head_branch",
            "head_sha",
            "run_attempt",
            "run_id",
            "workflow_sha256",
        ],
        "baseline",
    )
    if _positive_integer(baseline["run_id"], "baseline.run_id") != baseline_run_id:
        fail("baseline.run_id mismatch")
    if _positive_integer(baseline["run_attempt"], "baseline.run_attempt") != baseline_run_attempt or baseline_run_attempt != 1:
        fail("baseline.run_attempt mismatch")
    if _positive_integer(baseline["artifact_id"], "baseline.artifact_id") != baseline_artifact_id:
        fail("baseline.artifact_id mismatch")
    _pattern(baseline["artifact_archive_sha256"], SHA256, "baseline archive SHA")
    _pattern(baseline["workflow_sha256"], SHA256, "baseline workflow SHA")
    _pattern(baseline["head_sha"], SHA1, "baseline head SHA")
    _pattern(baseline["artifact_name"], SAFE_NAME, "baseline artifact name")
    _exact_string(baseline["head_branch"], "main", "baseline head branch")

    candidate_bytes = _regular_file(
        root / "candidate" / "candidate-spec.json",
        "candidate spec",
        MAX_JSON_BYTES,
    )
    if hashlib.sha256(candidate_bytes).hexdigest() != candidate_spec_sha256:
        fail("candidate spec raw SHA-256 mismatch")


def verify_bridge(args: argparse.Namespace) -> None:
    if RELEASE_ID.fullmatch(args.release_id) is None:
        fail("release-id is unsafe")
    for name in ("source_sha",):
        if SHA1.fullmatch(getattr(args, name)) is None:
            fail(f"{name} is not a nonzero Git SHA")
    if SHA256.fullmatch(args.artifact_digest) is None:
        fail("artifact digest is not SHA-256")
    if SHA256.fullmatch(args.candidate_spec_sha256) is None:
        fail("candidate spec digest is not SHA-256")
    if SAFE_NAME.fullmatch(args.artifact_name) is None:
        fail("artifact name is unsafe")
    for name in (
        "artifact_id",
        "producer_run_id",
        "candidate_run_id",
        "candidate_run_attempt",
        "candidate_artifact_id",
        "baseline_run_id",
        "baseline_run_attempt",
        "baseline_artifact_id",
    ):
        _positive_integer(getattr(args, name), name)

    archive = Path(args.archive).resolve(strict=False)
    scratch_root = Path(args.scratch_root).resolve(strict=False)
    action_root = Path(args.action_root).resolve(strict=False)
    metadata = Path(args.metadata).resolve(strict=False)
    catalog = Path(args.catalog).resolve(strict=False)
    if _file_sha256(
        archive,
        "release-auth archive",
        MAX_ARCHIVE_BYTES,
    ) != args.artifact_digest:
        fail("release-auth archive SHA-256 mismatch")
    validate_metadata(
        metadata,
        artifact_id=args.artifact_id,
        artifact_name=args.artifact_name,
        artifact_digest=args.artifact_digest,
        run_id=args.producer_run_id,
        source_sha=args.source_sha,
    )
    safe_extract(archive, scratch_root)
    _compare_trees(scratch_root, action_root)
    validate_auth(
        action_root,
        catalog_path=catalog,
        release_id=args.release_id,
        source_sha=args.source_sha,
        producer_run_id=args.producer_run_id,
        candidate_run_id=args.candidate_run_id,
        candidate_run_attempt=args.candidate_run_attempt,
        candidate_artifact_id=args.candidate_artifact_id,
        candidate_spec_sha256=args.candidate_spec_sha256,
        baseline_run_id=args.baseline_run_id,
        baseline_run_attempt=args.baseline_run_attempt,
        baseline_artifact_id=args.baseline_artifact_id,
    )


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(allow_abbrev=False)
    for name in (
        "archive",
        "scratch-root",
        "action-root",
        "metadata",
        "catalog",
        "artifact-name",
        "artifact-digest",
        "release-id",
        "source-sha",
        "candidate-spec-sha256",
    ):
        result.add_argument(f"--{name}", required=True)
    for name in (
        "artifact-id",
        "producer-run-id",
        "candidate-run-id",
        "candidate-run-attempt",
        "candidate-artifact-id",
        "baseline-run-id",
        "baseline-run-attempt",
        "baseline-artifact-id",
    ):
        result.add_argument(f"--{name}", required=True, type=int)
    return result


def main() -> int:
    try:
        verify_bridge(parser().parse_args())
    except BridgeError as error:
        print(str(error), file=sys.stderr)
        return 1
    print("ET13 release-auth bridge: authenticated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
