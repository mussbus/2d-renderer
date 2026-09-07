"""Check Git/index and checkout bytes through the existing repository audit."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
LF_EXTENSIONS = {".zig", ".zon", ".ps1", ".py", ".hlsl", ".json", ".md", ".txt", ".tsv", ".obj"}
BINARY_EXTENSIONS = {".png", ".ppm", ".zip"}
INDEX_BLOBS = {}


def git(*args, data=None):
    # Ownership permission is local to this process; conversion config is untouched.
    return subprocess.run(
        ["git", "-c", "safe.directory=" + ROOT.as_posix(), "-C", str(ROOT), *args],
        input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        check=True, env=dict(os.environ, GIT_OPTIONAL_LOCKS="0"),
    ).stdout


def blob(path):
    if path not in INDEX_BLOBS:
        INDEX_BLOBS[path] = git("show", ":" + path)
    return INDEX_BLOBS[path]


def preload_blobs(paths):
    # One Git process avoids hundreds of Windows process starts. Read each
    # binary payload by its declared length, never through text conversion.
    with subprocess.Popen(
        ["git", "-c", "safe.directory=" + ROOT.as_posix(), "-C", str(ROOT), "cat-file", "--batch"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        env=dict(os.environ, GIT_OPTIONAL_LOCKS="0"),
    ) as process:
        for path in paths:
            process.stdin.write((":" + path + "\n").encode("utf-8"))
            process.stdin.flush()
            header = process.stdout.readline().split()
            if len(header) != 3 or header[1] != b"blob":
                raise ValueError("Cannot read indexed blob: " + path)
            size = int(header[2])
            raw = process.stdout.read(size)
            if len(raw) != size or process.stdout.read(1) != b"\n":
                raise ValueError("Incomplete indexed blob: " + path)
            INDEX_BLOBS[path] = raw
        process.stdin.close()
        if process.wait() != 0:
            raise ValueError(process.stderr.read().decode("utf-8", errors="replace"))


def exact_document_hashes():
    # Consume the existing tables without copying or changing their authority.
    source = blob("tools/check_documentation.ps1").decode("utf-8")
    result = {}
    for kind, folder, count in (
        ("Prompt", "docs/history/prompts/exact", 12),
        ("Report", "docs/history/reports/prompt-implementation-reports/exact", 8),
    ):
        block = re.search(r"\$exact" + kind + r"Hashes = \[ordered\]@\{(.*?)\n\}", source, re.S)
        if block is None:
            raise ValueError("Missing existing exact " + kind + " hash table")
        pairs = re.findall(r"'([^']+)' = '([a-f0-9]{64})'", block[1])
        if len(pairs) != count or len(dict(pairs)) != count:
            raise ValueError("Invalid existing exact " + kind + " hash table")
        result.update({folder + "/" + name: value for name, value in pairs})
    return result


def check(index_only=False):
    files = git("ls-files", "-z").decode("utf-8").rstrip("\0").split("\0")
    path_input = ("\0".join(files) + "\0").encode("utf-8")
    modes = ["--cached"] if index_only else ["--cached", None]
    classifications = []
    for mode in modes:
        args = ["check-attr", "-z", "--stdin", "text", "eol"]
        if mode:
            args.insert(1, mode)
        output = git(*args, data=path_input).decode("utf-8").rstrip("\0").split("\0")
        attrs = {}
        for path, name, value in zip(output[::3], output[1::3], output[2::3]):
            attrs.setdefault(path, {})[name] = value
        classifications.append(attrs)

    manifest = json.loads(blob("assets/history/manifest.json"))
    decision = manifest["raw_byte_integrity"]["owner_established_authorities"]
    entries = decision["entries"]
    if (decision["decision_date"] != "2026-09-06"
            or decision["baseline"] != "d71c4ae439d0b04019734cd3f45b7a6366a6a00f"
            or len(entries) != 10 or len({entry["path"] for entry in entries}) != 10):
        raise ValueError("The bounded ten-file owner authority decision is missing or invalid")
    families = {family["family"]: family for family in manifest["families"]}
    frozen = [family["path"] + "/" for family in families.values()
              if family["disposition"] == "keep_historical_in_place"]
    expected = exact_document_hashes()
    document_paths = set(expected)
    captures = json.loads(blob("evidence/effects_projectiles/validation.json"))["historical_evidence_sha256"]
    expected.update(captures)
    for entry in entries:
        path = entry["path"]
        family = families[entry["family"]]
        if (entry["prior_individual_sha256_authority"] is not False
                or not path.startswith(family["path"] + "/")
                or entry["accepted_family_bytes"] != family["bytes"]
                or path in expected):
            raise ValueError("Invalid owner authority provenance: " + path)
        expected[path] = entry["sha256"]

    preload_blobs([path for path in files if path in expected or Path(path).suffix in LF_EXTENSIONS
                   or path in {".gitattributes", ".gitignore"}])
    failures = []
    lf_count = 0
    for path in files:
        suffix = Path(path).suffix
        immutable = path in document_paths or path.startswith(tuple(frozen)) or path.startswith("evidence/effects_projectiles/history/")
        text = not immutable and (suffix in LF_EXTENSIONS or path in {".gitattributes", ".gitignore"})
        binary = suffix in BINARY_EXTENSIONS
        if not (immutable or text or binary):
            continue
        required = "unset" if immutable or binary else "set"
        for attrs in classifications:
            if attrs[path].get("text") != required or (text and attrs[path].get("eol") != "lf"):
                failures.append("required checkout attributes missing: " + path)
        if text:
            lf_count += 1
            committed = blob(path)
            if b"\r" in committed or b"\0" in committed:
                failures.append("noncanonical LF Git blob: " + path)
            if not index_only:
                working = (ROOT / path).read_bytes()
                if b"\r" in working or b"\0" in working:
                    failures.append("noncanonical LF checkout: " + path)

    for path, sha256 in expected.items():
        if path not in files:
            failures.append("protected path not versioned: " + path)
            continue
        raw = blob(path)
        if hashlib.sha256(raw).hexdigest() != sha256:
            failures.append("protected raw Git hash mismatch: " + path)
        if not index_only and hashlib.sha256((ROOT / path).read_bytes()).hexdigest() != sha256:
            failures.append("protected raw checkout hash mismatch: " + path)
    for entry in entries:
        raw = blob(entry["path"])
        normalized = raw.replace(b"\r\n", b"\n")
        if (len(raw) != entry["bytes"] or b"\r" in normalized
                or hashlib.sha256(normalized).hexdigest() != entry["baseline_blob_sha256"]):
            failures.append("owner-authorized size/normalized-content mismatch: " + entry["path"])
        if not index_only and (ROOT / entry["path"]).stat().st_size != entry["bytes"]:
            failures.append("owner-authorized checkout size mismatch: " + entry["path"])
    if failures:
        raise ValueError("Checkout integrity failed:\n- " + "\n- ".join(failures))
    print(f"Checkout integrity PASS: {lf_count} LF paths; {len(document_paths)} pre-existing exact document hashes; "
          f"{len(captures)} pre-existing capture hashes; {len(entries)} newly owner-established authorities; "
          + ("index only" if index_only else "index and working tree"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--index-only", action="store_true", help="review staged policy/blobs before creating a fresh checkout")
    args = parser.parse_args()
    try:
        check(args.index_only)
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
