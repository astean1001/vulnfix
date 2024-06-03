#! /usr/bin/env python3.8
import os
import subprocess
import time
import sys
import argparse
from typing import Union, List, Dict, Tuple, Optional, Set
import multiprocessing as mp
import datetime
date = datetime.datetime.now().strftime("%Y-%m-%d")
id = date
cmd = "run"

def execute(cmd: str, dir: str, conf_id: str, env: dict = None):
  print(f"Change directory to {dir}")
  print(f"Executing: {cmd}")
  if env is None:
    env = os.environ
  proc = subprocess.run(cmd, shell=True, cwd=dir, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
  if proc.returncode != 0:
    print("!!!!! Error !!!!")
    try:
      print(proc.stderr.decode("utf-8", errors="ignore"))
    except Exception as e:
      print(e)
  return proc.returncode

def execute_wrapper(args):
  return execute(args[0], args[1], args[2], args[3])

def run_cmd(opt: str, dir: str, config: List[Tuple[float, int]]):
  core = 10
  pool = mp.Pool(core)
  args_list = list()
  for conf in config:
    conf_id = f"4096-{conf[0]}-k{conf[1]}"
    if conf[1] < 0:
        conf_id = f"4096-{conf[0]}"
    out_dir = os.path.join(dir, f"2024-02-28/out-{conf_id}")
    target_cmd = "./nm-new.instrumented -A -a -l -S -s --special-syms --synthetic --with-symbol-versions @@"
    target_cmd = f"./tiffcrop.instrumented @@ /tmp/out-{conf_id}"
    cmd = f"timeout 6h /home/yuntong/vulnfix/thirdparty/DAFL/afl-fuzz -C -t 2000ms -m none -i ./in -o {out_dir} -r {conf[0]} -k {conf[1]} -- {target_cmd}"
    args_list.append((cmd, dir, conf_id, out_dir))
  pool.map(execute_wrapper, args_list)
  pool.close()
  pool.join()
  print(f"{opt} done")

def analyze(dir: str):
  result = list()
  for d in sorted(os.listdir(dir)):
    if os.path.isdir(os.path.join(dir, d)):
      file = os.path.join(dir, d, "unique_dafl.log")
      with open(file, "r") as f:
        uniq = 0
        tot = 0
        lines = f.readlines()
        for line in lines:
          if "[uniq]" in line:
            uniq += 1
          if "[q]" in line:
            tot += 1
        result.append((d, uniq, tot))
  with open(os.path.join(dir, "result.csv"), "w") as f:
    f.write("id,uniq,tot\n")
    for r in result:
      f.write(f"{r[0]},{r[1]},{r[2]}\n")

def run_exp(subject: str) -> None:
  print(f"run {subject}")
  run_file = "/home/yuntong/vulnfix/src/dafl-run.py"
  if cmd == "analyze":
    run_file = "/home/yuntong/vulnfix/src/dafl-analyze.py"
  execute(f"python3.8 {run_file} run {subject} --id {id}", "/home/yuntong/vulnfix", id)


def main(argv: List[str]):
  parser = argparse.ArgumentParser()
  parser.add_argument("id", help="id for experiment")
  parser.add_argument("--cmd", help="cmd", choices=["run", "analyze"], default="run")
  args = parser.parse_args(argv[1:])
  global cmd
  global id
  id = args.id
  cmd = args.cmd
  # libtiff, libxml2, zziplib
  exps = ["cve_2016_5321", "cve_2016_10094", "cve_2012_5134", "cve_2017_5969", "cve_2017_5975"]
  # libjpeg
  exps.append("cve_2012_2806")
  # coreutils
  exps.append("gnubug_25003")
  pool = mp.Pool(32)
  pool.map(run_exp, exps)
  pool.close()
  pool.join()
  print(f"{id} done")


if __name__ == "__main__":
  main(sys.argv)