#!/bin/bash

LOGFILE="/etc/logs/RAMPAGE.log"

echo "===== ECC RAM Test Started on $(date) =====" | tee -a "$LOGFILE"

# Get total RAM size
RAM_SIZE=$(free -m | awk '/Mem:/ {print $2}')
RAM_SIZE=$(($RAM_SIZE + 0 ))

# Ensure RAM is detected
if [[ -z "$RAM_SIZE" || "$RAM_SIZE" -le 200 ]]; then
  echo "Error: Unable to retrieve memory size or insufficient RAM detected." | tee -a "$LOGFILE"
  exit 1
fi

# Allocate 80% of RAM for testing
TEST_RAM=$(($RAM_SIZE * 70 / 100 ))

echo "Testing ${TEST_RAM}MB RAM using memtester..." | tee -a "$LOGFILE"

# Run memtester and log results
sudo memtester "${TEST_RAM}M" 1 2>&1 | tee -a "$LOGFILE"

echo "Checking ECC error logs..." | tee -a "$LOGFILE"

# List all memory controllers
EDAC_PATH="/sys/devices/system/edac/mc/"
MC_CONTROLLERS=$(ls "$EDAC_PATH" 2>/dev/null)

if [[ -z "$MC_CONTROLLERS" ]]; then
  echo "No EDAC memory controllers found. ECC monitoring may not be available." | tee -a "$LOGFILE"
else
  for mc in $MC_CONTROLLERS; do
    echo "Checking $mc for ECC errors..." | tee -a "$LOGFILE"
    
    # Get ECC error counts
    CE_COUNT=$(cat "$EDAC_PATH/$mc/ce_count" 2>/dev/null)
    UE_COUNT=$(cat "$EDAC_PATH/$mc/ue_count" 2>/dev/null)

    echo "Corrected Errors: $CE_COUNT | Uncorrectable Errors: $UE_COUNT" | tee -a "$LOGFILE"

    # If errors are found, list faulty DIMMs
    if [[ "$CE_COUNT" -gt 0 || "$UE_COUNT" -gt 0 ]]; then
      echo "Faulty RAM Detected! Checking affected DIMM slots..." | tee -a "$LOGFILE"
      
      grep . "$EDAC_PATH/$mc/csrow"*/ce_count 2>/dev/null | while read -r line; do
        ROW=$(echo "$line" | cut -d '/' -f 6 | cut -d 'w' -f 2)
        ERRORS=$(echo "$line" | awk '{print $NF}')
        echo "DIMM Slot csrow$ROW has $ERRORS ECC errors." | tee -a "$LOGFILE"
      done
    fi
  done
fi

echo "Mapping DIMM slots to physical hardware..." | tee -a "$LOGFILE"

# Get physical memory slots using dmidecode
sudo dmidecode --type memory | tee -a "$LOGFILE"

echo "===== ECC RAM Test Completed on $(date) =====" | tee -a "$LOGFILE"

