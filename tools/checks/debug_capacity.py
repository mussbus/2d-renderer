"""Bounded production debug-buffer compiler probes; retain raw compiler outcomes."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--optimize", choices=("Debug", "ReleaseSafe", "ReleaseFast"), default="Debug")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    zig = root / ".deps/zig-0.16.0/zig.exe"
    version = subprocess.run([str(zig), "version"], check=True, capture_output=True, text=True).stdout.strip()
    if version != "0.16.0":
        raise RuntimeError("debug capacity probes require Zig 0.16.0")
    rows = []
    for name in ("valid", "zero", "too_large"):
        command = [str(zig), "build-obj", "-fno-emit-bin", "-O" + args.optimize,
                   "--cache-dir", ".zig-cache", "--global-cache-dir", ".tmp/projectile-impact/global-cache",
                   "--dep", "debug_draw", "-Mroot=tests/fixtures/debug_capacity/" + name + ".zig",
                   "--dep", "sprite_batch", "-Mdebug_draw=src/debug/debug_draw.zig",
                   "-Msprite_batch=src/graphics/sprite_batch.zig"]
        result = subprocess.run(command, cwd=root, capture_output=True)
        raw = result.stdout + result.stderr
        log = output / (name + ".txt")
        with log.open("xb") as stream:
            stream.write(raw)
        errors = [line for line in raw.decode("utf-8", errors="replace").splitlines() if "error:" in line]
        diagnostic = "error: debug command capacity must fit the sprite ordering key"
        expected_failure = name != "valid"
        verified = (result.returncode != 0 and len(errors) == 1 and
                    "debug_draw.zig:" in errors[0] and errors[0].endswith(diagnostic)) if expected_failure else result.returncode == 0
        rows.append({"fixture": name, "optimization_mode": args.optimize,
                     "command": command, "compiler_exit_code": result.returncode,
                     "expected": "capacity diagnostic" if expected_failure else "compile success",
                     "verified": verified, "raw_log": log.name,
                     "raw_sha256": hashlib.sha256(raw).hexdigest()})
        with (output / "results.json").open("w", encoding="utf-8", newline="\n") as stream:
            json.dump(rows, stream, indent=2)
            stream.write("\n")
        print(name + ": compiler_exit=" + str(result.returncode) + " verified=" + str(verified), flush=True)
        if not verified:
            raise RuntimeError("capacity probe failed: " + name + "; see " + str(log))


if __name__ == "__main__":
    main()
