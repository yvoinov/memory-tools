#!/bin/sh

#####################################################################################
## The script sets up custom allocator OS-wide performance prerequisites.
##
## Version 2.0
## Written by Y.Voinov (C) 2022-2026
#####################################################################################

set -e

# Sysctl config path
CONFIG_BASE="/etc"
SYSCTL_PATH="$CONFIG_BASE/sysctl.d"
SYSCTL_FILE="$CONFIG_BASE/sysctl.conf"
CONFIG_NAME="10-mt_custom.conf"

# Write file content
SYSCTL_FILE_STR1="# System tweaks for custom allocator"
# Note: Don't set swappiness too low on Proxmox/KVM or create big enough swap.
SYSCTL_FILE_STR2="vm.swappiness = 30"
SYSCTL_FILE_STR3="vm.vfs_cache_pressure = 50"
SYSCTL_FILE_STR4="vm.overcommit_ratio = 99"
# Note: When run aerospike or KVM with relatively small memory footprint, set vm.overcommit_memory=1. Otherwise asd will fail to start.
SYSCTL_FILE_STR5="vm.overcommit_memory = 2"

# Existence flags
SYSCTL_STR1_EXIST=""
SYSCTL_STR2_EXIST=""
SYSCTL_STR3_EXIST=""
SYSCTL_STR4_EXIST=""
SYSCTL_STR5_EXIST=""

# Subroutines
usage_note()
{
  echo "The script sets up custom allocator OS-wide prerequisites."
  echo "Reboot is recommended, but non-required. Must be run as root."
  echo "Usage: $(basename "$0") [options]"
  echo "Options:"
  echo "    -h, -H, --help   show this help"
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
  if [ "$(uname)" != "Linux" ]; then
    log_error "This script is for Linux only"
    exit 2
  fi
  log_ok "Running on Linux"
}

check_root()
{
  if [ "$(id -u)" -ne 0 ]; then
    log_error "Must be run as root"
    exit 3
  fi
  log_ok "Running as root"
}

check_container()
{
  if [ -n "$(grep 'kthreadd' /proc/2/status 2>/dev/null)" ]; then
    log_ok "Not in container"
  else
    log_info "In container. If it unprivileged, permission denied can occurs"
  fi
}

# Get sysctl key from "key = value"
get_sysctl_key()
{
  printf '%s\n' "${1%% = *}"
}

# Get sysctl value from "key = value"
get_sysctl_value()
{
  printf '%s\n' "${1##* = }"
}

check_sysctl()
{
  line=$1

  key=$(get_sysctl_key "$line")
  value=$(get_sysctl_value "$line")

  [ "$(sysctl -n "$key" 2>/dev/null)" = "$value" ]
}

config_contains()
{
  line=$1
  file=$2

  grep -F -x -q "$line" "$file" 2>/dev/null
}

check_running_values()
{
  if check_sysctl "$SYSCTL_FILE_STR2"; then
    log_info "Value '$SYSCTL_FILE_STR2' already active"
    SYSCTL_STR2_EXIST=1
  fi

  if check_sysctl "$SYSCTL_FILE_STR3"; then
    log_info "Value '$SYSCTL_FILE_STR3' already active"
    SYSCTL_STR3_EXIST=1
  fi

  if check_sysctl "$SYSCTL_FILE_STR4"; then
    log_info "Value '$SYSCTL_FILE_STR4' already active"
    SYSCTL_STR4_EXIST=1
  fi

  if check_sysctl "$SYSCTL_FILE_STR5"; then
    log_info "Value '$SYSCTL_FILE_STR5' already active"
    SYSCTL_STR5_EXIST=1
  fi
}

append_if_needed()
{
  exist_flag=$1
  line=$2
  file=$3

  if [ -n "$exist_flag" ]; then
    return
  fi

  if config_contains "$line" "$file"; then
    return
  fi

  printf '%s\n' "$line"
}

write_file()
{
  file=$1

  append_if_needed "$SYSCTL_STR1_EXIST" "$SYSCTL_FILE_STR1" "$file"
  append_if_needed "$SYSCTL_STR2_EXIST" "$SYSCTL_FILE_STR2" "$file"
  append_if_needed "$SYSCTL_STR3_EXIST" "$SYSCTL_FILE_STR3" "$file"
  append_if_needed "$SYSCTL_STR4_EXIST" "$SYSCTL_FILE_STR4" "$file"
  append_if_needed "$SYSCTL_STR5_EXIST" "$SYSCTL_FILE_STR5" "$file"
}

update_sysctl_config()
{
  if [ -d "$SYSCTL_PATH" ]; then
    target="$SYSCTL_PATH/$CONFIG_NAME"
  else
    target="$SYSCTL_FILE"
  fi

  new_lines=$(write_file "$target")

  if [ -z "$new_lines" ]; then
    log_info "No configuration changes required"
    return 1
  fi

  if [ -f "$target" ]; then
    printf '%s\n' "$new_lines" >> "$target"
  else
    printf '%s\n' "$new_lines" > "$target"
  fi

  log_info "Updated $target"

  return 0
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
      *)
        shift
      ;;
    esac
  done
fi

check_os
check_root
check_container

check_running_values
update_sysctl_config

if set_config; then
  log_info "Applying sysctl settings..."
  sysctl --system >/dev/null 2>&1
fi

log_ok "Done. Reboot recommended but non-required"
exit 0
