#!/bin/sh

#####################################################################################
## The script for disable global preload any non-system allocator per specified SMF
## service or remove per-service allocator preload.
## Service name (FMRI) specified as script argument.
## Solaris version.
##
## Version 1.0
## Written by Y.Voinov (C) 2025
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
  echo "The script for disable global preload any non-system allocator per specified SMF service."
  echo "To disable per-service preload, use -d option."
  echo "Must be run as root."
  echo "Usage: `basename $0` <service_fmri> [options]"
  echo "Options:"
  echo "    -d, -D      disable per-service preload"
  echo "    -h, -H, ?   show this help"
  echo "Example 1 (per-service workaround): `basename $0` cswapache2:default"
  echo "Example 2 (completely disable): `basename $0` cswapache2:default -d"
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

check_service_has_one_instance()
{
  if [ ! "`svcs -H  $SERVICE_FMRI | grep $SERVICE_FMRI | wc -l`" -eq 1 ]; then
    echo "ERROR: FMRI $SERVICE_NAME returns more than one services:"
    echo "`svcs -H  $SERVICE_FMRI | grep $SERVICE_FMRI`"
    echo "Please choose one more precisely."
    exit 5
  fi
}

get_env_filtered() {
  fmri=$1
  line=`svccfg -s "$fmri" listprop start/environment 2>/dev/null`
  set -- $line

  if [ "$#" -le 2 ]; then
    echo ""
    return 0
  fi

  count=0
  out=""

  for tok in "$@"
  do
    count=`expr $count + 1`
    [ "$count" -le 2 ] && continue

    tok=`echo "$tok" | tr -d '"'`

    case "$tok" in
      LD_PRELOAD_32=*|LD_PRELOAD_64=*)
      ;;
      *)
        if [ -z "$out" ]; then
          out="\"$tok\""
        else
          out="$out \"$tok\""
        fi
      ;;
    esac
  done

  echo "$out"
}

disable_preload()
{
  mode=$1
  full_smf_name="`svcs -H $SERVICE_FMRI | awk '{ print $3 }'`"
  fmri="`printf '%s\n' "$full_smf_name" | sed -e 's/^svc://' -e 's/:default$//'`"
  if [ "$mode" = "1" ]; then
    if [ ! -n "`svccfg -s $fmri listprop start/environment | grep 'LD_PRELOAD_32=$ALLOCATOR_SYMLINK_PATH_32'`" ]; then
      svccfg -s $fmri unsetenv LD_PRELOAD_32
      echo "INFO: 32 bit disabled."
    elif [ ! -n "`svccfg -s $fmri listprop start/environment | grep 'LD_PRELOAD_64=$ALLOCATOR_SYMLINK_PATH_64'`" ]; then
      svccfg -s $fmri unsetenv LD_PRELOAD_64
      echo "INFO: 64 bit disabled."
    fi
  else
    if [ -z "`svccfg -s $fmri listprop start/environment`" ]; then
      if [ -z "`svccfg -s $fmri listpg start`" ]; then
        # The start method may also be missing
        printf "Property start not exists. Create..."
        svccfg -s $fmri <<EOT
          addpg start method
          end
EOT
        echo "Done."
      fi
      # In case of no property start/environment exists
      printf "Property start/environment not exists. Create..."
      svccfg -s $fmri <<EOT
        setprop start/environment=astring:()
        end
EOT
      echo "Done."
    fi

    envs=`get_env_filtered "$fmri"`

    # Let's null both variables to not choose with service bitness or value
    # Build final command line safely. Keep another environments if any
    command='setprop start/environment=("LD_PRELOAD_32=" "LD_PRELOAD_64="'
    if [ -n "$envs" ]; then
     command="$command $envs"
    fi
    command="$command)"

    svccfg -s $fmri <<EOT
      $command
      end
EOT
  fi
  svcadm refresh $full_smf_name
  svcadm restart $full_smf_name
}

# Main
if [ -z $1 ]; then
  usage_note
fi

disable_full="0"
SERVICE_FMRI=""

while [ $# -gt 0 ]; do
  case "$1" in
    -d|-D)
      disable_full="1"
    ;;
    -h|-H|\?)
      usage_note
    ;;
    *)
    # Accumulate to one string
      if [ -z "$SERVICE_FMRI" ]; then
        SERVICE_FMRI=$1
      else
        SERVICE_FMRI="$SERVICE_FMRI $1"
      fi
    ;;
    esac
    shift
done

if [ -z $SERVICE_FMRI ]; then
  usage_note
fi

check_os
check_root
check_service
check_symlink
check_service_has_one_instance

disable_preload $disable_full

echo "Completed for $SERVICE_FMRI."

exit 0
