import json
import subprocess
import sys

query = json.load(sys.stdin)
drv_path = query["drv_path"]

derivation = json.loads(subprocess.run(
  [
    "nix",
    "--extra-experimental-features", "nix-command",
    "derivation", "show",
   drv_path,
  ],
  stdout=subprocess.PIPE,
  check=True,
).stdout)[drv_path]

result = {name: val["path"] for name, val in derivation["outputs"].items()}
json.dump(result, sys.stdout, separators=(",", ":"))
