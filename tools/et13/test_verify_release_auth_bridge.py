from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest import mock
import warnings
import zipfile

MODULE_PATH = Path(__file__).with_name("verify_release_auth_bridge.py")
SPEC = importlib.util.spec_from_file_location("verify_release_auth_bridge", MODULE_PATH)
if SPEC is None or SPEC.loader is None:  # pragma: no cover
    raise RuntimeError("cannot load verify_release_auth_bridge.py")
bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bridge)


RELEASE_ID = "ms-20260817-et13"
SOURCE_SHA = "1234567890abcdef1234567890abcdef12345678"
CANDIDATE_SHA = "abcdef1234567890abcdef1234567890abcdef12"
BASE_SHA = "fedcba0987654321fedcba0987654321fedcba09"
WORKFLOW_SHA = "a" * 64
ARCHIVE_SHA = "b" * 64


def canonical(value: object) -> bytes:
    return (
        json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
        + "\n"
    ).encode()


def auth_payload(candidate_digest: str) -> dict[str, object]:
    return {
        "baseline": {
            "artifact_archive_sha256": ARCHIVE_SHA,
            "artifact_id": 404,
            "artifact_name": "approved-baseline",
            "head_branch": "main",
            "head_sha": SOURCE_SHA,
            "run_attempt": 1,
            "run_id": 303,
            "workflow_sha256": WORKFLOW_SHA,
        },
        "candidate": {
            "artifact_archive_sha256": ARCHIVE_SHA,
            "artifact_id": 202,
            "artifact_name": "candidate-spec",
            "base_sha": BASE_SHA,
            "head_branch": f"release/candidate-{RELEASE_ID}",
            "head_sha": CANDIDATE_SHA,
            "run_attempt": 1,
            "run_id": 101,
            "source_path": (
                f"release-manifests/candidates/{RELEASE_ID}.candidate-spec.json"
            ),
            "spec_sha256": candidate_digest,
            "workflow_sha256": WORKFLOW_SHA,
        },
        "frontend_source_sha": SOURCE_SHA,
        "producer_run_attempt": 1,
        "producer_run_id": 505,
        "release_id": RELEASE_ID,
        "schema_version": "leva.et13.release-auth.v1",
    }


class Fixture:
    def __init__(self, root: Path, mutate_auth=None, mutate_action=None):
        self.root = root
        self.action = root / "action"
        self.action.mkdir()
        candidate = b'{"release_id":"ms-20260817-et13"}\n'
        candidate_digest = hashlib.sha256(candidate).hexdigest()
        files = {
            "candidate/candidate-spec.json": candidate,
            "baseline/baseline-approval.v1.json": b"{}\n",
            "baseline/review-candidate.v1.json": b"{}\n",
            "baseline/screens/case.png": b"png-bytes",
        }
        payload = auth_payload(candidate_digest)
        if mutate_auth:
            mutate_auth(payload)
        files["auth.json"] = canonical(payload)
        for relative, contents in files.items():
            target = self.action / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(contents)
        if mutate_action:
            mutate_action(self.action)

        self.catalog = root / "catalog.json"
        self.catalog.write_bytes(
            canonical({"cases": [{"artifact_path": "screens/case.png"}]})
        )
        self.archive = root / "auth.zip"
        with zipfile.ZipFile(self.archive, "w", zipfile.ZIP_DEFLATED) as output:
            for path in sorted(self.action.rglob("*")):
                if path.is_file():
                    output.write(path, path.relative_to(self.action).as_posix())
        self.digest = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        self.metadata = root / "metadata.json"
        self.metadata.write_bytes(
            canonical(
                {
                    "digest": f"sha256:{self.digest}",
                    "expired": False,
                    "id": 606,
                    "name": (
                        f"et13-release-auth-{RELEASE_ID}-run-505-attempt-1"
                    ),
                    "workflow_run": {
                        "head_branch": "main",
                        "head_sha": SOURCE_SHA,
                        "id": 505,
                    },
                }
            )
        )
        self.scratch = root / "scratch"
        self.args = argparse.Namespace(
            archive=str(self.archive),
            scratch_root=str(self.scratch),
            action_root=str(self.action),
            metadata=str(self.metadata),
            catalog=str(self.catalog),
            artifact_id=606,
            artifact_name=f"et13-release-auth-{RELEASE_ID}-run-505-attempt-1",
            artifact_digest=self.digest,
            release_id=RELEASE_ID,
            source_sha=SOURCE_SHA,
            producer_run_id=505,
            candidate_run_id=101,
            candidate_run_attempt=1,
            candidate_artifact_id=202,
            candidate_spec_sha256=candidate_digest,
            baseline_run_id=303,
            baseline_run_attempt=1,
            baseline_artifact_id=404,
        )


