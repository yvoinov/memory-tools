#!/bin/sh

#####################################################################################
## The script intended to disable own Python malloc on Linux.
## It sets PYTHONMALLOC to use libC. This require when using custom allocators to
## prevent segfaults.
##
## Version 1.3
## Written by Y.Voinov (C) 2022-2024
#####################################################################################

# Global environment file
GLOBAL_ENV="/etc/environment"

# Subroutines
usage_note()
{
 echo "The script sets PYTHONMALLOC to use libC on Linux."
 echo "Just run it and reboot system. Must be run as root."
 echo "Example: `basename $0` && reboot"
 exit 0
}

check_os()
{
  if [ "`uname`" != "Linux" ]; then
    echo "ERROR: This script is for Linux only."
    exit 2
  fi
}

check_root()
{
  if [ -z "`id | grep 'uid=0(root)'`" ]; then
    echo "ERROR: Must be run as root."
    exit 3
  fi
}

check_version()
{
  py_exec="`whereis python | awk '{ print $2 }'`"

  if [ -z "$py_exec" ]; then
    echo "ERROR: Python not found. Exiting..."
    exit 4
  fi

  py_ver="`$py_exec -V 2>&1 | awk '{print $2}'`"

  py_ver_major="`echo $py_ver | cut -f1 -d'.'`"
  py_ver_minor="`echo $py_ver | cut -f1 -d'.'`"

  if [ "$py_ver_major" -ge "3" -a "$py_ver_minor" -ge "6" ]; then
    echo "ERROR: PYTHONMALLOC only supported from 3.6."
    exit 5
  fi
}

check_os
check_root
check_version

if [ -f "$GLOBAL_ENV" ]; then
  value="`cat $GLOBAL_ENV | grep PYTHONMALLOC`"
  if [ ! -z "$value" ]; then
    echo "ERROR: $value already set."
    exit 1
  fi
  echo "PYTHONMALLOC='malloc'" >> $GLOBAL_ENV
else
  echo "ERROR: File $GLOBAL_ENV not found. Exiting..."
  exit 1
fi

echo "Done. Please reboot this system now."
exit 0
