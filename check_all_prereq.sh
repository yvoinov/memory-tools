#!/bin/sh

#####################################################################################
## The script checks all prerequisites for custom allocator
##
## Version 1.5
## Written by Y.Voinov (C) 2023-2026
#####################################################################################

# Allocator library search prefix: from where to find
LD_BASE="/usr/local"
# Set library name to find
LIB_NAME="*alloc.so"

# Find allocator lib(s)
# We assume that there is only one allocator in a given path and it has a corresponding name pattern.
ALLOCATOR_PATH="`find $LD_BASE -name $LIB_NAME -exec file {} \; | grep 32 | cut -d':' -f1`"
ALLOCATOR_PATH64="`find $LD_BASE -name $LIB_NAME -exec file {} \; | grep 64 | cut -d':' -f1`"

# sysctl values to check (Linux only)
SYSCTL_FILE_STR1="vm.overcommit_memory"
OVERCOMMIT1="1"
OVERCOMMIT2="2"
# overcommit_ratio at least 70 (must be >=70)
SYSCTL_FILE_STR2="vm.overcommit_ratio"
OVERCOMMIT_RATIO="70"
# vfs_cache_pressure no more 50 (must be <=50)
SYSCTL_FILE_STR3="vm.vfs_cache_pressure"
VFS_CACHE_PRESSURE="50"
# swappiness at least 50 (must be >=50)
SYSCTL_FILE_STR4="vm.swappiness"
SWAPPINESS="50"

verbose="0"

ALL_OK="0"

# Subroutines
usage_note()
{
  echo "The script checks all prerequisites for custom allocator"
  echo "Must be run as root."
  echo "Usage: `basename $0` [options]"
  echo "Options:"
  echo "    -v, -V	     Verbose. Show details."
  echo "    -h, -H, --help   show this help"
  exit 0
}

verbose_output()
{
  if [ "$verbose" = "1" ]; then
    echo .
    echo "$1: $2"
    if [ ! -z "$3" ]; then
      echo "$3: $4"
    fi
  fi
}

check_os()
{
  if [ "`uname`" = "Linux" ]; then
    echo "Linux"
  elif [ "`uname`" = "SunOS" ]; then
    echo "SunOS"
  elif [ "`uname`" = "FreeBSD" ]; then
    echo "FreeBSD"
  else
    echo "ERROR: Unsupported OS."
    exit 1
  fi
}

check_root()
{
  if [ -z "`id | grep 'uid=0(root)'`" ]; then
    echo "ERROR: Must be run as root."
    exit 3
  fi
}

check_lib()
{
  printf "Checking custom allocator installed..."
  if [ "$verbose" = "1" ]; then
    echo .
    if [ -f "$ALLOCATOR_PATH" ]; then
      echo $ALLOCATOR_PATH
    fi
    if [ -f "$ALLOCATOR_PATH64" ]; then
      echo $ALLOCATOR_PATH64
    fi
  fi
  if [ ! -f "$ALLOCATOR_PATH" -a ! -f "$ALLOCATOR_PATH64" ]; then
    echo "NOT OK"
    ALL_OK="1"
  else
    echo "OK"
  fi
}

check_swap()
{
  printf "Checking RAM/swap ratio..."
  if [ "$os" = "SunOS" ]; then
    cmd1="`swap -l | awk -F'[^0-9]*' '$0=$5'`"
    swap_size="`expr $cmd1 \* 512`"
    cmd2=`prtconf | grep Memory | awk '{ print $3 }'`
    ram_size="`expr $cmd2 \* 1024 \* 1024`"
  elif [ "$os" = "Linux" ]; then
    swap_size=`free --kilo | grep Swap | awk '{ print $2 }'`
    ram_size="`grep MemTotal /proc/meminfo | awk '{ print $2 }'`"
  elif [ "$os" =  "FreeBSD" ]; then
    cmd1="`swapinfo | grep swapfs | awk '{print $2}'`"
    swap_size="`expr $cmd1 \* 1024`"
    ram_size="`sysctl hw.physmem | awk '{ print $2 }'`"
  fi
  verbose_output "RAM size " "$ram_size" "Swap size" "$swap_size"
  if [ "$swap_size" -ge "$ram_size" ]; then
    echo "OK"
  else
    echo "NOT OK"
    ALL_OK="1"
  fi
}

