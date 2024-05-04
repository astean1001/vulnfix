#! /usr/bin/env python3.8
import os
import subprocess
import time
import sys
from typing import Union, List, Dict, Tuple, Optional, Set
import multiprocessing as mp
import datetime
date = datetime.datetime.now().strftime("%Y-%m-%d")

def execute(cmd: str, dir: str, conf_id: str, out_dir: str, env: dict = None):
  print(f"Change directory to {dir}")
  print(f"Executing: {cmd}")
  if env is None:
    env = os.environ
  proc = subprocess.run(cmd, shell=True, cwd=dir, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
  log_file = os.path.join(dir, f"{out_dir}/out-{conf_id}.log")
  os.system(f"rm -rf {out_dir}/crashes {out_dir}/hangs")
  if proc.returncode != 0:
    print("!!!!! Error !!!!")
    try:
      print(proc.stderr.decode("utf-8", errors="ignore"))
      with open(log_file, "w") as f:
        f.write(proc.stderr.decode("utf-8", errors="ignore"))
        f.write("\n\n====================\n\n")
        f.write(proc.stdout.decode("utf-8", errors="ignore"))
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


def main(argv: List[str]):
  dir = "/home/yuntong/vulnfix/data/libtiff/cve_2016_5321/dafl-runtime/2024-02-27"
  opt = "exp"
  if len(argv) != 0:
    opt = argv[0]
    dir = argv[1]
  config = list()
  for r in [0.8, 0.9, 0.95, 0.99, 1.0]:
    for k in [1]:
      config.append((r, k))
  for r in [0.05, 0.1, 0.2, 0.3, 0.5]:
    for k in [-1]:
      config.append((r, k))
  if opt == "exp":
    run_cmd(opt, dir, config)
  elif opt == "analyze":
    analyze(dir)

if __name__ == "__main__":
  main(sys.argv[1:])