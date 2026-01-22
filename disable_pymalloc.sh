#!/bin/sh

#####################################################################################
## The script intended to enable/disable own Python malloc on Linux for userland.
##
## Version 1.5
## Written by Y.Voinov (C) 2022-2026
#####################################################################################

# Variables
PYTHON_BINARY="python3"

# Global environment file
GLOBAL_ENV="/etc/environment"

# Environment
ENV_VALUE="PYTHONMALLOC=malloc"

# Subroutines
usage_note()
{
  echo "The script sets PYTHONMALLOC to use libC on Linux."
  echo "Just run it and re-login system. Must be run as root."
  echo "Usage: `basename $0` [options]"
  echo "Options:"
  echo "    -h, -H, ?   show this help"
  echo "    -d, -D      disable libC PYTHONMALLOC in $GLOBAL_ENV"
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
  py_exec="`whereis $PYTHON_BINARY | awk '{ print $2 }'`"

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

# Defaults
disable_libc="0"

while [ $# -gt 0 ]; do
  case "$1" in
    -h|-H|\?)
      usage_note
    ;;
    -d|-D)
      disable_libc="1"
    ;;
    *)
      shift
    ;;
    esac
    shift
done

check_os
check_root
check_version

if [ "$disable_libc" = "0" ]; then
  if [ -f "$GLOBAL_ENV" ]; then
    value="`cat $GLOBAL_ENV | grep PYTHONMALLOC`"
    if [ ! -z "$value" ]; then
      echo "ERROR: $value already set."
      exit 1
    fi
    echo $ENV_VALUE >> $GLOBAL_ENV
  else
    echo "ERROR: File $GLOBAL_ENV not found. Exiting..."
    exit 1
  fi
else
  value="`cat $GLOBAL_ENV | grep $ENV_VALUE`"
  if [ ! -z "$value" ]; then
    tmp_file=`mktemp`
    sed -i '/$ENV_VALUE/d' $GLOBAL_ENV > $tmp_file && mv $tmp_file $GLOBAL_ENV
    echo "INFO: $ENV_VALUE deleted."
  fi
fi

echo "Done. Please re-login now."
exit 0