check_thp()
{
  printf "Checking THP status..."
  cmd="`sysctl vm.nr_hugepages | awk '{ print $3 }'`"
  verbose_output "THP" "$cmd"
  if [ "$cmd" = "0" ]; then
    echo "OK"
  else
    echo "NOT OK"
    ALL_OK="1"
  fi
}

check_recommended_vm_settings()
{
  printf "Checking overcommit status..."
  cmd1="`sysctl $SYSCTL_FILE_STR1 | cut -d' ' -f3`"
  verbose_output "Acceptable values" "$OVERCOMMIT1 $OVERCOMMIT2" "Specified value" "$cmd1"
  if [ "$cmd1" = "$OVERCOMMIT2" ] || [ "$cmd1" = "$OVERCOMMIT1" ]; then
    echo "OK"
  else
    echo "NOT OK"
    ALL_OK="1"
  fi
  printf "Checking overcommit ratio..."
  cmd2="`sysctl $SYSCTL_FILE_STR2 | cut -d' ' -f3`"
  verbose_output "Acceptable values" "$OVERCOMMIT_RATIO" "Specified value" "$cmd2"
  if [ "$cmd2" -ge "$OVERCOMMIT_RATIO" ]; then
    echo "OK"
  else
    echo "NOT OK"
    ALL_OK="1"
  fi
  printf "Checking vfs_cache_pressure..."
  cmd3="`sysctl $SYSCTL_FILE_STR3 | cut -d' ' -f3`"
  verbose_output "Acceptable values" "$VFS_CACHE_PRESSURE" "Specified value" "$cmd3"
  if [ "$cmd3" -le "$VFS_CACHE_PRESSURE" ]; then
    echo "OK"
  else
    echo "NOT OK"
    ALL_OK="1"
  fi
  printf "Checking swappiness..."
  cmd4="`sysctl $SYSCTL_FILE_STR4 | cut -d' ' -f3`"
  verbose_output "Acceptable values" "$SWAPPINESS" "Specified value" "$cmd4"
  if [ "$cmd4" -ge "$SWAPPINESS" ]; then
    echo "OK"
  else
    echo "NOT OK"
    ALL_OK="1"
  fi
}

check_ld_conditions()
{
  printf "Checking LD.SO conditions..."
  res="0"
  if [ "$os" = "SunOS" ]; then
    if [ ! -z "`crle | grep $ALLOCATOR_PATH`" -a ! -z "`crle -64 | grep $ALLOCATOR_PATH64`" ]; then
      res=1
    fi
  elif [ "$os" = "Linux" ]; then
    dir1="`dirname $ALLOCATOR_PATH 2>/dev/null`"
    dir2="`dirname $ALLOCATOR_PATH64 2>/dev/null`"
    if [ ! -z "`ldconfig -p | grep $dir1 2>/dev/null`" -o ! -z "`ldconfig -p | grep $dir2 2>/dev/null`" ]; then
      res=1
    fi
  elif [ "$os" = "FreeBSD" ]; then
    dir1="`dirname $ALLOCATOR_PATH 2>/dev/null`"
    dir2="`dirname $ALLOCATOR_PATH64 2>/dev/null`"
    if [ ! -z "`ldconfig -r | grep $dir1 2>/dev/null`" -o ! -z "`ldconfig -r | grep $dir2 2>/dev/null`" ]; then
      res=1
    fi
  fi
  verbose_output "LD.SO prerequisites" "$res"
  if [ "$res" = "1" ]; then
    echo "OK"
  else
    echo "NOT OK"
    ALL_OK="1"
  fi
}

# Main
 # Parse command line
if [ "x$*" != "x" ]; then
  arg_list=$*
  # Read arguments
  for i in $arg_list
  do
    case $i in
     -v|-V) verbose="1"
     ;;
     -h|-H|--help) usage_note
     ;;
     *) shift
     ;;
    esac
  done
fi

# Get OS once
os="`check_os`"

# Global checks
check_root
check_lib
check_swap

# Prerequisites & recommendations
check_ld_conditions
if [ "$os" = "Linux" ]; then
  check_thp
  check_recommended_vm_settings
fi

printf "Done. "

if [ "$ALL_OK" = "0" ]; then
  echo "All prerequisites OK."
  exit 0
else
  echo "Any/all prerequisites NOT OK."
  if [ "$verbose" = "0" ]; then
    echo "Run in verbose mode to see details."
  fi
  exit 1
fi
