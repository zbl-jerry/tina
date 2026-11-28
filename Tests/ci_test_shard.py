#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Vorssaint

"""Transfer one run's test executable and partition its complete default suite list."""

import argparse
import io
import json
import platform
import re
import shutil
import subprocess
import tarfile
from pathlib import Path

BINARY = Path("build/metrics-tests")
# Rounded seconds from recent macOS CI. Unknown suites still run, with a
# small default weight until new timings warrant an explicit estimate.
WEIGHTS = {
    "recorder": 115, "notch": 101, "agents": 63,
    "screenshots": 35, "settings": 35, "feature-hub-layout": 32,
    "switcher": 23, "dock-autohide": 15, "features": 13, "repository": 11,
    "homebrew-filter": 7, "utilities": 6, "keep-awake": 5,
    "clipboard": 4, "mixer": 4, "updates": 4, "command-bar": 3, "transient-paste": 3,
}


def output(*command):
    return subprocess.check_output(command, text=True).strip()


def build_identity():
    return {
        "commit": output("git", "rev-parse", "HEAD"),
        "architecture": platform.machine(),
        # Omit the host Target line; the binary explicitly targets arm64 macOS 14.
        "swift": output("swiftc", "--version").splitlines()[0],
        "xcode": output("xcodebuild", "-version"),
        "sdk": output("xcrun", "--sdk", "macosx", "--show-sdk-build-version"),
    }


def pack(path):
    identity = json.dumps(build_identity(), sort_keys=True).encode()
    metadata = tarfile.TarInfo("identity.json")
    metadata.size = len(identity)
    with tarfile.open(path, "w:gz", compresslevel=1) as archive:
        archive.addfile(metadata, io.BytesIO(identity))
        archive.add(BINARY, arcname="metrics-tests", recursive=False)


def restore(path):
    with tarfile.open(path, "r:gz") as archive:
        entries = archive.getmembers()
        if sorted(entry.name for entry in entries) != ["identity.json", "metrics-tests"] or not all(
            entry.isfile() for entry in entries
        ):
            raise ValueError("unexpected entries in the test artifact")
        with archive.extractfile("identity.json") as metadata:
            if json.load(metadata) != build_identity():
                raise ValueError("test artifact does not match this checkout or toolchain")
        BINARY.parent.mkdir(parents=True, exist_ok=True)
        with archive.extractfile("metrics-tests") as test_file, BINARY.open("wb") as binary:
            shutil.copyfileobj(test_file, binary)
        BINARY.chmod(0o755)


def partition(suites):
    if len(suites) < 2 or len(suites) != len(set(suites)) or not all(
        re.fullmatch(r"[a-z0-9][a-z0-9-]*", suite) for suite in suites
    ):
        raise ValueError("invalid default suite list from test executable")

    assignment = {}
    loads = [0, 0]
    for suite in sorted(suites, key=lambda name: (-WEIGHTS.get(name, 1), name)):
        shard = 0 if loads[0] <= loads[1] else 1
        assignment[suite] = shard
        loads[shard] += WEIGHTS.get(suite, 1)
    # Preserve the original relative execution order inside each shard.
    return [[suite for suite in suites if assignment[suite] == shard] for shard in range(2)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subcommands = parser.add_subparsers(dest="command", required=True)
    pack_parser = subcommands.add_parser("pack")
    pack_parser.add_argument("archive", type=Path)
    run_parser = subcommands.add_parser("run")
    run_parser.add_argument("archive", type=Path)
    run_parser.add_argument("shard", type=int, choices=(1, 2))
    args = parser.parse_args()

    if args.command == "pack":
        pack(args.archive)
        return 0
    restore(args.archive)
    suites = partition(output(str(BINARY), "--list-default").splitlines())[args.shard - 1]
    print(f"Test shard {args.shard}/2 ({len(suites)} suites): {', '.join(suites)}", flush=True)
    return subprocess.call(["./build.sh", "--test-run-only", *(f"--test-suite={suite}" for suite in suites)])


if __name__ == "__main__":
    raise SystemExit(main())
