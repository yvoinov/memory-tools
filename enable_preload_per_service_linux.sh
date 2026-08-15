#!/bin/sh

#####################################################################################
## The script for enable non-system allocator preload per specified systemd service.
## Service name specified as script argument (without any suffix, only service name).
## Linux version.
##
## Version 1.7
## Written by Y.Voinov (C) 2024-2026
#####################################################################################

# Variables
# Set bitness for alocator. 64 by default
BITNESS=64
# Allocator library search prefix: from where to find
LIBRARY_PREFIX="/usr/local"
# Set library name to preload
LIBRARY_NAME="*alloc.so"

# Drop-in directory
DROP_IN_DIR="/usr/lib/systemd/system"

# Allocator library path
ALLOCATOR_SYMLINK_PATH=""

CONF_FILE_NAME="mt_preload_env.conf"

# Drop-in extra env
CONF_EXTRA_ENV_FILE="mt_extra_env.conf"

# Subroutines
usage_note()
{
  echo "The script for enable non-system allocator preload per specified systemd service."
  echo "Must be run as root."
  echo "Usage: `basename $0` <service-name> [options]"
  echo "Options:"
  echo "    -h, -H, --help                     show this help"
  echo "    -b, -B, --base                     override allocator base directory"
  echo '    -e|-E "VAR1=value VAR2=value ..."  extra environment variables'
  echo ""
  echo "Note: Use -b=/usr/local/lib/... to override the default allocator base directory."
  echo ""
  echo "Example: `basename $0` apache2"
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

check_symlink()
{
  if [ -z "$ALLOCATOR_SYMLINK_PATH" ]; then
    echo "ERROR: No $BITNESS bit allocator found in $LIBRARY_PREFIX."
    echo "Check allocator installed."
    exit 4
  fi

  allocator_count=`printf '%s\n' "$ALLOCATOR_SYMLINK_PATH" | wc -l`

  if [ "$allocator_count" -gt 1 ]; then
    echo "ERROR: More than one $BITNESS bit allocator found in $LIBRARY_PREFIX:"
    printf '%s\n' "$ALLOCATOR_SYMLINK_PATH"
    echo "Please specify a more precise allocator base directory with -b."
    exit 4
  fi

  if [ -f "$ALLOCATOR_SYMLINK_PATH" ]; then
    echo "Allocator in $LIBRARY_PREFIX found: `ls $ALLOCATOR_SYMLINK_PATH`"
  else
    echo "ERROR: Symlink to library could not be found. Check allocator installed."
    exit 4
  fi
}

# Main
# Defaults
EXTRA_ENV=""
SERVICE_NAME=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|-H|--help)
      usage_note
      ;;
    -b|-B|--base)
      option="$1"
      shift
      if [ -z "$1" ]; then
        echo "ERROR: Option $option requires an argument"
        exit 2
      fi
      LIBRARY_PREFIX="$1"
      shift
      ;;
    -b=*|-B=*|--base=*)
      LIBRARY_PREFIX="`echo "$1" | sed 's/^[^=]*=//'`"
      shift
      ;;
    -e|-E)
      option="$1"
      shift
      if [ $# -eq 0 ]; then
        echo "ERROR: Option $option requires an argument"
        exit 2
      fi
      if [ -z "$EXTRA_ENV" ]; then
        EXTRA_ENV="$1"
      else
        EXTRA_ENV="$EXTRA_ENV $1"
      fi
      shift
      ;;
    *)
      # Accumulate to one string
      if [ -z "$SERVICE_NAME" ]; then
        SERVICE_NAME="$1"
      else
        SERVICE_NAME="$SERVICE_NAME $1"
      fi
      ;;
  esac
  shift
done

if [ -z "$SERVICE_NAME" ]; then
  usage_note
fi

# Find allocator lib(s)
# We assume that there is only one allocator in a given path and it has a corresponding name pattern.
ALLOCATOR_SYMLINK_PATH="`find "$LIBRARY_PREFIX" -name "$LIBRARY_NAME" -exec env POSIX_CORRECT=1 file {} \; | grep "$BITNESS" | cut -d':' -f1`"

check_os
check_root
check_service
check_symlink

if [ ! -d "$DROP_IN_DIR/$SERVICE_NAME.service.d" ]; then
  mkdir -p "$DROP_IN_DIR/$SERVICE_NAME.service.d/"
  echo "Directory $DROP_IN_DIR/$SERVICE_NAME.service.d created."
else
  echo "Directory $DROP_IN_DIR/$SERVICE_NAME.service.d exists."
fi

if [ ! -f "$DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME" ]; then
  echo "[Service]" > "$DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME"
  echo "Environment='LD_PRELOAD=$ALLOCATOR_SYMLINK_PATH'" >> "$DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME"
  echo "File $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME created."
else
  echo "File $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME exists."
  echo "File content: "
  cat "$DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_FILE_NAME"
fi

if [ -n "$EXTRA_ENV" ]; then
  if [ -f "$DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_EXTRA_ENV_FILE" ]; then
    echo "File $DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_EXTRA_ENV_FILE exists."
    echo "File content: "
    cat "$DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_EXTRA_ENV_FILE"
    echo "The file will be overwritten."
  fi

  echo "[Service]" > "$DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_EXTRA_ENV_FILE"
  for pair in $EXTRA_ENV; do
    echo "Environment='$pair'" >> "$DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_EXTRA_ENV_FILE"
  done

  echo "New file content: "
  cat "$DROP_IN_DIR/$SERVICE_NAME.service.d/$CONF_EXTRA_ENV_FILE"
fi

systemctl daemon-reload
systemctl restart $SERVICE_NAME

echo "Completed for $SERVICE_NAME."

exit 0
