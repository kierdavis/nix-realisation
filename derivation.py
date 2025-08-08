import json
import pathlib
import subprocess
import sys

query = json.load(sys.stdin)

eval_options = json.loads(query["eval_options"])
eval_result = subprocess.run(
  [
    "nix",
    "--extra-experimental-features", "nix-command",
    "--extra-experimental-features", "flakes",
    "path-info",
    "--derivation",
    "--show-trace",
  ] + eval_options + [query["flake_output"]],
  stdout=subprocess.PIPE,
)
if eval_result.returncode != 0:
  sys.exit(eval_result.returncode)
drv_path = eval_result.stdout.decode("utf-8").strip()

if query["create_gc_root"]:
  gc_root_path = pathlib.Path(query["gc_root_dir"]) / (query["gc_root_id"] + ".drv")
  gc_root_path.parent.mkdir(parents=True, exist_ok=True)
  # XXX: I don't think there's a way to point a GC root at a derivation
  # through the Nix CLI right now, except with this horrible hack:
  # Create a GC root pointing at an arbitrary placeholder store path.
  subprocess.run(
    [
      "nix",
      "--extra-experimental-features", "nix-command",
      "build",
      "--expr", 'builtins.toFile "placeholder" ""',
      "--out-link", str(gc_root_path),
    ],
    stdout=sys.stderr,
    check=True,
  )
  # Change the symlink to point at what we actually want.
  gc_root_path.unlink()
  gc_root_path.symlink_to(drv_path)

result = {"drv_path": drv_path}
json.dump(result, sys.stdout, separators=(",", ":"))
