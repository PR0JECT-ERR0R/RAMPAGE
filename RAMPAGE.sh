#!/bin/bash

sudo apk add $(cat /mnt/usb/installed-packages.txt)

LOGFILE="/etc/log/memtest.log"

# Get total RAM size and available CPU cores
RAM_SIZE=$(free -m | awk '/Mem:/ {print $2}')
RAM_SIZE=$(( RAM_SIZE + 0 ))
CPU_CORES=$(nproc)

# Ensure RAM_SIZE is valid
if [[ -z "$RAM_SIZE" || "$RAM_SIZE" -le 200 ]]; then
  echo "Error: Insufficient RAM detected or unable to retrieve memory size." | tee -a "$LOGFILE"
  exit 1
fi

# Allocate only 60% of RAM (to prevent crashes) instead of 80%
TOTAL_TEST_RAM=$(( RAM_SIZE * 60 / 100 ))

# Limit the number of parallel `memtester` instances to 4 (or less)
MAX_PARALLEL_JOBS=4
if [[ "$CPU_CORES" -lt "$MAX_PARALLEL_JOBS" ]]; then
  MAX_PARALLEL_JOBS=$CPU_CORES
fi

# Split available RAM across limited parallel jobs
PER_JOB_RAM=$(( TOTAL_TEST_RAM / MAX_PARALLEL_JOBS ))

echo "Starting Parallel RAM Test on $(date)" | tee -a "$LOGFILE"
echo "Detected RAM: ${RAM_SIZE}MB | Allocating ${TOTAL_TEST_RAM}MB for testing (${PER_JOB_RAM}MB per instance)..." | tee -a "$LOGFILE"

# Run memtester on multiple CPU cores, but limit parallelism
for ((i=0; i<MAX_PARALLEL_JOBS; i++)); do
    sudo -u nobody nice -n -20 memtester "${PER_JOB_RAM}M" 1 2>&1 | tee -a "$LOGFILE" &
    sleep 2  # Small delay to prevent overload
done

# Wait for all tests to complete
wait

echo "RAM Test completed on $(date)" | tee -a "$LOGFILE"
echo "--------------------------" >> "$LOGFILE"

lbu commit -d
