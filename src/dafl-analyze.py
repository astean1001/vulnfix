#! /usr/bin/env python3.8
import os
import subprocess
import time
import sys
from typing import Union, List, Dict, Tuple, Optional, Set
import multiprocessing as mp
import datetime
import json
import argparse
import sbsv

date = datetime.datetime.now().strftime("%Y-%m-%d")
root_dir = "/home/yuntong/vulnfix"
exp_id = date


def read_config(file) -> dict:
    result = dict()
    with open(file, "r") as f:
        for line in f.readlines():
            line = line.strip()
            if line == "":
                continue
            tokens = line.split("=", maxsplit=1)
            result[tokens[0]] = tokens[1]
    return result


def print_env_str(env: dict):
    cov_exe = env["PACFIX_COV_EXE"]
    val_exe = env["PACFIX_VAL_EXE"]
    cov_dir = env["PACFIX_COV_DIR"]
    print(f"PACFIX_COV_EXE={cov_exe};PACFIX_VAL_EXE={val_exe};PACFIX_COV_DIR={cov_dir};AFL_NO_UI=1")


def new_env(env: dict, dir: str) -> dict:
    result = env.copy()
    result["PACFIX_COV_DIR"] = dir
    return result


import pandas as pd
import matplotlib.pyplot as plt


def analyze_vertical(dir: str):
    file = os.path.join(dir, "vertical.log")
    if not os.path.exists(file):
        print(f"ERROR: {file} does not exist")
        return
    
    df = pd.read_csv(file, names=['type', 'is_preserve', 'is_inter', 'is_new_val', 'mut', 'loc'])
    df = df[df['type'] == 'v']

    fig, axes = plt.subplots(1, 3, figsize=(18, 6))
    if not df[df['is_preserve'] == 1].empty:
        df[df['is_preserve'] == 1].groupby(['mut', 'is_preserve']).size().unstack().plot(kind='bar', ax=axes[0])
        axes[0].set_title('mut - is_preserve distribution')
        axes[0].set_ylabel('#')
    
    if not df[df['is_inter'] == 1].empty:
        df[df['is_inter'] == 1].groupby(['mut', 'is_inter']).size().unstack().plot(kind='bar', ax=axes[1])
        axes[1].set_title('mut - is_interesting distribution')
        axes[1].set_ylabel('#')
    
    if not df[df['is_new_val'] == 1].empty:
        df[df['is_new_val'] == 1].groupby(['mut', 'is_new_val']).size().unstack().plot(kind='bar', ax=axes[2])
        axes[2].set_title('mut - is_new_val distribution')
        axes[2].set_ylabel('#')
    
    plt.tight_layout()
    out_file = os.path.join(dir, "mut_distribution.png")
    plt.savefig(out_file)
    
    # loc에 대한 분포 시각화
    fig, axes = plt.subplots(1, 4, figsize=(24, 6))
    
    if not df[df['is_preserve'] == 1].empty:
        df[df['is_preserve'] == 1].groupby(pd.cut(df["loc"], bins=16))['is_preserve'].value_counts().unstack().plot(kind='bar', ax=axes[0])
        axes[0].set_title('loc - is_preserve distribution')
        axes[0].set_ylabel('#')
    
    if not df[df['is_inter'] == 1].empty:
        df[df['is_inter'] == 1].groupby(pd.cut(df["loc"], bins=16))['is_inter'].value_counts().unstack().plot(kind='bar', ax=axes[1])
        axes[1].set_title('loc - is_interesting distribution')
        axes[1].set_ylabel('#')
    
    if not df[df['is_new_val'] == 1].empty:
        df[df['is_new_val'] == 1].groupby(pd.cut(df["loc"], bins=16))['is_new_val'].value_counts().unstack().plot(kind='bar', ax=axes[2])
        axes[2].set_title('loc - is_new_val distribution')
        axes[2].set_ylabel('#')
    if not df["loc"].empty:
        df.groupby(pd.cut(df["loc"], bins=16))['loc'].count().plot(kind='bar', ax=axes[3])
    axes[3].set_title("loc - distribution")
    axes[3].set_xlabel("loc")
    axes[3].set_ylabel("#")
    
    plt.tight_layout()
    out_file = os.path.join(dir, "loc_distribution.png")
    plt.savefig(out_file)


