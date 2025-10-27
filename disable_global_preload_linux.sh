#!/bin/sh

#####################################################################################
## The script for disable non-system allocator global preload. Linux version.
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
  echo "The script for disable non-system allocator global preload."
  echo "Must be run as root."
  echo "Usage: `basename $0` [options]"
  echo "Options:"
  echo "    -h, -H, ?   show this help"
  echo "    -u, -U, ?   unlink hard link if exists"
  echo "    -32         disable 32 bit allocator preload on 32 bit OS"
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

disable_global_preload()
{
  remove_link=$1
  if [ "$remove_link" = "1" ]; then
    get_lib_name="`readlink -f $ALLOCATOR_SYMLINK_PATH`"
    get_dirname="`find /usr -name 'libc.so.*' -exec file {} \; | grep $BITNESS | grep 'ELF' | cut -d: -f1 | { read f && dirname "$f"; }`"
    get_link_name="`basename $get_lib_name | cut -d'.' -f1-3`"
    allocator_link="$get_dirname/$get_link_name"
  else
    allocator_link="$ALLOCATOR_SYMLINK_PATH"
  fi

  if [ -f $PRELOAD_CONF ] && [ -z "`cat $PRELOAD_CONF | grep $allocator_link`" ]; then 
    echo "$PRELOAD_CONF contents: `cat $PRELOAD_CONF`"
    echo "Disabled already or not enabled."
  elif [ -f $PRELOAD_CONF ] && [ ! -z "`cat $PRELOAD_CONF | grep $allocator_link`" ]; then
    chattr -i $PRELOAD_CONF
    mv $PRELOAD_CONF $PRELOAD_CONF.orig
    echo "File $PRELOAD_CONF renamed to $PRELOAD_CONF.orig."
  else
    echo "File $PRELOAD_CONF not exists."
    echo "Disabled already or not enabled."
  fi

  if [ "$remove_link" = "1" ]; then
    if [ -f "$get_dirname/$get_link_name" ]; then
      unlink $get_dirname/$get_link_name
      echo "Hard link $get_dirname/$get_link_name unlinked."
    else
      echo "Hard link $get_dirname/$get_link_name not found."
    fi
  fi
}

# Main
# Defaults
unlink_hard_link="0"

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
      -u|-U)
        unlink_hard_link="1"
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

disable_global_preload $unlink_hard_link

echo "Completed. Reboot now to apply changes globally."

exit 0
