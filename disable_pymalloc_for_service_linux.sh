#!/bin/sh

#####################################################################################
## The script for disable own Python malloc on Linux per specified systemd service
## Service name specified as script argument (without any suffix, only service name).
## Linux version.
##
## Version 1.0
## Written by Y.Voinov (C) 2026
#####################################################################################

# Variables
PYTHON_BINARY="python3"

# Find libc binary
CONF_FILE_NAME="mt_disable_pymalloc_env.conf"

# Subroutines
usage_note()
{
  echo "The script sets PYTHONMALLOC to use libC on Linux for specified service."
  echo "Must be run as root."
  echo "Usage: `basename $0` <service_name> [options]"
  echo "Options:"
  echo "    -h, -H, ?   show this help"
  echo "Example: `basename $0` tuned"
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

check_service()
{
  if [ ! -z "`systemctl status $SERVICE_NAME | grep 'could not be found.'`" ]; then
    echo "ERROR: Service $SERVICE_NAME could not be found."
    exit 3
  fi
}

disable_preload()
{
  if [ -d /usr/lib/systemd/system/$SERVICE_NAME.service.d ]; then
    echo "Directory /usr/lib/systemd/system/$SERVICE_NAME.service.d found."
    if [ -f /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME ]; then
      rm -f /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME
      rmdir /usr/lib/systemd/system/$SERVICE_NAME.service.d
      if [ ! -d /usr/lib/systemd/system/$SERVICE_NAME.service.d ]; then
        echo "Directory /usr/lib/systemd/system/$SERVICE_NAME.service.d removed."
      fi
    fi
  else
    echo "ERROR: Directory /usr/lib/systemd/system/$SERVICE_NAME.service.d does not exists."
    exit 4
  fi
}

write_file_content()
{
  echo "[Service]" > /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME
  echo "Environment='PYTHONMALLOC=malloc'" >> /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME
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

# Main
if [ -z $1 ]; then
  usage_note
fi

SERVICE_NAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|-H|\?)
      usage_note
    ;;
    *)
    # Accumulate to one string
      if [ -z "$SERVICE_NAME" ]; then
        SERVICE_NAME=$1
      else
        SERVICE_NAME="$SERVICE_NAME $1"
      fi
    ;;
    esac
    shift
done

if [ -z $SERVICE_NAME ]; then
  usage_note
fi

check_os
check_root
check_version
check_service

if [ ! -d /usr/lib/systemd/system/$SERVICE_NAME.service.d ]; then
  mkdir -p /usr/lib/systemd/system/$SERVICE_NAME.service.d/
  echo "Directory /usr/lib/systemd/system/$SERVICE_NAME.service.d created."
else
  echo "Directory /usr/lib/systemd/system/$SERVICE_NAME.service.d exists."
fi

if [ ! -f /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME ]; then
  write_file_content
  echo "File /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME created."
else
  echo "File /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME exists."
  if [ "`grep alloc.so /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME`" ]; then
    # Overwrite file content if drop-in exist
    write_file_content
    echo "File /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME overwrited."
  fi
  echo "New file content:"
  cat /usr/lib/systemd/system/$SERVICE_NAME.service.d/$CONF_FILE_NAME
  exit 4
fi

systemctl daemon-reload
systemctl restart $SERVICE_NAME

echo "Completed for $SERVICE_NAME."

exit 0
