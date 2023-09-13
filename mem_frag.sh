#!/bin/sh

#####################################################################################
## Script to determine memory fragmentation (Linux/SunOS).
##
## Version 1.1
## Modified by Y.Voinov (C) 2023
## Initial written by N.Parfenovich (C) 2023
#####################################################################################

if [ "`uname`" = "Linux" ]; then
  awk '/MemTotal/{total=$2} /MemFree/{free=$2} /Buffers/{buf=$2} /^Cached/{cache=$2} END{printf "Fragmentation level: %.2f%%\n", (1-(free+buf+cache)/total)*100}' /proc/meminfo
elif [ "`uname`" = "SunOS" ]; then
  echo "::memstat" | mdb -k | awk '/Total/{total=$3} /Free (freelist)/{free=$3} /Free (cachelist)/{cache=$3} /Kernel/{kernel=$3} /Anon/{anon=$3} /ZFS File Data/{file=$3} /Exec and libs/{exec=$3} /Page cache/{pcache=$3} END{printf "Fragmentation level: %.2f%%\n", (1-(free+cache+kernel+anon+file+exec+pcache)/total)*100}'
fi
