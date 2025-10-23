#!/bin/sh

#####################################################################################
## The script for enable non-system allocator global preload. Solaris version.
##
## Version 1.2
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

# OS specific runtime paths
###############################################################################################################
# Note: Be careful with compiler runtime paths on platforms other than Solaris 10 (It uses OpenCSW by default).
#       They may differ, but must be set correctly. Ideally, the runtime paths should point to the most recent
#       version, but not be lower than the version the allocator was compiled with.
###############################################################################################################
# OpenIndiana
OI_RUNTIME_32="/usr/gcc/14/lib"
OI_RUNTIME_64_X86="/usr/gcc/14/lib/amd64"
OI_RUNTIME_64_SPARC="/usr/gcc/14/lib/sparcv9"
# OmniOS
OMNI_RUNTIME_32="/usr/gcc/14/lib"
OMNI_RUNTIME_64="/usr/gcc/14/lib/64"
# Solaris 10
SOL10_RUNTIME_32="/opt/csw/lib"
SOL10_RUNTIME_64_X86="/opt/csw/lib/amd64"
SOL10_RUNTIME_64_SPARC="/opt/csw/lib/sparcv9"
# Solaris 11
SOL11_RUNTIME_32="/usr/gcc/7/lib"
SOL11_RUNTIME_64_X86="/usr/gcc/7/lib/amd64"
SOL11_RUNTIME_64_SPARC="/usr/gcc/7/lib/sparcv9"
# Runtime variables. Should be empty before set below
RUNTIME_DIR_32=""
RUNTIME_DIR_64=""

# Secure lib paths.  Should be empty before set below
SECURE_DIR_32=""
SECURE_DIR_64=""

# Subroutines
usage_note()
{
  echo "The script for enable non-system allocator global preload."
  echo "Make sure you made emergency boot media before use!"
  echo "Must be run as root."
  echo "Options:"
  echo "  -n, -N, non-interactive mode for automation"
  echo "Example: `basename $0`"
  exit 0
}

check_os()
{
  to_screen=$1
  if [ "$to_screen" = "1" ]; then
    if [ "`uname`" != "SunOS" ]; then
      echo "ERROR: Unsupported OS."
      exit 1
    else
      printf "OS detected: "
      if [ ! -z "`cat /etc/release | grep 'OpenIndiana'`" ]; then
        echo "OpenIndiana"
      elif [ ! -z "`cat /etc/release | grep 'OmniOS'`" ]; then
        echo "OmniOS"
      elif [ ! -z "`cat /etc/release | grep 'Oracle Solaris 10'`" ]; then
        echo "Oracle Solaris 10"
      elif [ ! -z "`cat /etc/release | grep 'Oracle Solaris 11'`" ]; then
        echo "Oracle Solaris 11"
      else
        echo "Unknown Solaris"
      fi
    fi
  elif [ "$to_screen" = "0" ]; then
    if [ ! -z "`cat /etc/release | grep 'OpenIndiana'`" ]; then
      echo "oi"
    elif [ ! -z "`cat /etc/release | grep 'OmniOS'`" ]; then
      echo "omni"
    elif [ ! -z "`cat /etc/release | grep 'Oracle Solaris 10'`" ]; then
      echo "sol10"
    elif [ ! -z "`cat /etc/release | grep 'Oracle Solaris 11'`" ]; then
      echo "sol11"
    else
      echo "unknown"
    fi
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
  if [ ! -z "$ALLOCATOR_SYMLINK_PATH_32" -a -f "$ALLOCATOR_SYMLINK_PATH_32" ] && \
     [ ! -z "$ALLOCATOR_SYMLINK_PATH_64" -a -f "$ALLOCATOR_SYMLINK_PATH_64" ]; then
    echo "Allocator 32 bit: `ls $ALLOCATOR_SYMLINK_PATH_32`"
    echo "Allocator 64 bit: `ls $ALLOCATOR_SYMLINK_PATH_64`"
  else
    echo "ERROR: Symlinks to library could not be found. Check allocator installed."
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
  if [ "`check_ld_config_32`" = "1" -a ! -z "$preload_env_32" -a "`check_ld_config_64`" = "1" -a ! -z "$preload_env_64" ]; then
    if [ "$preload_env_32" = "$ALLOCATOR_SYMLINK_PATH_32" -a "$preload_env_64" = "$ALLOCATOR_SYMLINK_PATH_64" ]; then
      echo "Allocator $preload_env_32 preloaded."
      echo "Allocator $preload_env_64 preloaded."
      echo "ERROR: Global preload already enabled. Exiting..."
      exit 4
    fi
  else
    echo "Global preload does not enabled."
  fi
}

