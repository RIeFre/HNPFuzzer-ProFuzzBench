#!/bin/bash

folder=$1
# kamailio refuses to start without its runtime dir
mkdir -p ./kamailio-gcov/runtime_dir
   #fuzzer result folder
pno=$2      #port number
step=$3     #step to skip running gcovr and outputting data to covfile
            #e.g., step=5 means we run gcovr after every 5 test cases
covfile=$4  #path to coverage file
fmode=$5    #file mode -- structured or not
            #fmode = 0: the test case is a concatenated message sequence -- there is no message boundary
            #fmode = 1: the test case is a structured file keeping several request messages

# The default Kamailio build compiles every in-tree module, but this benchmark's
# kamailio-basic.cfg loads only the 15 modules below. gcovr scans .gcno files as
# well as .gcda files, so without this exclusion the report denominator contains
# roughly 138k lines of modules that are never loaded at runtime.
EXCL_UNLOADED_MODULES='.*modules/(?!kex/|corex/|tm/|tmx/|sl/|rr/|pv/|maxfwd/|usrloc/|registrar/|textops/|siputils/|xlog/|sanity/|counters/).*'

#delete the existing coverage file
rm $covfile > /dev/null 2>&1; touch $covfile

#clear gcov data
gcovr --gcov-ignore-errors=no_working_dir_found --merge-mode-functions separate -r kamailio-gcov/src --exclude "$EXCL_UNLOADED_MODULES" -s -d > /dev/null 2>&1

#output the header of the coverage file which is in the CSV format
#Time: timestamp, l_per/b_per and l_abs/b_abs: line/branch coverage in percentage and absolutate number
echo "Time,l_per,l_abs,b_per,b_abs" >> $covfile

#files stored in replayable-* folders are structured
#in such a way that messages are separated
if [ $fmode -eq "1" ]; then
  testdir="replayable-queue"
  replayer="aflnet-replay"
else
  testdir="queue"
  replayer="afl-replay"
fi

# aflnet-replay waits only ~10 ms (server_wait_usecs) before sending, while this
# kamailio build needs ~16 ms on an idle host -- and noticeably more when the
# 8-12 containers of a benchmark run compete for the same cores -- to answer its
# first SIP request. Starting the replayer in parallel with the server therefore
# sends every message into a socket that is not listening yet, and the measured
# coverage stays at the start-up baseline no matter how large the corpus is.
# Start the server first, wait it out (WARMUP), then replay.
WARMUP=${WARMUP:-0.3}
# How long the server is kept alive per test case: long enough for run_pjsip's
# REGISTER to complete, short enough to keep a multi-thousand-entry replay cheap.
SERVER_LIFETIME=${SERVER_LIFETIME:-6}
PJSUA_WINDOW=${PJSUA_WINDOW:-2}

replay_one() {
  local f=$1
  timeout -k 0 -s SIGTERM ${SERVER_LIFETIME}s ./kamailio-gcov/src/kamailio \
    -f ./kamailio-basic.cfg -L ./kamailio-gcov/src/modules \
    -Y ./kamailio-gcov/runtime_dir/ -n 1 -D -E > /dev/null 2>&1 &
  sleep $WARMUP
  ./run_pjsip > /dev/null 2>&1
  $replayer "$f" SIP $pno 1 > /dev/null 2>&1
  sleep $PJSUA_WINDOW
  pkill -f "kamailio-gcov/src/kamailio" > /dev/null 2>&1
  pkill -f pjsua > /dev/null 2>&1
  wait > /dev/null 2>&1
}

#process initial seed corpus first
for f in $(echo $folder/$testdir/*.raw); do 
  time=$(stat -c %Y $f)

  replay_one "$f"
  cov_data=$(gcovr --gcov-ignore-errors=no_working_dir_found --merge-mode-functions separate -r kamailio-gcov/src --exclude "$EXCL_UNLOADED_MODULES" -s | grep "[lb][a-z]*:")
  l_per=$(echo "$cov_data" | grep lines | cut -d" " -f2 | rev | cut -c2- | rev)
  l_abs=$(echo "$cov_data" | grep lines | cut -d" " -f3 | cut -c2-)
  b_per=$(echo "$cov_data" | grep branch | cut -d" " -f2 | rev | cut -c2- | rev)
  b_abs=$(echo "$cov_data" | grep branch | cut -d" " -f3 | cut -c2-)
  
  echo "$time,$l_per,$l_abs,$b_per,$b_abs" >> $covfile
done

#process fuzzer-generated testcases
count=0
for f in $(echo $folder/$testdir/id*); do 
  time=$(stat -c %Y $f)

  replay_one "$f"
  count=$(expr $count + 1)
  rem=$(expr $count % $step)
  if [ "$rem" != "0" ]; then continue; fi
  cov_data=$(gcovr --gcov-ignore-errors=no_working_dir_found --merge-mode-functions separate -r kamailio-gcov/src --exclude "$EXCL_UNLOADED_MODULES" -s | grep "[lb][a-z]*:")
  l_per=$(echo "$cov_data" | grep lines | cut -d" " -f2 | rev | cut -c2- | rev)
  l_abs=$(echo "$cov_data" | grep lines | cut -d" " -f3 | cut -c2-)
  b_per=$(echo "$cov_data" | grep branch | cut -d" " -f2 | rev | cut -c2- | rev)
  b_abs=$(echo "$cov_data" | grep branch | cut -d" " -f3 | cut -c2-)
  
  echo "$time,$l_per,$l_abs,$b_per,$b_abs" >> $covfile
done

#ouput cov data for the last testcase(s) if step > 1
if [[ $step -gt 1 ]]
then
  time=$(stat -c %Y $f)
  cov_data=$(gcovr --gcov-ignore-errors=no_working_dir_found --merge-mode-functions separate -r kamailio-gcov/src --exclude "$EXCL_UNLOADED_MODULES" -s | grep "[lb][a-z]*:")
  l_per=$(echo "$cov_data" | grep lines | cut -d" " -f2 | rev | cut -c2- | rev)
  l_abs=$(echo "$cov_data" | grep lines | cut -d" " -f3 | cut -c2-)
  b_per=$(echo "$cov_data" | grep branch | cut -d" " -f2 | rev | cut -c2- | rev)
  b_abs=$(echo "$cov_data" | grep branch | cut -d" " -f3 | cut -c2-)
  
  echo "$time,$l_per,$l_abs,$b_per,$b_abs" >> $covfile
fi
