#!/bin/sh

#####################################################################################
## The script checks all prerequisites for custom allocator
##
## Version 2.0
## Written by Y.Voinov (C) 2023-2026
#####################################################################################

# Allocator library search prefix: change if installed different base.
LD_BASE="/usr/local"

# Set library name to find
LIB_NAME="*alloc.so"

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
  echo "The script checks all prerequisites for custom allocator."
  echo "Must be run as root."
  echo "Usage: `basename $0` [options]"
  echo "Options:"
  echo "    -b, --base         override allocator base directory"
  echo "    -v, -V             Verbose. Show details."
  echo "    -h, -H, --help     show this help"
  exit 0
}

verbose_output()
{
  if [ "$verbose" = "1" ]; then
    echo .
    echo "$1"
    echo "$2: $3"
    if [ ! -z "$4" ]; then
      echo "$4: $5"
    fi
  fi
}

log_ok()
{
  printf "[OK] %s\n" "$*"
}

log_nok()
{
  printf "[NOT OK] %s\n" "$*" >&2
}

log_info()
{
  printf "[INFO] %s\n" "$*" >&2
}

log_error()
{
  printf "[ERROR] %s\n" "$*" >&2
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
    log_error "Unsupported OS"
    exit 1
  fi
}

check_root()
{
  if [ -z "`id | grep 'uid=0(root)'`" ]; then
    log_error "Must be run as root"
    exit 3
  fi
  log_ok "Running as root"
}

check_lib()
{
  # Find allocator lib(s)
  # We assume that there is at least one allocator in a given path
  # and it has a corresponding name pattern.
  ALLOCATOR_PATH32="`find $LD_BASE -name $LIB_NAME -exec env POSIXLY_CORRECT=1 file {} \; | grep 32 | cut -d':' -f1`"
  ALLOCATOR_PATH64="`find $LD_BASE -name $LIB_NAME -exec env POSIXLY_CORRECT=1 file {} \; | grep 64 | cut -d':' -f1`"

  if [ "$verbose" = "1" ]; then
    echo "Checking custom allocator installed..."
    echo .
    echo "ALLOCATOR_PATH32:"
    if [ -z "$ALLOCATOR_PATH32" ]; then
      echo "<not found>"
    else
      echo "$ALLOCATOR_PATH32"
    fi
    echo "ALLOCATOR_PATH64:"
    if [ -z "$ALLOCATOR_PATH64" ]; then
      echo "<not found>"
    else
      echo "$ALLOCATOR_PATH64"
    fi
  fi

  if [ -z "$ALLOCATOR_PATH32" -o -z "$ALLOCATOR_PATH64" ]; then
    log_nok "Allocator not found"
    ALL_OK="1"
    return
  fi

  log_ok "Allocator found"

  allocator_count="0"

  if [ ! -z "$ALLOCATOR_PATH32" ]; then
    count="`echo "$ALLOCATOR_PATH32" | wc -l | sed 's/[ ]*//g'`"
    allocator_count="`expr $allocator_count + $count`"
  fi

  if [ ! -z "$ALLOCATOR_PATH64" ]; then
    count="`echo "$ALLOCATOR_PATH64" | wc -l | sed 's/[ ]*//g'`"
    allocator_count="`expr $allocator_count + $count`"
  fi

  if [ "$allocator_count" -gt 1 ]; then
    log_info "Multiple allocator libraries found: $allocator_count"
    log_info "Check ALLOCATOR_PATH32/ALLOCATOR_PATH64 in verbose mode"
  fi
}

check_swap()
{
  if [ "$os" = "SunOS" ]; then
    cmd1="`swap -l | awk -F'[^0-9]*' '$0=$5'`"
    swap_size="`expr $cmd1 \* 512`"
    cmd2="`prtconf | grep Memory | awk '{ print $3 }'`"
    ram_size="`expr $cmd2 \* 1024 \* 1024`"
  elif [ "$os" = "Linux" ]; then
    swap_size=`free --kilo | grep Swap | awk '{ print $2 }'`
    ram_size="`grep MemTotal /proc/meminfo | awk '{ print $2 }'`"
  elif [ "$os" = "FreeBSD" ]; then
    cmd1="`swapinfo | grep swapfs | awk '{print $2}'`"
    swap_size="`expr $cmd1 \* 1024`"
    ram_size="`sysctl hw.physmem | awk '{ print $2 }'`"
  fi
  verbose_output "Checking RAM/swap ratio..." "RAM size " "$ram_size" "Swap size" "$swap_size"
  if [ "$swap_size" -ge "$ram_size" ]; then
    log_ok "RAM/swap ratio"
  else
    log_nok "Insufficient RAM/swap ratio"
    ALL_OK="1"
  fi
}

check_thp()
{
  cmd="`sysctl vm.nr_hugepages | awk '{ print $3 }'`"
  verbose_output "Checking THP status..." "THP" "$cmd"
  if [ "$cmd" = "0" ]; then
    log_ok "THP disabled"
  else
    log_nok "THP still enabled"
    ALL_OK="1"
  fi
}

