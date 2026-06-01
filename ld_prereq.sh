#!/bin/sh

#####################################################################################
## The script executes ld prerequisites for custom allocator (Solaris/Linux/FreeBSD).
##
## Version 1.5
## Written by Y.Voinov (C) 2022-2026
#####################################################################################

# Allocator paths. Change if installed different base.
LD_BASE="/usr/local"
LIB_NAME_BASE="*alloc"
LD_PATH1="$LD_BASE/lib/$LIB_NAME_BASE"
LD_PATH2="$LD_BASE/lib/$LIB_NAME_BASE/64"
LIB_NAME="$LIB_NAME_BASE.so"

# Find allocator lib(s)
# We assume that there is only one allocator in a given path and it has a corresponding name pattern.
ALLOCATOR_PATH="`find $LD_BASE -name $LIB_NAME -exec file {} \; | grep 32 | cut -d':' -f1`"
ALLOCATOR_PATH64="`find $LD_BASE -name $LIB_NAME -exec file {} \; | grep 64 | cut -d':' -f1`"

# Paths to write
# Linux
LDCONF_PATH="/etc/ld.so.conf.d"
LDCONF_PATH1="/etc"

# Config names
# Linux
LDCONF_LINUX1="lma.conf"
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
  echo "    -h, -H, ?   show this help"
  exit 0
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
    echo "ERROR: Unsupported OS."
    exit 1
  fi
}

check_root()
{
  if [ -z "`id | grep 'uid=0(root)'`" ]; then
    echo "ERROR: Must be run as root."
    exit 3
  fi
}

write_linux()
{
  if [ -d $LDCONF_PATH ]; then
    if [ -f $LD_PATH1/$LIB_NAME ]; then
      echo $LD_PATH1 > $LDCONF_PATH/$LDCONF_LINUX1
    fi
    if [ -f $LD_PATH2/$LIB_NAME ]; then
      echo $LD_PATH2 >> $LDCONF_PATH/$LDCONF_LINUX1
    fi
  else
    if [ -f $LD_PATH1/$LIB_NAME ]; then
      echo $LD_PATH1 > $LDCONF_PATH1/$LDCONF_LINUX2
    fi
    if [ -f $LD_PATH2/$LIB_NAME ]; then
      echo $LD_PATH2 >> $LDCONF_PATH1/$LDCONF_LINUX2
    fi
  fi
}

check_lib()
{
  if [ ! -f "$ALLOCATOR_PATH" ] && [ ! -f "$ALLOCATOR_PATH64" ]; then
    echo "ERROR: The path(s) to libraries being added do not exist. Install allocator first."
    exit 2
  fi
  if [ -f "$ALLOCATOR_PATH" ]; then
    echo $ALLOCATOR_PATH
  fi
  if [ -f "$ALLOCATOR_PATH64" ]; then
    echo $ALLOCATOR_PATH64
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
    crle -64 -c /var/ld/64/ld.config -l /lib/64:/usr/lib/64:$LD_PATH -s /lib/secure/64:/usr/lib/secure/64:$LD_PATH2
  fi
  echo "Note: For global preload make ld.config by youself. -e/-E options should not added automatically"
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
    echo "Check: All ok."
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
      -h|-H|\?)
        usage_note
      ;;
      *)
        shift
      ;;
    esac
  done
fi

check_root
check_lib

if [ "`check_os`" = "Linux" ]; then
  write_linux
  ldconfig
  check_linux
elif [ "`check_os`" = "SunOS" ]; then
  write_sunos
elif [ "`check_os`" = "FreeBSD" ]; then
  write_freebsd
fi

echo "Done."
exit 0
