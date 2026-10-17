"""Cloud-free tests of the import helper's command boundary (Python 3 + Bash)."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[2]
BASH = os.environ.get("BASH_BIN") or shutil.which("bash")
DRIVER = r'''
import json, os, sys
from pathlib import Path
tool = Path(sys.argv[1]).name
args = sys.argv[2:]
with open(os.environ["CALL_LOG"], "a", encoding="utf-8") as log:
    log.write(json.dumps({"tool": tool, "args": args, "cwd": os.getcwd()}) + "\n")
if tool == "terragrunt" and args == ["render", "--json"]:
    if os.environ.get("FAIL_RENDER") == "1":
        sys.exit(7)
    print(Path(os.environ["RENDERED_CONFIG"]).read_text(encoding="utf-8"))
elif ("import" in args) and os.environ.get("FAIL_IMPORT") == "1":
    sys.exit(9)
'''

@unittest.skipUnless(BASH, "Bash is required")
class ImportHelperTests(unittest.TestCase):
    def run_helper(self, inputs=None, **flags):
        with tempfile.TemporaryDirectory(prefix="gcp-import-") as directory:
            temp = Path(directory)
            tools = temp / "bin"
            tools.mkdir()
            log = temp / "calls.jsonl"
            driver = temp / "record.py"
            driver.write_text(DRIVER, encoding="utf-8")
            rendered = temp / "rendered.json"
            rendered.write_text(json.dumps({"inputs": inputs if inputs is not None else {
                "project_id": "test-project-123", "region": "us-central1", "zone": "us-central1-a"
            }}), encoding="utf-8")
            for tool in ("terragrunt", "terraform"):
                command = tools / tool
                command.write_text('#!/usr/bin/env bash\nexec python3 "$TEST_DRIVER" "$0" "$@"\n',
                                   encoding="utf-8", newline="\n")
                command.chmod(0o755)
            # Git Bash on Windows may not provide python3; use this test interpreter.
            if os.name == "nt":
                interpreter = sys.executable.replace("\\", "/")
                (tools / "python3").write_text(
                    '#!/usr/bin/env bash\nexec "' + interpreter + '" "$@"\n',
                    encoding="utf-8", newline="\n")
            env = os.environ.copy()
            for name in ("TF_VAR_project_id", "TF_VAR_region", "TF_VAR_zone",
                         "TF_CLI_ARGS", "TF_CLI_ARGS_init", "TF_CLI_ARGS_import", "TF_CLI_ARGS_plan"):
                env.pop(name, None)
            env.update({
                "PATH": str(tools) + os.pathsep + env["PATH"],
                "TEST_DRIVER": str(driver), "CALL_LOG": str(log),
                "RENDERED_CONFIG": str(rendered),
            })
            env.update(flags)
            result = subprocess.run(
                [BASH, str(REPO / "gcp" / "import-existing.sh").replace("\\", "/")],
                cwd=temp, env=env, text=True, capture_output=True, timeout=30,
            )
            calls = [json.loads(line) for line in log.read_text(encoding="utf-8").splitlines()] if log.exists() else []
            return result, calls

    def test_all_imports_use_dr_inputs_and_canonical_directory(self):
        result, calls = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls[0]["args"], ["render", "--json"])
        self.assertTrue(all(call["tool"] == "terragrunt" for call in calls))
        imports = [call for call in calls if call["args"][:3] == ["run", "--", "import"]]
        self.assertEqual(len(imports), 17)
        self.assertEqual(len({call["args"][3] for call in imports}), 17)
        self.assertNotIn("google_compute_subnetwork.admin", {call["args"][3] for call in imports})
        ids = {call["args"][3]: call["args"][4] for call in imports}
        self.assertTrue(all("test-project-123" in identity for identity in ids.values()))
        self.assertTrue(all("kdt4-3" not in identity and "asia-northeast3" not in identity for identity in ids.values()))
        self.assertEqual(ids["google_compute_subnetwork.gke"],
                         "projects/test-project-123/regions/us-central1/subnetworks/retail-dr-gke-subnet")
        self.assertEqual(ids["google_container_node_pool.retail"],
                         "test-project-123/us-central1-a/retail-dr-gke/retail-dr-pool")
        self.assertEqual(ids["google_project_iam_member.ops"],
                         "test-project-123 roles/container.developer serviceAccount:retail-dr-ops@test-project-123.iam.gserviceaccount.com")
        self.assertEqual(calls[-1]["args"], ["run", "--", "plan"])
        for call in calls:
            self.assertEqual(Path(call["cwd"]).resolve(), (REPO / "live/gcp/dr").resolve())

    def test_render_failure_stops_before_state_writes(self):
        result, calls = self.run_helper(FAIL_RENDER="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0]["args"], ["render", "--json"])

    def test_missing_input_stops_before_state_writes(self):
        result, calls = self.run_helper(inputs={"project_id": "test-project-123"})
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(calls), 1)

    def test_invalid_input_stops_before_state_writes(self):
        result, calls = self.run_helper(inputs={
            "project_id": "test-project-123", "region": "us-central1", "zone": "bad\nvalue"
        })
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(calls), 1)

    def test_import_failure_stops_remaining_imports_and_plan(self):
        result, calls = self.run_helper(FAIL_IMPORT="1")
        self.assertNotEqual(result.returncode, 0)
        imports = [call for call in calls if "import" in call["args"]]
        self.assertEqual(len(imports), 1)
        self.assertFalse(any("plan" in call["args"] for call in calls))

    def test_conflicting_identity_override_stops_before_state_writes(self):
        for key, value in (("TF_VAR_project_id", "other-project-456"),
                           ("TF_VAR_region", "europe-west1"),
                           ("TF_VAR_zone", "europe-west1-b")):
            with self.subTest(key=key):
                result, calls = self.run_helper(**{key: value})
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(len(calls), 1)

    def test_injected_cli_arguments_stop_before_state_writes(self):
        for key in ("TF_CLI_ARGS", "TF_CLI_ARGS_init", "TF_CLI_ARGS_import", "TF_CLI_ARGS_plan"):
            with self.subTest(key=key):
                result, calls = self.run_helper(**{key: "-var=project_id=other-project-456"})
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(len(calls), 1)

if __name__ == "__main__":
    unittest.main()