check_and_set_runtime()
{
  # If not defined, set globals to targets
  if [ "`check_os 0`" = "oi" -a -d "$OI_RUNTIME_32" ] && \
     ([ -d "$OI_RUNTIME_64_X86" ] || [ -d "$OI_RUNTIME_64_SPARC" ]); then
      runtime_dir_32=$OI_RUNTIME_32
      if [ "`uname -p`" = "i386" ]; then
        runtime_dir_64=$OI_RUNTIME_64_X86
      elif [ "`uname -p`" = "sparc" ]; then
        runtime_dir_64=$OI_RUNTIME_64_SPARC
      fi
  elif [ "`check_os 0`" = "omni" ]; then
    if [ -d "$OMNI_RUNTIME_32" ] && [ -d "$OMNI_RUNTIME_64" ]; then
      runtime_dir_32=$OMNI_RUNTIME_32
      runtime_dir_64=$OMNI_RUNTIME_64
    fi
  elif [ "`check_os 0`" = "sol10" -a -d "$SOL10_RUNTIME_32" ] && \
     ([ -d "$SOL10_RUNTIME_64_X86" ] || [ -d "$SOL10_RUNTIME_64_SPARC" ]); then
      runtime_dir_32=$SOL10_RUNTIME_32
      if [ "`uname -p`" = "i386" ]; then
        runtime_dir_64=$SOL10_RUNTIME_64_X86
      elif [ "`uname -p`" = "sparc" ]; then
        runtime_dir_64=$SOL10_RUNTIME_64_SPARC
      fi
  elif [ "`check_os 0`" = "sol11" -a -d "$SOL11_RUNTIME_32" ] && \
     ([ -d "$SOL11_RUNTIME_64_X86" ] || [ -d "$SOL11_RUNTIME_64_SPARC" ]); then
    runtime_dir_32=$SOL11_RUNTIME_32
    if [ "`uname -p`" = "i386" ]; then
      runtime_dir_64=$SOL11_RUNTIME_64_X86
    elif [ "`uname -p`" = "sparc" ]; then
      runtime_dir_64=$SOL11_RUNTIME_64_SPARC
    fi
  fi
  # Check runtime dirs defined
  if [ -z "$runtime_dir_32" ]; then
    echo "ERROR: Runtime dir 32 bit $runtime_dir_32 does not exists."
    exit 5
  fi
  if [ -z "$runtime_dir_64" ]; then
    echo "ERROR: Runtime dir 64 bit $runtime_dir_64 does not exists."
    exit 5
  fi
  # Check if path added already
  default_search_path_32="`crle 2>/dev/null | grep 'Default Library Path' | sed 's/^[^:]*:[ 	]*//; s/[ 	]*(.*)//; s/[ 	]*$//'`"
  default_search_path_64="`crle -64 2>/dev/null | grep 'Default Library Path' | sed 's/^[^:]*:[ 	]*//; s/[ 	]*(.*)//; s/[ 	]*$//'`"
  if [ ! -z "`echo $default_search_path_32 | grep $runtime_dir_32`" -a ! -z "`echo $default_search_path_64 | grep $runtime_dir_64`" ]; then
    echo "Runtime search path 32: $default_search_path_32"
    echo "Runtime search path 64: $default_search_path_64"
    echo "Runtime search paths defined already."
    # Keep original path
    RUNTIME_DIR_32=$default_search_path_32
    RUNTIME_DIR_64=$default_search_path_64
  else
    # Set full search paths
    RUNTIME_DIR_32="$runtime_dir_32:$default_search_path_32"
    RUNTIME_DIR_64="$runtime_dir_64:$default_search_path_64"
  fi
}

