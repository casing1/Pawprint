#!/usr/bin/env python3
"""Static checks on the GitHub workflows, so their mistakes surface locally.

Three releases in a row failed on workflow errors rather than on the code: a public key grepped
from a path that had moved, and a `$VERSION` used in a step that never declared it. Each cost a
full build to discover. These are the rules that would have caught them.

Run it directly, or let CI do it.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
WORKFLOWS = sorted((ROOT / ".github/workflows").glob("*.yml"))

failures: list[str] = []


def fail(workflow: pathlib.Path, message: str) -> None:
    failures.append(f"{workflow.name}: {message}")


def steps(text: str) -> list[str]:
    """Splits a workflow into step blocks. Crude, but the shape of these files is regular."""
    return re.split(r"\n      - (?=name:|uses:)", text)


def run_body(step: str) -> str:
    """The shell of a step, or empty if it has none."""
    match = re.search(r"run: [|>]?\n((?:\s{10,}.*\n?)+)", step)
    return match.group(1) if match else ""


for workflow in WORKFLOWS:
    text = workflow.read_text()
    # A job-level `env:` covers every step in that job. Read by indentation rather than by a
    # single pattern, because a comment line inside the block would otherwise end it early.
    job_vars: set[str] = set()
    lines = text.split("\n")
    for i, line in enumerate(lines):
        if line != "    env:":
            continue
        for entry in lines[i + 1:]:
            if entry.strip() and not entry.startswith("      "):
                break
            if match := re.match(r"      (\w+):", entry):
                job_vars.add(match.group(1))

    for step in steps(text):
        header = step.split("\n", 1)[0].strip()[:60]
        body = run_body(step)
        if not body:
            continue
        declared = step[: step.index("run:")] if "run:" in step else ""

        # 1. A GitHub expression must never reach a shell. This is the injection rule.
        for expression in re.findall(r"\$\{\{[^}]+\}\}", body):
            fail(workflow, f"step '{header}' interpolates {expression.strip()} into its shell; "
                           "pass it through env: and quote it")

        # 2. Every variable the shell reads must be declared, assigned in the same body, or one
        #    the runner provides. This is the one that shipped an empty version into a filename.
        provided = {
            "GITHUB_OUTPUT", "GITHUB_ENV", "GITHUB_PATH", "GITHUB_WORKSPACE", "GITHUB_SHA",
            "GITHUB_REF", "GITHUB_REF_NAME", "GITHUB_REPOSITORY", "GITHUB_RUN_NUMBER",
            "RUNNER_TEMP", "RUNNER_OS", "HOME", "PATH", "TMPDIR", "BASH_SOURCE",
        }
        assigned = set(re.findall(r"^\s*([A-Z][A-Z0-9_]*)=", body, re.M))
        assigned |= set(re.findall(r"for ([A-Za-z_][A-Za-z0-9_]*) in ", body))
        for name in set(re.findall(r"\$\{?([A-Z][A-Z0-9_]{2,})\b", body)):
            if name in provided or name in assigned:
                continue
            if name in job_vars or re.search(rf"^\s*{name}:", declared, re.M):
                continue
            fail(workflow, f"step '{header}' reads ${name}, which nothing declares or assigns")

        # 3. A shell that stops at the first error, so a failed step is a failed step.
        if "set -euo pipefail" not in body and body.count("\n") > 2:
            fail(workflow, f"step '{header}' has a multi-line shell without `set -euo pipefail`")

    # 4. Least privilege, stated rather than inherited.
    if not re.search(r"^permissions:", text, re.M):
        fail(workflow, "no top-level `permissions:` block")

if failures:
    print("WORKFLOW CHECK FAILED\n")
    for line in failures:
        print(f"  {line}")
    sys.exit(1)

print(f"WORKFLOW CHECK OK — {len(WORKFLOWS)} workflows")
