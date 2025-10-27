#!/bin/sh

#####################################################################################
## The script for enable non-system allocator global preload. Linux version.
##
## Version 1.3
## Written by Y.Voinov (C) 2025
#####################################################################################

# Variables
# Global preload config
PRELOAD_CONF="/etc/ld.so.preload"
# Set bitness for allocator. 64 by default
BITNESS=64
# Allocator library search prefix: from where to find
LIBRARY_PREFIX="/usr/local"
# Set library name to preload
LIBRARY_NAME="*alloc.so"

# Find allocator binary
# We assume that there is only one allocator in a given path and it has a corresponding name pattern.
ALLOCATOR_SYMLINK_PATH="`find $LIBRARY_PREFIX -name $LIBRARY_NAME -exec file {} \; | grep $BITNESS | cut -d':' -f1`"

# Subroutines
usage_note()
{
  echo "The script for enable non-system allocator global preload."
  echo "Make sure you made emergency boot media before use!"
  echo "Must be run as root."
  echo "Usage: `basename $0` [options]"
  echo "Options:"
  echo "  -n, -N, non-interactive mode for automation"
  echo "  -l, -L  make hard link in system libs"
  echo "  -32     32 bit allocator preload on 32 bit OS"
  echo
  echo "Note: A hard link to the allocator in the system directory"
  echo "      is required for services restricted by the sandbox."
  exit 0
}

check_os()
{
  if [ "`uname`" != "Linux" ]; then
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

enable_global_preload()
{
  make_link=$1
  if [ "$make_link" = "1" ]; then
    get_lib_name="`readlink -f $ALLOCATOR_SYMLINK_PATH`"
    get_dirname="`find /usr -name 'libc.so.*' -exec file {} \; | grep $BITNESS | grep 'ELF' | cut -d: -f1 | { read f && dirname "$f"; }`"
    get_link_name="`basename $get_lib_name | cut -d'.' -f1-3`"
    # Make hardlink
    if [ ! -f $get_dirname/$get_link_name ]; then
      ln $get_lib_name "$get_dirname/$get_link_name"
      echo "Hard link $get_dirname/$get_link_name created."
    else
      echo "Hard link $get_dirname/$get_link_name already exists."
   fi
    allocator_link="$get_dirname/$get_link_name"
  else
    allocator_link="$ALLOCATOR_SYMLINK_PATH"
  fi

  if [ ! -z "$ALLOCATOR_SYMLINK_PATH" -a -f "$ALLOCATOR_SYMLINK_PATH" ]; then
    echo "Allocator: `ls $ALLOCATOR_SYMLINK_PATH`"
  else
    echo "ERROR: Symlink to library could not be found. Check allocator installed."
    exit 3
  fi

  if [ -f "$PRELOAD_CONF" ] && [ ! -z "`cat $PRELOAD_CONF | grep $ALLOCATOR_SYMLINK_PATH`" ]; then
    echo "$PRELOAD_CONF contents: `cat $PRELOAD_CONF`"
    echo "ERROR: Global preload already enabled. Exiting..."
    exit 4
  fi

  if [ ! -f $PRELOAD_CONF ]; then
    echo $allocator_link >> $PRELOAD_CONF
    echo "File $PRELOAD_CONF created."
    chattr +i $PRELOAD_CONF
  else
    if [ ! -z "`cat $PRELOAD_CONF | grep $allocator_link`" ]; then
      tmp_buf="`cat $PRELOAD_CONF`"
      chattr -i $PRELOAD_CONF
      echo $allocator_link":"$tmp_buf >> $PRELOAD_CONF
      echo "File $PRELOAD_CONF updated."
      chattr +i $PRELOAD_CONF
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
make_hard_link="0"

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
      -l|-L)
        make_hard_link="1"
      ;;
      -32)
        BITNESS=32
      ;;
      *) shift
      ;;
    esac
  done
fi

check_os
check_root

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
    IFS= read -r ans || exit  # Ctrl+C or EOF
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

enable_global_preload $make_hard_link

echo "${YEL}Completed. Reboot now to apply changes globally.${NC}"

exit 0