check_and_set_trusted_paths()
{
  secure_lib_search_path_32="`crle 2>/dev/null | grep 'Trusted Directories' | sed 's/^[^:]*:[ 	]*//; s/[ 	]*(.*)//; s/[ 	]*$//'`"
  secure_lib_search_path_64="`crle -64 2>/dev/null | grep 'Trusted Directories' | sed 's/^[^:]*:[ 	]*//; s/[ 	]*(.*)//; s/[ 	]*$//'`"
  secure_dir_lib_32="`dirname $ALLOCATOR_SYMLINK_PATH_32`"
  secure_dir_lib_64="`dirname $ALLOCATOR_SYMLINK_PATH_64`"
  if [ ! -z "`echo $secure_lib_search_path_32 | grep $secure_dir_lib_32`" -a ! -z "`echo $secure_lib_search_path_64 | grep $secure_dir_lib_64`" ]; then
    echo "Trusted libraries path 32: $secure_lib_search_path_32"
    echo "Trusted libraries path 64: $secure_lib_search_path_64"
    echo "Trusted libraries paths defined already."
    # Keep original path
    SECURE_DIR_32="$secure_lib_search_path_32"
    SECURE_DIR_64="$secure_lib_search_path_64"
  else
    # Set full trusted libs paths
    SECURE_DIR_32="$secure_lib_search_path_32:$secure_dir_lib_32"
    SECURE_DIR_64="$secure_lib_search_path_64:$secure_dir_lib_64"
  fi
}

enable_global_preload()
{
  # Protection if config exists
  if [ "`check_ld_config_32`" = "1" ]; then
    cp $PRELOAD_CONF_32 "$PRELOAD_CONF_32.orig"
    echo "Config file $PRELOAD_CONF_32 exists and saved to $PRELOAD_CONF_32.orig."
  fi
  if [ "`check_ld_config_64`" = "1" ]; then
    cp $PRELOAD_CONF_64 "$PRELOAD_CONF_64.orig"
    echo "Config file $PRELOAD_CONF_64 exists and saved to $PRELOAD_CONF_64.orig."
  fi
  # Enable global preload
  crle -c $PRELOAD_CONF_32 -l $RUNTIME_DIR_32 -s $SECURE_DIR_32 -e LD_PRELOAD_32=$ALLOCATOR_SYMLINK_PATH_32
  crle -64 -c $PRELOAD_CONF_64 -l $RUNTIME_DIR_64 -s $SECURE_DIR_64 -e LD_PRELOAD_64=$ALLOCATOR_SYMLINK_PATH_64
}

# Main
# Defaults
non_interactive="0"

while [ $# -gt 0 ]; do
  case "$1" in
    -h|-H|\?)
      usage_note
    ;;
    -n|-N)
      non_interactive="1"
    ;;
    *) shift
    ;;
    esac
done

check_os 1  # Output OS to screen
check_root
check_symlink
check_enabled

if [ "$non_interactive" = "0" ]; then
  if command -v tput >/dev/null 2>&1 && [ -n "`tput colors`" ]; then
    RED_BG="`tput bold; tput setab 1; tput setaf 7`"  # light white on red
    YEL="`tput bold; tput setaf 3`"                   # light yellow
    NC="`tput sgr0`"                                  # reset
  else
    RED_BG=""
    YEL=""
    NC=""
  fi

  echo
  echo "${RED_BG}##############################################################################${NC}"
  echo "${RED_BG}##${NC} ${YEL}WARNING!!! BEFORE YOU BEGIN, MAKE SURE YOU HAVE EMERGENCY BOOTABLE MEDIA${NC} ${RED_BG}##${NC}"
  echo "${RED_BG}##${NC} ${YEL}PREPARED! Otherwise, your system may become unbootable.${NC}                  ${RED_BG}##${NC}"
  echo "${RED_BG}##${NC}              Press Y to continue or N/Ctrl+C to cancel.                  ${RED_BG}##${NC}"
  echo "${RED_BG}##############################################################################${NC}"

  while true; do
    IFS= read ans || exit  # Ctrl+C or EOF
    case "$ans" in
      y|Y)
          break
      ;;
      n|N)
          exit
      ;;
      *)
        printf 'Please answer y/Y or n/N\n'
      ;;
    esac
  done
fi

check_and_set_runtime
check_and_set_trusted_paths
enable_global_preload

echo "${YEL}Completed. Check exclusions and reboot now to apply changes globally.${NC}"

exit 0
