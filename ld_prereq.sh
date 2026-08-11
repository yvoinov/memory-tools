#!/bin/sh

#####################################################################################
## The script executes ld prerequisites for custom allocator (Solaris/Linux/FreeBSD).
##
## Version 2.0
## Written by Y.Voinov (C) 2022-2026
#####################################################################################

# Allocator paths. Change if installed different base.
LD_BASE="/usr/local"
LIB_NAME_BASE="*alloc"
LIB_NAME="$LIB_NAME_BASE.so"

ALLOCATOR_PATH32=""
ALLOCATOR_PATH64=""

LD_PATH1=""
LD_PATH2=""

# Paths to write
# Linux
LDCONF_PATH="/etc"
LDCONF_PATH_D="$LDCONF_PATH/ld.so.conf.d"

# Config names
# Linux
LDCONF_LINUX1="mt_ld_custom.conf"
LDCONF_LINUX2="ld.so.conf"

# SunOS
CRLE_CONF1="/var/ld/ld.config"
CRLE_CONF2="/var/ld/64/ld.config"

# Subroutines
usage_note()
{
  echo "The script executes ld prerequisites for custom allocator (Solaris/Linux/FreeBSD)."
  echo "Must be run as root."
  echo "Usage: `basename $0` [options]"
  echo "Options:"
  echo "    -h, -H, --help   show this help"
  echo "    -b, --base    override allocator base directory"
  exit 0
}

log_ok()
{
  printf "[OK] $*\n"
}

log_info()
{
  printf "[INFO] $*\n" >&2
}

log_error()
{
  printf "[ERROR] $*\n" >&2
}

check_os()
{
  if [ "`uname`" = "Linux" ]; then
    echo "Linux"
  elif [ "`uname`" = "SunOS" ]; then
    echo "SunOS"
  elif [ "`uname`" = "FreeBSD" ]; then
    echo "FreeBSD"
  else
    log_error "Unsupported OS"
    exit 1
  fi
}

check_root()
{
  if [ -z "`id | grep 'uid=0(root)'`" ]; then
    log_error "Must be run as root"
    exit 3
  fi
  log_ok "Running as root"
}

check_lib()
{
  allocator_count="0"

  if [ ! -z "$ALLOCATOR_PATH32" ]; then
    count="`echo "$ALLOCATOR_PATH32" | wc -l | sed 's/[ ]*//g'`"
    allocator_count="`expr $allocator_count + $count`"
  fi

  if [ ! -z "$ALLOCATOR_PATH64" ]; then
    count="`echo "$ALLOCATOR_PATH64" | wc -l | sed 's/[ ]*//g'`"
    allocator_count="`expr $allocator_count + $count`"
  fi

  if [ "$allocator_count" -gt 1 ]; then
    log_info "Multiple allocator libraries found: $allocator_count"
    log_info "[ $ALLOCATOR_PATH32 ]"
    log_info "[ $ALLOCATOR_PATH64 ]"
    if [ "$allocator_count" -eq 2 ] && [ ! -z "$ALLOCATOR_PATH32" ] && [ ! -z "$ALLOCATOR_PATH64" ]; then
      path1="`dirname "$ALLOCATOR_PATH32" 2>/dev/null`"
      path2="`dirname "$ALLOCATOR_PATH64" 2>/dev/null`"
      path1_4="`echo "$path1" | sed 's#^/##' | cut -d'/' -f1-4`"
      path2_4="`echo "$path2" | sed 's#^/##' | cut -d'/' -f1-4`"
      if [ "$path1_4" != "$path2_4" ]; then
        log_error "Allocator paths do not match up to 4 levels"
        log_info "Narrow the search from current LD_BASE=$LD_BASE to a subdirectory"
        exit 2
      fi
    else
      log_info "Narrow the search from current LD_BASE=$LD_BASE to a subdirectory"
      exit 2
    fi
  elif [ ! -f "$ALLOCATOR_PATH32" ] && [ ! -f "$ALLOCATOR_PATH64" ]; then
    log_error "The path(s) to libraries being added do not exist. Install allocator first"
    exit 3
  fi

  if [ -f "$ALLOCATOR_PATH32" ]; then
    log_ok $ALLOCATOR_PATH32
  fi
  if [ -f "$ALLOCATOR_PATH64" ]; then
    log_ok $ALLOCATOR_PATH64
  fi
}

