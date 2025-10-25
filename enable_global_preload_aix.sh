#!/bin/sh

#####################################################################################
## The script for enable non-system allocator global preload. AIX version.
##
## Version 1.1
## Written by Y.Voinov (C) 2025
#####################################################################################

# Variables
# Global preload config
PRELOAD_CONF="/etc/environment"
# Allocator library search prefix: from where to find
LIBRARY_PREFIX="/usr/local"
# Set library name to preload
LIBRARY_NAME="*alloc.so"

# Find allocator binary
# We assume that there is only one allocator in a given path and it has a corresponding name pattern.
ALLOCATOR_SYMLINK_PATH_32="`find $LIBRARY_PREFIX -name $LIBRARY_NAME -exec file {} \; | grep 32 | cut -d':' -f1`"
ALLOCATOR_SYMLINK_PATH_64="`find $LIBRARY_PREFIX -name $LIBRARY_NAME -exec file {} \; | grep 64 | cut -d':' -f1`"

# Subroutines
usage_note()
{
  echo "The script for enable non-system allocator global preload."
  echo "Make sure you made emergency boot media before use!"
  echo "Must be run as root."
  echo "Usage: `basename $0` [options]"
  echo "Options:"
  echo "  -n, -N, non-interactive mode for automation"
  exit 0
}

check_os()
{
  if [ "`uname`" != "AIX" ]; then
    echo "ERROR: Unsupported OS."
    exit 1
  fi
}

check_root()
{
  if [ -z "`id | grep 'uid=0(root)'`" ]; then
    echo "ERROR: Must be run as root."
    exit 2
  fi
}

check_symlink()
{
  if [ ! -z "$ALLOCATOR_SYMLINK_PATH_32" -a -f "$ALLOCATOR_SYMLINK_PATH_32" ] && \
     [ ! -z "$ALLOCATOR_SYMLINK_PATH_64" -a -f "$ALLOCATOR_SYMLINK_PATH_64" ]; then
    echo "Allocator 32 bit: `ls $ALLOCATOR_SYMLINK_PATH_32`"
    echo "Allocator 64 bit: `ls $ALLOCATOR_SYMLINK_PATH_64`"
  else
    echo "ERROR: Symlinks to library could not be found. Check allocator installed."
    exit 3
  fi
}

check_enabled() {
  preload_env_32="`cat $PRELOAD_CONF | grep '\-e LDR_PRELOAD' | cut -f2 -d'='`"
  preload_env_64="`cat $PRELOAD_CONF | grep '\-e LDR_PRELOAD_64' | cut -f2 -d'='`"
  if [ ! -z "$preload_env_32" -a ! -z "$preload_env_64" ]; then
    if [ "$preload_env_32" = "$ALLOCATOR_SYMLINK_PATH_32" -a "$preload_env_64" = "$ALLOCATOR_SYMLINK_PATH_64" ]; then
      echo "Allocator $preload_env_32 preloaded."
      echo "Allocator $preload_env_64 preloaded."
      echo "ERROR: Global preload already enabled. Exiting..."
      exit 4
    fi
  else
    echo "Global preload does not enabled."
  fi
}

write_config()
{
  echo "LDR_PRELOAD=$ALLOCATOR_SYMLINK_PATH_32" >> $PRELOAD_CONF
  echo "LDR_PRELOAD64=$ALLOCATOR_SYMLINK_PATH_64" >> $PRELOAD_CONF
}

enable_global_preload()
{
  if [ ! -f $PRELOAD_CONF ]; then
    write_config
    echo "File $PRELOAD_CONF created."
  else
    if [ ! -z "`cat $PRELOAD_CONF | grep $ALLOCATOR_SYMLINK_PATH_32`" -a ! -z "`cat $PRELOAD_CONF | grep $ALLOCATOR_SYMLINK_PATH_64`" ]; then
      cp $PRELOAD_CONF "$PRELOAD_CONF.orig"
      write_config
      echo "File $PRELOAD_CONF updated."
    else
      echo "File $PRELOAD_CONF exists."
      echo "File content: "
      cat $PRELOAD_CONF
      exit 5
    fi
  fi
}

# Main
# Defaults
non_interactive="0"

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

check_os
check_root
check_symlink
check_enabled

if [ "$non_interactive" = "0" ]; then
  if command -v tput >/dev/null 2>&1 && [ -n "`tput colors`" ]; then
    RED_BG="`tput bold; tput setab 1; tput setaf 7`"  # light white on red
    YEL="`tput bold; tput setaf 3`"                   # light yellow
    NC="`tput sgr0`"                                  # reset
  else
    RED_BG=""
    YEL=""
    NC=""
  fi

  echo "${RED_BG}##############################################################################${NC}"
  echo "${RED_BG}##${NC} ${YEL}WARNING!!! BEFORE YOU BEGIN, MAKE SURE YOU HAVE EMERGENCY BOOTABLE MEDIA${NC} ${RED_BG}##${NC}"
  echo "${RED_BG}##${NC} ${YEL}PREPARED! Otherwise, your system may become unbootable.${NC}                  ${RED_BG}##${NC}"
  echo "${RED_BG}##${NC}              Press Y to continue or N/Ctrl+C to cancel.                  ${RED_BG}##${NC}"
  echo "${RED_BG}##############################################################################${NC}"

  while true; do
    IFS= read ans || exit  # Ctrl+C or EOF
    case "$ans" in
      y|Y)
          break
      ;;
      n|N)
          exit
      ;;
      *)
          printf 'Please answer y/Y or n/N\n'
      ;;
    esac
  done
fi

enable_global_preload

echo "${YEL}Completed. Reboot now to apply changes globally.${NC}"

exit 0
