#!/bin/sh

#####################################################################################
## Script to determine memory fragmentation estimate (Linux/Solaris).
##
## Version 1.3
## Modified by Y.Voinov (C) 2023-2026
## Initial written by N.Parfenovich (C) 2023
#####################################################################################

percent=""
non_interactive="0"

usage_note()
{
  echo "The script to get system memory fragmentation estimate."
  echo "Must be run as root or equivalent."
  echo "Usage: `basename $0` [options]"
  echo "Options:"
  echo "  -n, -N, non-interactive mode for automation or monitoring"
  echo
  exit 0
}

# Parse command line
if [ "x$*" != "x" ]; then
  arg_list=$*
  # Read arguments
  for i in $arg_list
  do
    case $i in
      -h|-H|\?)
        usage_note
      ;;
      -n|-N)
        non_interactive="1"
      ;;
      *) shift
      ;;
    esac
  done
fi

if [ "$non_interactive" = "0" ]; then
  percent="%"
fi

if [ "`uname`" = "Linux" ]; then
  awk '/MemTotal/{total=$2} /MemFree/{free=$2} /Buffers/{buf=$2} /^Cached/{cache=$2} END{printf "%.2f'$percent'\n", (1-(free+buf+cache)/total)*100}' /proc/meminfo
elif [ "`uname`" = "SunOS" ]; then
  if [ -z "`id | grep 'uid=0(root)'`" ]; then
    echo "ERROR: Must be run as root."
    exit 1
  fi
  echo "::memstat" | mdb -k | awk '/Total/{total=$3} /Free (freelist)/{free=$3} /Free (cachelist)/{cache=$3} /Kernel/{kernel=$3} /Anon/{anon=$3} /ZFS File Data/{file=$3} /Exec and libs/{exec=$3} /Page cache/{pcache=$3} END{printf "%.2f'$percent'\n", (1-(free+cache+kernel+anon+file+exec+pcache)/total)*100}'
fi
