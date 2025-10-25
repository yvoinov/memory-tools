#!/bin/sh

#####################################################################################
## The script for disable non-system allocator global preload. Solaris version.
##
## Version 1.1
## Written by Y.Voinov (C) 2025
#####################################################################################

# Variables
# Global preload configs
PRELOAD_CONF_32="/var/ld/ld.config"
PRELOAD_CONF_64="/var/ld/64/ld.config"
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
  echo "The script for disable non-system allocator global preload."
  echo "Must be run as root."
  echo "Usage: `basename $0` [options]"
  echo "Options:"
  echo "    -c, -C	Clears configs if previous ones were not saved."
  echo "                This means that there were no configurations"
  echo"                 other than the default."
  echo "    -h, -H, ?   show this help"
  exit 0
}

check_os()
{
  if [ "`uname`" != "SunOS" ]; then
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
  if [ ! -z "$ALLOCATOR_SYMLINK_PATH_32" -a -f "$ALLOCATOR_SYMLINK_PATH_32" ] \
  -a [ ! -z "$ALLOCATOR_SYMLINK_PATH_64" -a -f "$ALLOCATOR_SYMLINK_PATH_64" ]; then
    echo "Allocator 32 bit: `ls $ALLOCATOR_SYMLINK_PATH_32`"
    echo "Allocator 64 bit: `ls $ALLOCATOR_SYMLINK_PATH_64`"
  else
    echo "ERROR: Symlinks to library could not be found. Nothing to disable."
    exit 3
  fi
}

check_ld_config_32() {
  if [ -f "$PRELOAD_CONF_32" ]; then
    echo "1"
  else
    echo "0"
  fi
}

check_ld_config_64() {
  if [ -f "$PRELOAD_CONF_64" ]; then
    echo "1"
  else
    echo "0"
  fi
}

check_enabled() {
  preload_env_32="`crle | grep '\-e LD_PRELOAD_32' | cut -f2 -d'=' | grep -v 'replaceable'`"
  preload_env_64="`crle -64 | grep '\-e LD_PRELOAD_64' | cut -f2 -d'=' | grep -v 'replaceable'`"
  if [ "`check_ld_config_32`" = "1" -o ! -z "$preload_env_32" -o "`check_ld_config_64`" = "1" -o ! -z "$preload_env_64" ]; then
    if [ "$preload_env_32" = "$ALLOCATOR_SYMLINK_PATH_32" -a "$preload_env_64" = "$ALLOCATOR_SYMLINK_PATH_64" ]; then
      echo "Allocator $preload_env_32 preloaded."
      echo "Allocator $preload_env_64 preloaded."
    fi
  else
    echo "ERROR: Global preload does not enabled."
    exit 4
  fi
}

disable_global_preload()
{
  cleanup_requested=$1
  if [ "`check_ld_config_32`" = "1" ]; then
    # Get current libraries paths
    default_search_path_32="`crle 2>/dev/null | grep 'Default Library Path' | sed 's/^[^:]*:[ 	]*//; s/[ 	]*(.*)//; s/[ 	]*$//'`"
    secure_lib_search_path_32="`crle 2>/dev/null | grep 'Trusted Directories' | sed 's/^[^:]*:[ 	]*//; s/[ 	]*(.*)//; s/[ 	]*$//'`"
    # Disable global preload
    crle -c $PRELOAD_CONF_32 -l $default_search_path_32 -s $secure_lib_search_path_32
  elif [ "`check_ld_config_64`" = "1" ]; then
    default_search_path_64="`crle -64 2>/dev/null | grep 'Default Library Path' | sed 's/^[^:]*:[ 	]*//; s/[ 	]*(.*)//; s/[ 	]*$//'`"
    secure_lib_search_path_64="`crle -64 2>/dev/null | grep 'Trusted Directories' | sed 's/^[^:]*:[ 	]*//; s/[ 	]*(.*)//; s/[ 	]*$//'`"
    crle -64 -c $PRELOAD_CONF_64 -l $default_search_path_64 -s $secure_lib_search_path_64
  fi
  if [ "$cleanup_requested" = "1" ]; then
    # If no saved previous config, just remove ld.config with backup
    if [ -f "$PRELOAD_CONF_32.orig" ]; then
      mv "$PRELOAD_CONF_32.orig" "$PRELOAD_CONF_32"
    else
      cp "$PRELOAD_CONF_32" "$PRELOAD_CONF_32.backup"
      rm -f "$PRELOAD_CONF_32"
    fi
    if [ -f "$PRELOAD_CONF_64.orig" ]; then
      mv "$PRELOAD_CONF_64.orig" "$PRELOAD_CONF_64"
    else
      cp "$PRELOAD_CONF_64" "$PRELOAD_CONF_64.backup"
      rm -f "$PRELOAD_CONF_64"
    fi
  fi
}

# Main
# Defaults
cleanup_configs="0"

while [ $# -gt 0 ]; do
  case "$1" in
    -h|-H|\?)
      usage_note
    ;;
    -c|-C)
      cleanup_configs="1"
    ;;
    *) shift
    ;;
    esac
done

check_os
check_root
check_enabled
disable_global_preload $cleanup_configs

echo "Completed. Reboot now to apply changes globally."

exit 0
