#!/bin/sh

#####################################################################################
## The script for enable non-system allocator preload per specified SMF service.
## Service name (FMRI) specified as script argument. Solaris version.
##
## Limitations:
## 1. Service should be online.
## 2. Service must have associated running binary.
##    If the service is complex - a one-time executed script or a set of commands in
##    a script, then preload must be performed manually.
##
## Version 1.1
## Written by Y.Voinov (C) 2025-2026
#####################################################################################

# Variables
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
  echo "The script for enable non-system allocator preload per specified SMF service."
  echo "Must be run as root."
  echo "Usage: `basename $0` <service-fmri> [options]"
  echo "Options:"
  echo "    -h, -H, ?   show this help"
  echo '    -e, -E, -e|-E "VAR1=value VAR2=value ...", extra environment variables'
  echo ""
  echo "Note: Additional environment variables are typically used to parameterize the allocator."
  echo "      It can also be used to set other environment variables that affect service."
  echo ""
  echo "Example: `basename $0` cron:default"
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

check_service()
{
  if [ -z "`svcs -H  $SERVICE_FMRI | grep $SERVICE_FMRI`" ]; then
    exit 3
  fi
}

check_symlink()
{
  if [ ! -z "$ALLOCATOR_SYMLINK_PATH_32" -a -f "$ALLOCATOR_SYMLINK_PATH_32" ] && \
     [ ! -z "$ALLOCATOR_SYMLINK_PATH_64" -a -f "$ALLOCATOR_SYMLINK_PATH_64" ]; then
    echo "Allocator 32 bit: `ls $ALLOCATOR_SYMLINK_PATH_32`"
    echo "Allocator 64 bit: `ls $ALLOCATOR_SYMLINK_PATH_64`"
  else
    echo "ERROR: Symlinks to libraries could not be found. Check allocator installed."
    exit 4
  fi
}

check_service_has_binary()
{
  full_fmri="`svcs -H $SERVICE_FMRI | awk '{ print $3 }'`"
  if [ ! -z "`svcs -H -o state $SERVICE_FMRI | grep online`" ]; then
    if [ -z "`svcs -H -p $SERVICE_FMRI | grep -v $full_fmri`" ]; then
      echo "ERROR: Service has no associated binary and must preload manually."
      exit 6
    fi
  else
    echo "ERROR: Service should be online."
    exit 5
  fi
}

check_service_has_one_instance()
{
  if [ ! "`svcs -H  $SERVICE_FMRI | grep $SERVICE_FMRI | wc -l`" -eq 1 ]; then
    echo "ERROR: FMRI $SERVICE_NAME returns more than one services:"
    echo "`svcs -H  $SERVICE_FMRI | grep $SERVICE_FMRI`"
    echo "Please choose one more precisely."
    exit 7
  fi
}

check_preloaded_already()
{
  var=$1
  value=$2
  fmri="`printf '%s\n' "$SERVICE_FMRI" | sed -e 's/^svc://' -e 's/:default$//'`"
  cond="`svccfg -s $fmri listprop start/environment | grep 'LD_PRELOAD_$var=$value'`"
  if [ ! -z "$cond" ]; then
    echo "ERROR: $SERVICE_FMRI already preloaded."
    exit 8
  fi
}

check_service_bitness_and_set_preload()
{
  # Get minimal pid for service
  full_smf_name="`svcs -H $SERVICE_FMRI | awk '{ print $3 }'`"
  service_pid="`svcs -H -p $SERVICE_FMRI | grep -v $full_smf_name | awk '{ print $2 }' | sort -n | head -1`"
  full_name="`pargs $service_pid | grep -v $service_pid | awk '{ print $2 }'`"
  if [ -n "$EXTRA_ENV" ]; then
    for pair in $EXTRA_ENV; do
      var=`echo "$pair" | cut -d= -f1`
      val=`echo "$pair" | cut -d= -f2-`
      svccfg -s "$SERVICE_FMRI" setenv "$var" "$val"
    done
  fi
  if [ ! -z "`file $full_name | grep 32`" ]; then
    echo "Service is 32 bit."
    check_preloaded_already 32 $ALLOCATOR_SYMLINK_PATH_32
    svccfg -s $SERVICE_FMRI setenv LD_PRELOAD_32 $ALLOCATOR_SYMLINK_PATH_32
  elif [ ! -z "`file $full_name | grep 64`" ]; then
    echo "Service is 64 bit."
    check_preloaded_already 64 $ALLOCATOR_SYMLINK_PATH_64
    svccfg -s $SERVICE_FMRI setenv LD_PRELOAD_64 $ALLOCATOR_SYMLINK_PATH_64
  fi
  svcadm refresh $SERVICE_FMRI
  svcadm restart $SERVICE_FMRI
}

# Main
SERVICE_FMRI=""
EXTRA_ENV=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|-H|\?)
      usage_note
      ;;
    -e|-E)
      shift
      if [ $# -eq 0 ]; then
        echo "Error: $1 requires an argument"
        usage_note
      fi
      if [ -z "$EXTRA_ENV" ]; then
        EXTRA_ENV="$1"
      else
        EXTRA_ENV="$EXTRA_ENV $1"
      fi
      shift
      ;;
    -*)
      echo "Unknown option: $1"
      usage_note
      ;;
    *)
      # Accumulate SERVICE_FMRI
      if [ -z "$SERVICE_FMRI" ]; then
        SERVICE_FMRI="$1"
      else
        SERVICE_FMRI="$SERVICE_FMRI $1"
      fi
      shift
      ;;
  esac
done

if [ -z $SERVICE_FMRI ]; then
  usage_note
fi

check_os
check_root
check_service
check_symlink
check_service_has_binary
check_service_has_one_instance
check_service_bitness_and_set_preload

echo "Completed for $SERVICE_FMRI."

exit 0
