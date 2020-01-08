#!/usr/bin/env bash
# If supplied $1 is the executable and $2 is the file where to create test-output.txt and summary.csv, otherwise these
# default to the 'target/current-directory-name' (e.g. target/commandlinerunner) and 
# target/native-image respectively

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

EXECUTABLE=${1:-target/${PWD##*/}}
if [ -z "$2" ]; then
  TEST_OUTPUT_FILE=target/native-image/test-output.txt
  BUILD_OUTPUT_FILE=target/native-image/output.txt
  SUMMARY_CSV_FILE=target/native-image/summary.csv
else
  TEST_OUTPUT_FILE=$2/test-output.txt
  BUILD_OUTPUT_FILE=$2/output.txt
  SUMMARY_CSV_FILE=$2/summary.csv
fi
echo "Testing executable '$EXECUTABLE'"

chmod +x ${EXECUTABLE}
./${EXECUTABLE} > $TEST_OUTPUT_FILE 2>&1 &
PID=$!
sleep 3

if [[ `cat $TEST_OUTPUT_FILE | grep "commandlinerunner running!"` ]]
then
  printf "${GREEN}SUCCESS${NC}\n"
  if [ -f "$BUILD_OUTPUT_FILE" ]; then
    TOTALINFO=`cat $BUILD_OUTPUT_FILE | grep "\[total\]"`
    BUILDTIME=`echo $TOTALINFO | sed 's/^.*\[total\]: \(.*\) ms.*$/\1/' | tr -d -c 0-9\.`
    BUILDMEMORY=`echo $TOTALINFO | sed 's/^.*\[total\]: .* ms,\(.*\) GB$/\1/' | tr -d -c 0-9\.`
    echo "Image build time: ${BUILDTIME}ms"
    RSS=`ps -o rss ${PID} | tail -n1`
    RSS=`bc <<< "scale=1; ${RSS}/1024"`
    echo "RSS memory: ${RSS}M"
    SIZE=`wc -c <"${EXECUTABLE}"`/1024
    SIZE=`bc <<< "scale=1; ${SIZE}/1024"`
    echo "Image size: ${SIZE}M"
    STARTUP=`cat $TEST_OUTPUT_FILE | grep "JVM running for"`
    REGEXP="Started .* in ([0-9\.]*) seconds \(JVM running for ([0-9\.]*)\).*$"
    if [[ ${STARTUP} =~ ${REGEXP} ]]; then
      STIME=${BASH_REMATCH[1]}
      JTIME=${BASH_REMATCH[2]}
      echo "Startup time: ${STIME} (JVM running for ${JTIME})"
    fi
    echo `date +%Y%m%d-%H%M`,$EXECUTABLE,$BUILDTIME,$BUILDMEMORY,${RSS},${SIZE},${STIME},${JTIME}  > $SUMMARY_CSV_FILE
  fi
  kill ${PID}
  exit 0
else
  printf "${RED}FAILURE${NC}: the output of the application does not contain the expected output\n"
  if [ -f "$BUILD_OUTPUT_FILE" ]; then 
    echo `date +%Y%m%d-%H%M`,$EXECUTABLE,ERROR,0,0,0,0,0 > $SUMMARY_CSV_FILE
  fi
  kill ${PID}
  exit 1
fi
