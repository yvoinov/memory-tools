#!/bin/sh

#####################################################################################
## Script to determine memory fragmentation (Linux only).
## 
## Version 1.0
## Modified by Y.Voinov (C) 2023
## Initial written by N.Parfenovich (C) 2023
#####################################################################################

check_os()
{
  if [ "`uname`" != "Linux" ]; then
    echo "ERROR: This script is for Linux only."
    exit 2
  fi
}

check_os

awk '/MemTotal/{total=$2} /MemFree/{free=$2} /Buffers/{buf=$2} /^Cached/{cache=$2} END{printf "Fragmentation level: %.2f%%\n", (1-(free+buf+cache)/total)*100}' /proc/meminfo