write_linux()
{
  if [ -d $LDCONF_PATH_D ]; then
    conf_file="$LDCONF_PATH_D/$LDCONF_LINUX1"
  else
    conf_file="$LDCONF_PATH/$LDCONF_LINUX2"
  fi
  if [ ! -f "$conf_file" ]; then
    if [ -f "$ALLOCATOR_PATH32" ]; then
      echo $LD_PATH1 > $conf_file
    fi
    if [ -f "$ALLOCATOR_PATH64" ]; then
      echo $LD_PATH2 >> $conf_file
    fi
  else
    if [ -f "$ALLOCATOR_PATH32" ]; then
      if [ -z "`grep -F -x "$LD_PATH1" "$conf_file"`" ]; then
        echo $LD_PATH1 >> $conf_file
      fi
    fi
    if [ -f "$ALLOCATOR_PATH64" ]; then
      if [ -z "`grep -F -x "$LD_PATH2" "$conf_file"`" ]; then
        echo $LD_PATH2 >> $conf_file
      fi
    fi
  fi
}

write_sunos()
{
 # If custom config exists, just add dirs.
  if [ -f $CRLE_CONF1 ]; then
    crle -c /var/ld/ld.config -u -l $LD_PATH1 -s $LD_PATH1
  else
    crle -c /var/ld/ld.config -l /lib:/usr/lib:$LD_PATH1 -s /lib/secure:/usr/lib/secure:/usr/lib:$LD_PATH1
  fi
  if [ -f $CRLE_CONF2 ]; then
    crle -64 -c /var/ld/64/ld.config -u -l $LD_PATH2 -s $LD_PATH2
  else
    crle -64 -c /var/ld/64/ld.config -l /lib/64:/usr/lib/64:$LD_PATH2 -s /lib/secure/64:/usr/lib/secure/64:/usr/lib:$LD_PATH2
  fi
  log_info "For global preload make ld.config by youself. -e/-E options should not added automatically"
}

write_freebsd()
{
  if [ -z "`ldconfig -r | grep $LD_PATH1/$LIB_NAME`" ]; then
    ldconfig -R $LD_PATH1
  fi
  if [ -z "`ldconfig -r | grep $LD_PATH2/$LIB_NAME`" ]; then
    ldconfig -R $LD_PATH2
  fi
}

check_linux()
{
  if [ ! -z "`ldconfig -p | grep ltalloc`" ]; then
    log_ok "Linux check: All ok"
  fi
}

check_sunos()
{
  if [ ! -z "`crle | grep $LD_PATH1`" -a "`crle -64 | grep $LD_PATH1`" ]; then
    log_ok "SunOS check: All ok"
  fi
}

# Main
# Parse command line
if [ "x$*" != "x" ]; then
  arg_list=$*

  # Read arguments
  for i in $arg_list
  do
    case $i in
    -h|-H|--help)
      usage_note
      ;;
    -b|--base)
      shift
      if [ -z "$1" ]; then
        log_error "Option $i requires an argument"
        exit 2
      fi
      LD_BASE="$1"
      ;;
    -b=*|--base=*)
      LD_BASE="`echo "$i" | sed 's/^[^=]*=//'`"
      ;;
    *)
      log_error "Unknown option: $i"
      exit 2
      ;;
    esac
    shift
  done
fi

log_info "LD_BASE=$LD_BASE"

# Find allocator lib(s)
ALLOCATOR_PATH32="`find $LD_BASE -name $LIB_NAME -exec env POSIXLY_CORRECT=1 file {} \; | grep 32 | cut -d':' -f1`"
ALLOCATOR_PATH64="`find $LD_BASE -name $LIB_NAME -exec env POSIXLY_CORRECT=1 file {} \; | grep 64 | cut -d':' -f1`"

LD_PATH1="`dirname $ALLOCATOR_PATH32 2>/dev/null`"
LD_PATH2="`dirname $ALLOCATOR_PATH64 2>/dev/null`"

check_root
check_lib

log_info "Running on `check_os`"

if [ "`check_os`" = "Linux" ]; then
  write_linux
  ldconfig
  check_linux
elif [ "`check_os`" = "SunOS" ]; then
  write_sunos
  check_sunos
elif [ "`check_os`" = "FreeBSD" ]; then
  write_freebsd
fi

log_ok "Done"
exit 0