check_recommended_vm_settings()
{
  cmd1="`sysctl $SYSCTL_FILE_STR1 | cut -d' ' -f3`"
  verbose_output "Checking status $SYSCTL_FILE_STR1..." "Acceptable values" "$OVERCOMMIT1 $OVERCOMMIT2" "Specified value" "$cmd1"
  if [ "$cmd1" = "$OVERCOMMIT2" ] || [ "$cmd1" = "$OVERCOMMIT1" ]; then
    log_ok "Overcommit disabled"
  else
    log_nok "Overcommit still enabled"
    ALL_OK="1"
  fi

  cmd2="`sysctl $SYSCTL_FILE_STR2 | cut -d' ' -f3`"
  verbose_output "Checking $SYSCTL_FILE_STR2..." "Acceptable values" "$OVERCOMMIT_RATIO" "Specified value" "$cmd2"
  if [ "$cmd2" -ge "$OVERCOMMIT_RATIO" ]; then
    log_ok "$SYSCTL_FILE_STR2"
  else
    log_nok "$SYSCTL_FILE_STR2"
    ALL_OK="1"
  fi

  cmd3="`sysctl $SYSCTL_FILE_STR3 | cut -d' ' -f3`"
  verbose_output "Checking $SYSCTL_FILE_STR3..." "Acceptable values" "$VFS_CACHE_PRESSURE" "Specified value" "$cmd3"
  if [ "$cmd3" -le "$VFS_CACHE_PRESSURE" ]; then
    log_ok "$SYSCTL_FILE_STR3"
  else
    log_nok "$SYSCTL_FILE_STR3"
    ALL_OK="1"
  fi

  cmd4="`sysctl $SYSCTL_FILE_STR4 | cut -d' ' -f3`"
  verbose_output "Checking $SYSCTL_FILE_STR4..." "Acceptable values" "$SWAPPINESS" "Specified value" "$cmd4"
  if [ "$cmd4" -ge "$SWAPPINESS" ]; then
    log_ok "$SYSCTL_FILE_STR4"
  else
    log_nok "$SYSCTL_FILE_STR4"
    ALL_OK="1"
  fi
}

check_ld_conditions()
{
  res="0"
  ld_matches=""
  ld_matches64=""

  if [ "$os" = "SunOS" ]; then
    ld_matches="`crle | grep 'alloc.so'`"
    ld_matches64="`crle -64 | grep 'alloc.so'`"
    if [ ! -z "$ld_matches" -o ! -z "$ld_matches64" ]; then
    res="1"
    fi
  elif [ "$os" = "Linux" ]; then
    ld_matches="`ldconfig -p | grep 'alloc.so' 2>/dev/null`"
    if [ ! -z "$ld_matches" ]; then
      res="1"
    fi
  elif [ "$os" = "FreeBSD" ]; then
    ld_matches="`ldconfig -r | grep 'alloc.so' 2>/dev/null`"
    if [ ! -z "$ld_matches" ]; then
      res="1"
    fi
  fi

  if [ "$verbose" = "1" ]; then
    echo .
    echo "Checking LD.SO conditions..."
    if [ "$os" = "SunOS" ]; then
      echo "LD.SO 32-bit:"
      if [ -z "$ld_matches" ]; then
        echo "<no allocator>"
      else
        echo "$ld_matches"
      fi
      echo "LD.SO 64-bit:"
      if [ -z "$ld_matches64" ]; then
        echo "<no allocator>"
      else
        echo "$ld_matches64"
      fi
    else
      echo "LD.SO:"
      if [ -z "$ld_matches" ]; then
        echo "<no allocator>"
      else
        echo "$ld_matches"
      fi
    fi
  fi

  if [ "$res" = "1" ]; then
    log_ok "LD.SO prerequisites"
  else
    log_nok "LD.SO prerequisites"
    ALL_OK="1"
  fi
}

# Main

# Parse command line
if [ "x$*" != "x" ]; then
  arg_list=$*

  for i in $arg_list
  do
    case $i in
      -v|-V)
        verbose="1"
      ;;
      -h|-H|--help)
        usage_note
      ;;
      -b|--base)
        shift
        if [ -z "$1" ]; then
          log_error "Option $i requires an argument"
          exit 2
        fi
        LD_BASE="$1"
        ;;
      -b=*|--base=*)
        LD_BASE="`echo "$i" | sed 's/^[^=]*=//'`"
        ;;
      *)
        shift
      ;;
    esac
  done
fi

log_info "LD_BASE=$LD_BASE"

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

log_ok "Done"

if [ "$ALL_OK" = "0" ]; then
  log_ok "All prerequisites OK"
  exit 0
else
  log_info "Any/all prerequisites NOT OK"
  if [ "$verbose" = "0" ]; then
    log_info "Run in verbose mode to see details"
  fi
  exit 1
fi
