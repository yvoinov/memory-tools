#!/bin/sh

#####################################################################################
## The script checks all prerequisites for LMA
##
## Version 1.0
## Written by Y.Voinov (C) 2023
#####################################################################################

# LMA paths. Change if installed different base.
LIB_NAME_BASE="ltalloc"
LD_BASE="/usr/local"
LD_PATH1="$LD_BASE/lib/$LIB_NAME_BASE"
LD_PATH2="$LD_BASE/lib/$LIB_NAME_BASE/64"

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
# swappiness at least 30 (must be >=30)
SYSCTL_FILE_STR4="vm.swappiness"
SWAPPINESS="30"

# Subroutines
usage_note()
{
 echo "The script checks all prerequisites for LMA"
 echo "Must be run as root."
 echo "Example: `basename $0`"
 exit 0
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
  printf "Checking LMA installed..."
  if [ ! -f $LD_PATH1/"lib"$LIB_NAME_BASE".so" -a ! -f $LD_PATH2/"lib"$LIB_NAME_BASE".so" ]; then
    echo "NOT OK"
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
  if [ "$swap_size" -ge "$ram_size" ]; then
    echo "OK"
  else
    echo "NOT OK"
  fi
}

check_thp()
{
  printf "Checking THP status..."
  cmd="`sysctl vm.nr_hugepages | awk '{ print $3 }'`"
  if [ "$cmd" = "0" ]; then
    echo "OK"
  else
    echo "NOT OK"
  fi
}

check_recommended_vm_settings()
{
  printf "Checking overcommit status..."
  cmd1="`sysctl $SYSCTL_FILE_STR1 | cut -d' ' -f3`"
  if [ "$cmd1" = "$OVERCOMMIT2" ] || [ "$cmd1" = "$OVERCOMMIT1" ]; then
    echo "OK"
  else
    echo "NOT OK"
  fi
  printf "Checking overcommit ratio..."
  cmd2="`sysctl $SYSCTL_FILE_STR2 | cut -d' ' -f3`"
  if [ "$cmd2" -ge "$OVERCOMMIT_RATIO" ]; then
    echo "OK"
  else
    echo "NOT OK"
  fi
  printf "Checking vfs_cache_pressure..."
  cmd3="`sysctl $SYSCTL_FILE_STR3 | cut -d' ' -f3`"
  if [ "$cmd3" -le "$VFS_CACHE_PRESSURE" ]; then
    echo "OK"
  else
    echo "NOT OK"
  fi
  printf "Checking swappiness..."
  cmd3="`sysctl $SYSCTL_FILE_STR4 | cut -d' ' -f3`"
  if [ "$cmd3" -ge "$SWAPPINESS" ]; then
    echo "OK"
  else
    echo "NOT OK"
  fi
}

check_ld_conditions()
{
  printf "Checking LD.SO conditions..."
  res="0"
  if [ "$os" = "SunOS" ]; then
    if [ ! -z "`crle | grep $LD_PATH1`" -a ! -z "`crle -64 | grep $LD_PATH2`" ]; then
      res=1
    fi
  elif [ "$os" = "Linux" ]; then
    if [ ! -z "`ldconfig -p | grep $LIB_NAME_BASE`" ]; then
      res=1
    fi
  elif [ "$os" = "FreeBSD" ]; then
    if [ ! -z "`ldconfig -r | grep $LIB_NAME_BASE`" ]; then
      res=1
    fi
  fi
  if [ "$res" = "1" ]; then
    echo "OK"
  else
    echo "NOT OK"
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
     -h|-H|\?) usage_note;;
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

echo "Done."
exit 0
