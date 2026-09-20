# HNPFuzzer-ProFuzzBench

HNPFuzzer-ProFuzzBench provides automation scripts for fuzzing the 13 targets in ProFuzzBench with 4 fuzzers, i.e., [HNPFuzzer](https://github.com/veltavid/HNPFuzzer.git), [AFLnwe](https://github.com/aflnet/aflnwe), [AFLNet](https://github.com/aflnet/aflnet), and [StateAFL](https://github.com/stateafl/stateafl).

## Base image

Every subject image is built from the **same prefix**, which is kept byte-identical
to profuzzbench-new's `ubuntu:22.04` prefix so Docker can reuse those layers:

| | |
|---|---|
| OS | `ubuntu:22.04` |
| Compiler | clang-12 / llvm-12-dev (an AFLNet-derived LLVM pass only builds against LLVM 12/13) |
| Coverage | `gcovr 8.6` (pinned) |
| Fuzzer | HNPFuzzer, built with `CFLAGS="-O3 -funroll-loops -fcommon"` — see the note in each Dockerfile |

Two things about this benchmark differ from profuzzbench-new on purpose:

- **No ASAN.** `AFL_USE_ASAN=1` and `-fsanitize=address` are stripped from every
  target build. `ASAN_OPTIONS` is still exported for compatibility, but nothing
  is compiled with the sanitizer, so exec/s and crash-detection power are not
  comparable with profuzzbench-new's numbers.
- **Images are prefixed `hnp-`** (`hnp-lightftp`, `hnp-lightftp-hnpfuzzer`,
  `hnp-lightftp-stateafl`, …) so they cannot collide with the bare-named images
  of a profuzzbench/profuzzbench-new checkout on the same host.

The 13 targets are pinned to the same upstream releases profuzzbench-new uses
(ProFTPD 1.3.9d, dnsmasq 2.93, Exim 4.100, OpenSSL 4.0.2, DCMTK 3.7.0,
Kamailio 6.1.4, OpenSSH V_9_7_P1, OwnTone 29.3, …); each clone carries a
`test "$(git rev-parse HEAD)" = …` guard so the build fails loudly if the pin
ever stops resolving.

## Set up environmental variables

```bash
git clone https://github.com/veltavid/HNPFuzzer-ProFuzzBench.git
cd HNPFuzzer-ProFuzzBench
export PFBENCH=$(pwd)
export PATH=$PATH:$PFBENCH/scripts/execution:$PFBENCH/scripts/analysis
```

## Build docker images

```bash
profuzzbench_build_all.sh
profuzzbench_build_HNPFuzzer.sh
```

## Run fuzzing

It is easy to run a fuzzing experiment by using [run_target.sh](run_target.sh), which receives 7 arguments as listed below.

- ***-t***: name of the target to be fuzzed
- ***-r***: number of parallel runs
- ***-f***: fuzzer name
- ***-s***: (optional) time for fuzzing in seconds, 86400s (24h) by default.
- ***-m***: (optional) mode of HNPFuzzer (i.e., *persistent, shared, sync, all*). The activated components in HNPFuzzer vary among modes.
- ***-i***: (optional) the index of output folder.
- ***-o***: (optional) directory where to place the output folder.

The following commands show how to run a 24h fuzzing using HNPFuzzer with all components enabled on LightFTP.

```bash
cd $PFBENCH
./run_target.sh -t lightftp -r 1 -f HNPFuzzer -m all -o ./tmp_results
```

## Collect the results

This step is the same as the step-3 in [ProFuzzBench](https://github.com/profuzzbench/profuzzbench/tree/master#step-3-collect-the-results).

## Evaluate the results

The python script [experiments_plot.py](scripts/analysis/experiments_plot.py) can be used to plot code coverage over time. Its usage is similar to profuzzbench_plot.py in ProFuzzBench, except for the following extra options:

- ***-t***: interval of ticks on the x-axis

- ***-r***: (optional) name of the folder that contains results.csv. If this options is not provided, the script will jump to a folder named "results" under each application directory and perform step-3. Therefore, there is no need to generate results.csv by hand in the previous step.

The following command is an example to plot the results.

```bash
cd $PFBENCH
python experiments_plot.py -c 1450 -s 1 -t 200 -o cov_over_time.png -r results
```

