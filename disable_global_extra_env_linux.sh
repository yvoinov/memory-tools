#!/bin/sh

#####################################################################################
## The script for disable extra env drop-ins for all running systemd services.
## This script was written to workaround the lack of a global environment for systemd
## services.
## Linux version.
##
## Version 1.0
## Written by Y.Voinov (C) 2026
#####################################################################################

# Variables

# Drop-in directory
DROP_IN_DIR="/usr/lib/systemd/system"

# Drop-in extra env
CONF_EXTRA_ENV_FILE="mt_extra_env.conf"

# Subroutines
usage_note()
{
  echo "The script for disable all enabled extra env drop-ins for all running systemd services."
  echo "Must be run as root."
  echo "Usage: `basename $0` [options]"
  echo "Options:"
  echo "    -h, -H, ?   show this help"
  echo ""
  echo "Note: All extra env configs with filename $CONF_EXTRA_ENV_FILE will be removed."
  exit 0
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

remove_drop_in()
{
  file_name=$1

  drop_in_dir=`dirname $file_name`
  file_name=`basename $file_name`
  if [ -d $drop_in_dir ]; then
    echo "Directory $drop_in_dir found."
    if [ -f $drop_in_dir/$file_name ]; then
      rm -f $drop_in_dir/$file_name
      echo "File $drop_in_dir/$file_name removed."
      rmdir $drop_in_dir
      if [ ! -d $drop_in_dir ]; then
        echo "Directory $drop_in_dir removed."
      fi
    fi
  else
    echo "ERROR: Directory $drop_in_dir does not exists."
    exit 4
  fi
  systemctl daemon-reload
}

# Main
while [ $# -gt 0 ]; do
  case "$1" in
    -h|-H|\?)
      usage_note
    ;;
    *)
      usage_note
    ;;
    esac
    shift
done

check_os
check_root

drop_in_files=`find $DROP_IN_DIR -name $CONF_EXTRA_ENV_FILE`

for fname in $drop_in_files; do
  remove_drop_in $fname
done

echo "Completed. Reboot system."

exit 0
