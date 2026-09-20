#!/bin/bash

FUZZER=$1     #fuzzer name (e.g., aflnet) -- this name must match the name of the fuzzer folder inside the Docker container
OUTDIR=$2     #name of the output folder
OPTIONS=$3    #all configured options -- to make it flexible, we only fix some options (e.g., -i, -o, -N) in this script
TIMEOUT=$4    #time for fuzzing
SKIPCOUNT=$5  #used for calculating cov over time. e.g., SKIPCOUNT=5 means we run gcovr after every 5 test cases

strstr() {
  [ "${1#*$2*}" = "$1" ] && return 1
  return 0
}

#Commands for afl-based fuzzers (e.g., aflnet, aflnwe) -- HNPFuzzer carries no
#"afl" substring, so it needs the explicit test.
if $(strstr $FUZZER "afl") || $(strstr $FUZZER "HNPFuzzer"); then

  # Run fuzzer-specific commands (if any)
  if [ -e ${WORKDIR}/run-${FUZZER} ]; then
    source ${WORKDIR}/run-${FUZZER}
  fi

  TARGET_DIR=${TARGET_DIR:-"LightFTP"}
  INPUTS=${INPUTS:-"${WORKDIR}/in-ftp"}

  #Step-1. Do Fuzzing
  #Move to fuzzing folder
  cd $WORKDIR/${TARGET_DIR}/Source/Release
  mkdir $OUTDIR
  if $(strstr $FUZZER "HNPFuzzer"); then
    # HNPFuzzer hands the message buffers to the target over shared memory
    # (sock2shm.so is LD_PRELOAD-ed into it), which is what lets a resident
    # server be reused across test cases.
    AFL_PRELOAD=/home/ubuntu/${FUZZER}/sock2shm.so timeout -k 0 --preserve-status $TIMEOUT /home/ubuntu/${FUZZER}/afl-fuzz -d -i ${INPUTS} -x ${WORKDIR}/ftp.dict -o $OUTDIR -N tcp://127.0.0.1/2100 $OPTIONS -c ${WORKDIR}/ftpclean ./fftp ${WORKDIR}/fftp.conf > ${OUTDIR}/fuzzing.out 2>&1
  else
    timeout -k 0 --preserve-status $TIMEOUT /home/ubuntu/${FUZZER}/afl-fuzz -d -i ${INPUTS} -x ${WORKDIR}/ftp.dict -o $OUTDIR -N tcp://127.0.0.1/2100 $OPTIONS -c ${WORKDIR}/ftpclean ./fftp ${WORKDIR}/fftp.conf > ${OUTDIR}/fuzzing.out 2>&1
  fi

  STATUS=$?

  #Step-2. Collect code coverage over time
  #Move to gcov folder
  cd $WORKDIR/LightFTP-gcov/Source/Release

  #The last argument passed to cov_script should be 0 if the fuzzer is afl/nwe and it should be 1 if the fuzzer is based on aflnet
  #0: the test case is a concatenated message sequence -- there is no message boundary
  #1: the test case is a structured file keeping several request messages
  if [ "$FUZZER" = "aflnwe" ]; then
    cov_script ${WORKDIR}/${TARGET_DIR}/Source/Release/${OUTDIR}/ 2100 ${SKIPCOUNT} ${WORKDIR}/${TARGET_DIR}/Source/Release/${OUTDIR}/cov_over_time.csv 0 > ${WORKDIR}/${TARGET_DIR}/Source/Release/${OUTDIR}/cov.out 2>&1
  else
    cov_script ${WORKDIR}/${TARGET_DIR}/Source/Release/${OUTDIR}/ 2100 ${SKIPCOUNT} ${WORKDIR}/${TARGET_DIR}/Source/Release/${OUTDIR}/cov_over_time.csv 1 > ${WORKDIR}/${TARGET_DIR}/Source/Release/${OUTDIR}/cov.out 2>&1
  fi

  gcovr -r .. --html --html-details -o index.html
  mkdir ${WORKDIR}/${TARGET_DIR}/Source/Release/${OUTDIR}/cov_html/
  cp *.html ${WORKDIR}/${TARGET_DIR}/Source/Release/${OUTDIR}/cov_html/


  # Fail loudly when the replay collected nothing: generate_csv.sh would
  # otherwise emit a header-only CSV and the whole run would look successful.
  cov_lines=$(wc -l < ${WORKDIR}/${TARGET_DIR}/Source/Release/${OUTDIR}/cov_over_time.csv)
  if [ "$cov_lines" -lt 2 ]; then
    echo "ERROR: no coverage rows for $FUZZER on $TARGET_DIR (${OUTDIR}/cov_over_time.csv)" >&2
    exit 1
  fi

  #Step-3. Save the result to the ${WORKDIR} folder
  #Tar all results to a file
  cd ${WORKDIR}/${TARGET_DIR}/Source/Release
  tar -zcvf ${WORKDIR}/${OUTDIR}.tar.gz ${OUTDIR}

  exit $STATUS
fi
