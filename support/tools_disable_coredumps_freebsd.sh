#!/bin/sh

# tools_disable_coredumps_freebsd.sh
#
# Version 1.0
# Written by Y.Voinov (C) 2026

SYSCTL_CONF="/etc/sysctl.conf"

log_ok()
{
  echo "[OK] $*"
}

log_info()
{
  echo "[INFO] $*"
}

log_error()
{
  echo "[ERROR] $*" >&2
}

set_setting()
{
  key="$1"
  value="$2"

  if grep -Eq "^[[:space:]]*${key}=" "${SYSCTL_CONF}"; then
    sed -i '' \
      -e "s|^[[:space:]]*${key}=.*|${key}=${value}|" \
      "${SYSCTL_CONF}" || {
        log_error "Failed to update ${key}"
        exit 1
      }

    log_ok "Value updated: ${key}=${value}"
  else
    echo "${key}=${value}" >> "${SYSCTL_CONF}" || {
      log_error "Failed to update ${SYSCTL_CONF}"
      exit 1
    }

    log_ok "Value added: ${key}=${value}"
  fi

  if ! grep -Fqx "${key}=${value}" "${SYSCTL_CONF}"; then
    log_error "File verification failed: ${key}"
    exit 1
  fi

  log_ok "File verification passed: ${key}"

  sysctl "${key}=${value}" >/dev/null 2>&1 || {
    log_error "Failed to apply ${key}"
    exit 1
  }

  log_ok "Runtime value applied: ${key}"
}

if [ "$(id -u)" -ne 0 ]; then
  log_error "This script must be run as root"
  exit 1
fi

log_ok "Running as root"

if [ "$(uname -s)" != "FreeBSD" ]; then
  log_error "This script is intended for FreeBSD only"
  exit 1
fi

log_ok "FreeBSD detected"

if [ ! -f "${SYSCTL_CONF}" ]; then
  log_error "File not found: ${SYSCTL_CONF}"
  exit 1
fi

log_ok "File exists: ${SYSCTL_CONF}"

set_setting "kern.corefile" "/dev/null"
set_setting "kern.coredump" "0"
set_setting "kern.sugid_coredump" "0"

log_info "Current kernel settings:"
sysctl kern.corefile
sysctl kern.coredump
sysctl kern.sugid_coredump

log_ok "Completed successfully"

exit 0
