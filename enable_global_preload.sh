#!/bin/sh

#####################################################################################
## The script for enable custom allocator global preload.
##
## Version 1.0
## Written by Y.Voinov (C) 2025
#####################################################################################

# Variables
# Global preload config
PRELOAD_CONF="/etc/ld.so.preload"
# Set bitness for alocator. 64 by default
BITNESS=64
# Allocator library search prefix: from where to find
LIBRARY_PREFIX="/usr/local"
# Set library name to preload
LIBRARY_NAME="*alloc.so"

# Find allocator binary
ALLOCATOR_SYMLINK_PATH=`find $LIBRARY_PREFIX -name $LIBRARY_NAME -exec file {} \; | grep $BITNESS | cut -d":" -f1`

# Subroutines
usage_note()
{
  echo "The script for enable custom allocator global preload."
  echo "Make sure you made emergency boot media before use!"
  echo "Must be run as root."
  echo "Example: `basename $0`"
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

check_symlink()
{
  if [ -z "$ALLOCATOR_SYMLINK_PATH" ]; then
    echo "ERROR: Symlink to library could not be found."
    exit 3
  fi
}

# Main
while [ $# -gt 0 ]; do
  case "$1" in
    -h|-H|\?)
      usage_note
    ;;
    *) shift
    ;;
    esac
done

check_os
check_root
check_symlink

echo "############################################################################"
echo "## WARNING! BEFORE YOU BEGIN, MAKE SURE YOU PREPARE EMERGENCY BOOT MEDIA! ##"
echo "## Otherwise, your system may become unbootable. Press Enter to continue  ##"
echo "## or Ctrl+C to cancel.                                                   ##"
echo "############################################################################"

read p

if [ ! -f $PRELOAD_CONF ]; then
  echo $ALLOCATOR_SYMLINK_PATH >> $PRELOAD_CONF
  echo "File $PRELOAD_CONF created."
  chattr +i $PRELOAD_CONF
else
  if [ ! -z "`cat $PRELOAD_CONF | grep $ALLOCATOR_SYMLINK_PATH`" ]; then
    tmp_buf="`cat $PRELOAD_CONF`"
    chattr -i $PRELOAD_CONF
    echo $ALLOCATOR_SYMLINK_PATH":"$tmp_buf >> $PRELOAD_CONF
    echo "File $PRELOAD_CONF updated."
    chattr +i $PRELOAD_CONF
  else
    echo "File $PRELOAD_CONF exists."
    echo "File content: "
    cat $PRELOAD_CONF
    exit 4
  fi
fi

echo "Completed. Reboot now to apply changes globally."

exit 0
