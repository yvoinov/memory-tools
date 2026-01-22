#!/bin/sh

#####################################################################################
## The script for enable/disable own Python malloc on Linux per specified systemd
## service.
## Service name specified as script argument (without any suffix, only service name).
## Linux version.
##
## Version 1.1
## Written by Y.Voinov (C) 2026
#####################################################################################

# Variables
PYTHON_BINARY="python3"

# Drop-in file name
CONF_FILE_NAME="mt_disable_pymalloc_env.conf"

# Drop-in directory
DROP_IN_DIR="/usr/lib/systemd/system"

# Subroutines
usage_note()
{
  echo "The script enable/disable PYTHONMALLOC to use libC on Linux for specified service."
  echo "Must be run as root."
  echo "Usage: `basename $0` <service_name> [options]"
  echo "Options:"
  echo "    -h, -H, ?   show this help"
  echo "    -d, -D      disable libC PYTHONMALLOC and delete drop-in"
  echo "Example 1 (enable using libC malloc): `basename $0` tuned"
  echo "Example 2 (disable using libC malloc): `basename $0` tuned -d"
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
  if [ -d $DROP_IN_DIR/$SERVICE_NAME.service.d ]; then
    echo "Directory $DROP_IN_DIR/$SERVICE_NAME.service.d found."
    if [ -f $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME ]; then
      rm -f $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME
      rmdir $DROP_IN_DIR/$SERVICE_NAME.service.d
      if [ ! -d $DROP_IN_DIR/$SERVICE_NAME.service.d ]; then
        echo "Directory $DROP_IN_DIR/$SERVICE_NAME.service.d removed."
      fi
    fi
  else
    echo "ERROR: Directory $DROP_IN_DIR/$SERVICE_NAME.service.d does not exists."
    exit 4
  fi
}

write_file_content()
{
  echo "[Service]" > $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME
  echo "Environment='PYTHONMALLOC=malloc'" >> $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME
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

# Defaults
disable_drop_in="0"
SERVICE_NAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|-H|\?)
      usage_note
    ;;
    -d|-D)
      disable_drop_in="1"
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

echo "disable_drop_in=$disable_drop_in"
echo "SERVICE_NAME=$SERVICE_NAME"

if [ -z $SERVICE_NAME ]; then
  usage_note
fi

check_os
check_root
check_version
check_service

if [ "$disable_drop_in" = "0" ]; then
  if [ ! -d $DROP_IN_DIR/$SERVICE_NAME.service.d ]; then
    mkdir -p $DROP_IN_DIR/$SERVICE_NAME.service.d/
    echo "Directory $DROP_IN_DIR/$SERVICE_NAME.service.d created."
  else
    echo "Directory $DROP_IN_DIR/$SERVICE_NAME.service.d exists."
  fi

  if [ ! -f $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME ]; then
    write_file_content
    echo "File $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME created."
  else
    echo "File $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME exists."
    if [ "`grep PYTHONMALLOC $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME`" ]; then
      # Overwrite file content if drop-in exist
      write_file_content
      echo "File $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME overwrited."
    fi
    echo "New file content:"
    cat $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME
    exit 4
  fi
else
  if [ -d $DROP_IN_DIR/$SERVICE_NAME.service.d ]; then
    echo "Directory $DROP_IN_DIR/$SERVICE_NAME.service.d exists."
    if [ -f $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME ]; then
      echo "File $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME exists."
      rm -f $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME
      echo "File $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME deleted."
    fi
    rmdir $DROP_IN_DIR/$SERVICE_NAME.service.d
  fi
fi

systemctl daemon-reload
systemctl restart $SERVICE_NAME

echo "Completed for $SERVICE_NAME."

exit 0