class ReleaseAuthBridgeTest(unittest.TestCase):
    def fixture(self, mutate_auth=None, mutate_action=None) -> Fixture:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        return Fixture(Path(temporary.name), mutate_auth, mutate_action)

    def test_valid_bridge_binds_metadata_archive_schema_and_files(self) -> None:
        fixture = self.fixture()
        bridge.verify_bridge(fixture.args)
        self.assertTrue(fixture.scratch.is_dir())

    def test_metadata_identity_and_archive_digest_drift_fail(self) -> None:
        for mutate in (
            lambda fixture: setattr(fixture.args, "artifact_id", 607),
            lambda fixture: setattr(fixture.args, "producer_run_id", 506),
            lambda fixture: setattr(fixture.args, "source_sha", CANDIDATE_SHA),
            lambda fixture: setattr(fixture.args, "artifact_digest", "c" * 64),
        ):
            with self.subTest(mutate=mutate):
                fixture = self.fixture()
                mutate(fixture)
                with self.assertRaises(bridge.BridgeError):
                    bridge.verify_bridge(fixture.args)

    def test_auth_extra_keys_types_values_and_noncanonical_bytes_fail(self) -> None:
        mutations = (
            lambda payload: payload.update({"generated_at": "now"}),
            lambda payload: payload.update({"producer_run_id": True}),
            lambda payload: payload["candidate"].update({"run_attempt": 1.0}),
            lambda payload: payload["candidate"].update({"head_branch": "main"}),
            lambda payload: payload["baseline"].update({"head_branch": "develop"}),
        )
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                fixture = self.fixture(mutate_auth=mutate)
                with self.assertRaises(bridge.BridgeError):
                    bridge.verify_bridge(fixture.args)

        fixture = self.fixture()
        value = json.loads((fixture.action / "auth.json").read_text())
        (fixture.action / "auth.json").write_text(json.dumps(value, indent=2) + "\n")
        with self.assertRaises(bridge.BridgeError):
            bridge.validate_auth(
                fixture.action,
                catalog_path=fixture.catalog,
                release_id=RELEASE_ID,
                source_sha=SOURCE_SHA,
                producer_run_id=505,
                candidate_run_id=101,
                candidate_run_attempt=1,
                candidate_artifact_id=202,
                candidate_spec_sha256=fixture.args.candidate_spec_sha256,
                baseline_run_id=303,
                baseline_run_attempt=1,
                baseline_artifact_id=404,
            )

    def test_duplicate_auth_key_fails(self) -> None:
        fixture = self.fixture()
        auth = fixture.action / "auth.json"
        auth.write_text(
            '{"schema_version":"leva.et13.release-auth.v1",'
            '"schema_version":"duplicate"}\n'
        )
        with self.assertRaises(bridge.BridgeError):
            bridge.validate_auth(
                fixture.action,
                catalog_path=fixture.catalog,
                release_id=RELEASE_ID,
                source_sha=SOURCE_SHA,
                producer_run_id=505,
                candidate_run_id=101,
                candidate_run_attempt=1,
                candidate_artifact_id=202,
                candidate_spec_sha256=fixture.args.candidate_spec_sha256,
                baseline_run_id=303,
                baseline_run_attempt=1,
                baseline_artifact_id=404,
            )

    def test_raw_archive_and_action_download_byte_drift_fails(self) -> None:
        fixture = self.fixture()
        (fixture.action / "baseline/screens/case.png").write_bytes(b"drift")
        with self.assertRaises(bridge.BridgeError):
            bridge.verify_bridge(fixture.args)

    def test_exact_file_allowlist_rejects_extras(self) -> None:
        fixture = self.fixture(
            mutate_action=lambda root: (root / "token.txt").write_text("secret")
        )
        with self.assertRaises(bridge.BridgeError):
            bridge.verify_bridge(fixture.args)

    def test_archive_rejects_traversal_link_duplicate_and_oversize(self) -> None:
        cases = []
        for name in ("../escape", "/absolute", "safe/../../escape"):
            cases.append(lambda output, name=name: output.writestr(name, b"evil"))

        def symlink(output: zipfile.ZipFile) -> None:
            info = zipfile.ZipInfo("link")
            info.external_attr = (stat.S_IFLNK | 0o777) << 16
            output.writestr(info, b"target")

        def duplicate(output: zipfile.ZipFile) -> None:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                output.writestr("same", b"one")
                output.writestr("same", b"two")

        cases.extend((symlink, duplicate))
        for writer in cases:
            with self.subTest(writer=writer):
                temporary = tempfile.TemporaryDirectory()
                self.addCleanup(temporary.cleanup)
                root = Path(temporary.name)
                archive = root / "bad.zip"
                with zipfile.ZipFile(archive, "w") as output:
                    writer(output)
                with self.assertRaises(bridge.BridgeError):
                    bridge.safe_extract(archive, root / "out")

        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        archive = root / "large.zip"
        with zipfile.ZipFile(archive, "w") as output:
            output.writestr("large", b"xx")
        with mock.patch.object(bridge, "MAX_ENTRY_BYTES", 1):
            with self.assertRaises(bridge.BridgeError):
                bridge.safe_extract(archive, root / "out")


if __name__ == "__main__":
    unittest.main()
