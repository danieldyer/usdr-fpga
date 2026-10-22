#!/usr/bin/env python3
"""Record exact source inputs and run Vivado without programming hardware."""
import argparse, hashlib, json, os, subprocess
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument("output",type=Path)
p.add_argument("--role",required=True,choices=["ram","operational","golden"])
p.add_argument("--jobs",type=int,default=4)
p.add_argument("--vivado",default="vivado")
a=p.parse_args()
root=Path(__file__).resolve().parents[1]
out=a.output.resolve()
if out.exists(): p.error("Choose a new output directory")
if a.jobs<1: p.error("jobs must be positive")
out.mkdir(parents=True)
files=sorted(f for d in ["hw","lib","scripts"] for f in (root/d).rglob("*") if f.is_file())
manifest={str(f.relative_to(root)):hashlib.sha256(f.read_bytes()).hexdigest() for f in files}
(out/"sources.json").write_text(json.dumps(manifest,indent=2)+"\n")
try:
    rev=subprocess.check_output(["git","rev-parse","HEAD"],cwd=root,text=True).strip()
    diff=subprocess.check_output(["git","diff","HEAD","--binary"],cwd=root)
    (out/"git.txt").write_text(rev+"\n")
    (out/"source.diff").write_bytes(diff)
except subprocess.CalledProcessError:
    (out/"git.txt").write_text("Source export; SHA256 manifest is authoritative.\n")
cmd=[a.vivado,"-mode","batch","-source",str(root/"hw/usdr/build.tcl"),"-tclargs",str(out),a.role,str(a.jobs)]
raise SystemExit(subprocess.call(cmd,cwd=out))
