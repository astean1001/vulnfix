import os
from os.path import join as pjoin

###########
# Path definitions
###########

# dir_root = str(Path(__file__).parent.parent.resolve())
dir_root = "/home/yuntong/vulnfix"
dir_runtime = pjoin(dir_root, "runtime") # set at runtime
dir_result = pjoin(dir_runtime, "result")
dir_lib = pjoin(dir_root, "lib")
dir_thirdparty = pjoin(dir_root, "thirdparty")
dir_eusolver = pjoin(dir_thirdparty, "eusolver")
dir_eusolver_src = pjoin(dir_eusolver, "src")
dir_cvc5 = pjoin(dir_thirdparty, "cvc5")
full_cvc5 = pjoin(dir_cvc5, "build", "bin", "cvc5")
dir_daikon = pjoin(dir_thirdparty, "daikon")
full_daikon = pjoin(dir_daikon, "daikon.jar")
dir_danmuji = pjoin(dir_thirdparty, "danmuji")
full_danmuji = pjoin(dir_danmuji, "danmuji")
dir_afl = pjoin(dir_thirdparty, "AFL")
dir_temp = pjoin(dir_root, "run-temp") # a temp dir to store runtime-generated junk files)
dir_dafl = pjoin(dir_thirdparty, "DAFL")

dir_afl_raw_input = ""
dir_afl_raw_output = ""
dir_afl_raw_input_normal = ""
dir_afl_raw_output_normal = ""
dir_afl_pass = ""
dir_afl_fail = ""
dir_seed_pass = ""
dir_seed_fail = ""

# original and patched binaries
bin_orig = ""
bin_instrumented = ""
bin_afl = ""
bin_dafl = ""
bin_snapshot = ""
bin_mutate = ""
bin_crash = "" # should crash at crash location with `patch_exit_code`

# files used during runtime
files_normal_in = []
file_exploit = ""
file_snapshot_orig = ""
file_snapshot_hash = ""
file_snapshot_processed = ""
file_solver_in = ""
file_pass_ss_pool = ""
file_fail_ss_pool = ""
file_logging = ""

# daikon-related files
file_daikon_config = pjoin(dir_root, "daikon-config")
file_daikon_feasibility_traces = ""
file_daikon_pass_traces = ""
file_daikon_fail_traces = ""
file_daikon_decl = ""
file_daikon_pass_inv = ""


##########
# Useful information for execution.
##########

### set at runtime
prog_cmd = '' # everything after the binary name; <exploit> is placeholder for input
fix_loc = ""
# The crash location provided by user.
# - Used to place instrumentations to check whether execution reaches crash location
# - Not using exploit_crash_line to avoid more parsing
# - Also for flexibility: exploit_crash_line is from sanitizer, and that can be in
# a very common function (like malloc etc.). The common functions are very easy
# to hit, so may not be a good first mechanism of filtering out irrelevant inputs
# In this case, crash_loc can be the call site of that common function.
crash_loc = ""
# The crash line information generated by sanitizers
# - Used to determine execution status of other inputs (i.e. whether crash at same loc as exploit)
# - Should look sth like: /home/yuntong/vulnfix/data/libming/cve_2016_9264/source/util/listmp3.c:128
# Note: clang sanitizers may addtionally append :column-num, but it does not matter
exploit_crash_line = ""
# the type of bug from sanitizer report
# should look sth like: heap-buffer-overflow
bug_type = ""
# exit code from exploit, should be either 55 or 54
exploit_exit_code = -1
# records mapping from variable name to its type
var_types = dict()
# records mapping from gsize to the size of individual elements of the buffer, str => int
gsize_to_elem_size = dict()
# records all variables used in each snapshot
candidate_variables = set()

### pre-defined
ubsan_exit_code = 54 # to identify crashes caused by UBSAN
asan_exit_code = 55 # to identify crashes caused by ASAN
patch_exit_code = 6 # to identify artifical crash introduced by vulnfix

# sanitizers environment options for it to work as expected
sanitizer_env = {"ASAN_OPTIONS":
                    "redzone=64:" +
                    "exitcode=" + str(asan_exit_code) + ":" +
                    "detect_leaks=0:" +
                    "allocator_may_return_null=1",
                  #   "dump_instruction_bytes=true",
                 "UBSAN_OPTIONS":
                    "halt_on_error=1:" +
                    "exitcode=" + str(ubsan_exit_code) + ":" +
                    "print_stacktrace=1"}
# include original env so that other env vars are not thrown away
modified_env = {**os.environ, **sanitizer_env}


##########
# Configuration settings
##########

# False -> input from file; True -> input from stdin
input_from_stdin = False
# Whether force to skip AFL deterministic stage;
# this overwrites the internel decision made by VulnFix
# If no specified in config file, then it remains as None
afl_skip_deterministic = None
# Whether to use raw size (in bytes) for _GSize_ in snapshots and inference
# By default, this is False and _GSize_ is in granularity of element size
use_raw_size = False
# Mode for using reduced snapshots
# normal value is False, meaning that VulnFix makes internel decisions on this
unreduced = False
# whether to terminate early in snapshot fuzzing, if keep seeing same results
early_term = True
# Are we using ConcFuzz instead of AFL+snapshot fuzzing?
concfuzz = False
# Are we using AFL-only instead of AFL+snapshot fuzzing?
aflfuzz = False
# Are we using DAFL-only instead of AFL+snapshot fuzzing?
daflfuzz = False
# Are we resetting benchmark instead of running it?
resetbench = False

# string: records which backend is being used
# {daikon, cvc5}
backend_choice = ""

# int: total time budget for this VulnFix run
time_budget = 30

# Patch validation
dir_source = ""
fix_file_rel_path = ""
fix_file_path = ""
backup_file_path = ""
fix_line = None
build_cmd = ""
binary_full_path = ""

all_pass_inputs = list()
all_fail_inputs = list()