def load_dafl_log(unique_log: str) -> dict:
    parser = sbsv.parser()
    parser.add_schema("[pacfix] [mem] [neg] [seed: int] [id: int] [hash: int] [time: int] [file: str]")
    parser.add_schema("[pacfix] [mem] [pos] [seed: int] [id: int] [hash: int] [time: int] [file: str]")
    parser.add_schema(
        "[moo] [save] [seed: int] [moo-id: int] [fault: int] [path: bool] [val: int] [file: str] [mut: str] [time: int]")
    parser.add_schema(
        "[vertical] [save] [seed: int] [id: int] [dfg-path: int] [cov: int] [prox: int] [adj: float] [mut: str] [file: str] [time: int]")
    parser.add_schema("[vertical] [dry-run] [id: int] [dfg-path: int] [res: int] [file: str]")
    parser.add_schema(
        "[vertical] [valuation] [seed: int] [dfg-path: int] [hash: int] [id: int] [persistent: bool] [time: int]")
    with open(unique_log, 'r') as f:
        return parser.load(f)


def analyze_dafl(dir: str):
    unique_log = os.path.join(dir, "unique_dafl.log")
    if not os.path.exists(unique_log):
        print(f"ERROR: {unique_log} does not exist")
        return
    result = load_dafl_log(unique_log)
    # print(result["vertical"]["valuation"])
    path_map = dict()
    for res in result["vertical"]["valuation"]:
        dfg_path = res["dfg-path"]
        hash = res["hash"]
        if dfg_path not in path_map:
            path_map[dfg_path] = set()
        path_map[dfg_path].add(hash)
    dfg_paths = list(path_map.keys())
    val_counts = [len(path_map[p]) for p in dfg_paths]
    print(dfg_paths)
    print(val_counts)
    x = range(len(dfg_paths))
    plt.figure(figsize=(10, 5))
    plt.bar(x, val_counts, color='blue')
    plt.xlabel('DFG Path')
    plt.ylabel('Number of Unique Hashes')
    plt.title('Number of Unique Hashes per DFG Path')
    plt.xticks(x)  # Set the x-ticks to match the dfg_paths
    plt.savefig(os.path.join(dir, "vertical-path.png"))


def execute(cmd: str, dir: str):
    print(f"Change directory to {dir}")
    print(f"Executing: {cmd}")
    proc = subprocess.run(cmd, shell=True, cwd=dir, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if proc.returncode != 0:
        print(f"!!!!! Error !!!! {cmd}")
        try:
            print(proc.stderr.decode("utf-8", errors="ignore"))
        except Exception as e:
            print(e)
    return proc.returncode


def collect_inputs(runtime_dir: str, dir: str):
    unique_log = os.path.join(dir, "unique_dafl.log")
    if not os.path.exists(unique_log):
        print(f"ERROR: {unique_log} does not exist")
        return
    target = os.path.join(runtime_dir, "vert-in")
    execute(f"rm -r {target}", runtime_dir)
    os.makedirs(target, exist_ok=True)
    execute(f"cp in/* {target}", runtime_dir)
    result = load_dafl_log(unique_log)
    print(result["vertical"]["dry-run"])
    print(result["vertical"]["save"])
    path_filter = set()
    for save in result["vertical"]["save"]:
        path = save["dfg-path"]
        if path in path_filter:
            continue
        file = save["file"]
        path_filter.add(path)
        execute(f"cp {file} {target}", runtime_dir)
        print(f"Save {len(path_filter)}")


def run_cmd(subject: dict, cmd: str):
    subject_dir = os.path.join(root_dir, "data", subject["subject"], subject["bug_id"])
    runtime_dir = os.path.join(subject_dir, "dafl-runtime")
    config = read_config(os.path.join(subject_dir, "config"))

    # ex_list = ["dafl", "moo", "vert"]
    ex_list = ["hor", "vert", "one"]
    for ex in ex_list:
        out_dir = os.path.join(runtime_dir, f"{exp_id}-{ex}")
        # analyze_vertical(out_dir)
        if cmd == "collect":
            collect_inputs(runtime_dir, out_dir)
            continue
        analyze_dafl(out_dir)
        analyze_vertical(out_dir)


def read_meta_data():
    with open(f"{root_dir}/meta-data.json") as f:
        meta_data = json.load(f)
    return meta_data


def find_subject(subject_id: str, meta) -> dict:
    for sbj in meta:
        if str(sbj["id"]) == subject_id:
            return sbj
        if sbj["bug_id"] == subject_id:
            return sbj
        if subject_id in sbj["bug_id"]:
            return sbj
    return None


def main(argv: List[str]):
    parser = argparse.ArgumentParser()
    parser.add_argument("cmd", help="Command to execute",
                        choices=["run", "collect", "analyze"])
    parser.add_argument("subject", help="subject_id")
    parser.add_argument("--id", help="id", default="")
    args = parser.parse_args(argv)
    meta = read_meta_data()
    subject = find_subject(args.subject, meta)
    if subject is None:
        print(f"FATAL: invalid subject {subject}")
        exit(1)
    global exp_id
    if args.id != "":
        exp_id = args.id
    run_cmd(subject, args.cmd)


if __name__ == "__main__":
    main(sys.argv[1:])
