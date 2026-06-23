#!/bin/sh

# tools_enable_coredumps_freebsd.sh
#
# Version 1.0
# Written by Y.Voinov (C) 2026

SYSCTL_CONF="/etc/sysctl.conf"
CORE_DIR="/var/core"

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

if [ -d "${CORE_DIR}" ]; then
  log_ok "Directory exists: ${CORE_DIR}"
else
  mkdir -p "${CORE_DIR}" || {
    log_error "Failed to create directory: ${CORE_DIR}"
    exit 1
  }

  chmod 1777 "${CORE_DIR}" || {
    log_error "Failed to set permissions on ${CORE_DIR}"
    exit 1
  }

  log_ok "Directory created: ${CORE_DIR}"
fi

set_setting "kern.corefile" "${CORE_DIR}/core.%N"
set_setting "kern.coredump" "1"
set_setting "kern.sugid_coredump" "1"

log_info "Current kernel settings:"
sysctl kern.corefile
sysctl kern.coredump
sysctl kern.sugid_coredump

log_info "ulimit -c = $(ulimit -c 2>/dev/null)"

log_ok "Completed successfully"

exit 0
