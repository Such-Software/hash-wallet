import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


def load_script(name):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).with_name(f"{name}.py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


release = load_script("desktop-release")
publisher = load_script("publish-desktop-asset")


class DesktopReleaseTests(unittest.TestCase):
    def test_lookup_finds_draft_on_later_github_page(self):
        draft = {"tag_name": "target", "draft": True}
        paginated_output = json.dumps([{"tag_name": "previous"}]) + json.dumps([draft])
        with patch.object(release, "command", return_value=paginated_output):
            self.assertEqual(release.release_for("target"), draft)

    def test_staging_creates_draft_before_pushing_the_builds_tag(self):
        commit = "a" * 40
        tag = "hash-bags-1.2.3-build4"
        draft = {"draft": True, "html_url": "https://example.invalid/draft"}
        with (
            patch.object(release, "has_release_driver", return_value=True),
            patch.object(release, "release_for", return_value=draft),
            patch.object(release, "remote_tag", return_value=commit),
            patch.object(release.subprocess, "run") as run,
            contextlib.redirect_stdout(io.StringIO()),
        ):
            release.stage(commit, tag, "1.2.3", f"refs/tags/{tag}", None, None, None)
        actions = [call.args[0] for call in run.call_args_list]
        self.assertEqual([action[0] for action in actions], ["git", "gh", "git"])
        self.assertIn("--draft", actions[1])
        self.assertIn("origin", actions[0])
        self.assertIn("gitea-builds", actions[2])

    def test_verification_refuses_a_missing_desktop_asset(self):
        with self.assertRaisesRegex(ValueError, "AppImage"):
            release.verify_assets({"assets": []}, ["Hash_Bags-x86_64.AppImage"])


class DesktopPublisherTests(unittest.TestCase):
    def test_tag_build_refuses_public_release(self):
        with tempfile.TemporaryDirectory() as directory:
            artifact = Path(directory) / "desktop.zip"
            artifact.write_bytes(b"fixture")
            with (
                patch.dict(publisher.os.environ, {"GITHUB_EVENT_NAME": "push"}),
                patch.object(publisher, "find_release", return_value={"draft": False}),
                patch.object(publisher, "verify_tag"),
                patch.object(publisher, "request") as request,
                self.assertRaisesRegex(ValueError, "draft release"),
            ):
                publisher.publish("target", artifact)
            request.assert_not_called()

    def test_retry_accepts_identical_asset_and_refuses_replacement(self):
        with tempfile.TemporaryDirectory() as directory:
            artifact = Path(directory) / "desktop.zip"
            artifact.write_bytes(b"fixture")
            digest = "sha256:" + hashlib.sha256(artifact.read_bytes()).hexdigest()
            asset = {"name": artifact.name, "state": "uploaded", "digest": digest}
            draft = {"draft": True, "assets": [asset]}
            with (
                patch.dict(publisher.os.environ, {"GITHUB_EVENT_NAME": "workflow_dispatch"}),
                patch.object(publisher, "find_release", return_value=draft),
                patch.object(publisher, "request") as request,
                contextlib.redirect_stdout(io.StringIO()),
            ):
                publisher.publish("target", artifact)
                artifact.write_bytes(b"different fixture")
                with self.assertRaisesRegex(ValueError, "different or incomplete asset"):
                    publisher.publish("target", artifact)
            request.assert_not_called()


if __name__ == "__main__":
    unittest.main()
