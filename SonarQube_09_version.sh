#!/usr/bin/env bash
# RHEL 8.x - SonarQube install script (run as root) - Java 17 only
set -Eeuo pipefail
trap 'rc=$?; echo "[ERROR] exit=$rc at ${BASH_SOURCE##*/}:$LINENO (func: ${FUNCNAME[1]:-main})"; exit $rc' ERR

# Optional debug toggle
if [[ "${DEBUG:-0}" == "1" ]]; then
  export PS4='+ $(date "+%F %T") ${BASH_SOURCE##*/}:${LINENO}:${FUNCNAME[0]:-main}: '
  set -x
fi

# --- Safety: root check ---
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Please run as root"
  exit 1
fi

# --- Globals (override with env if desired) ---
PKG_MGR="$(command -v dnf || command -v yum)"
SONARQUBE_VERSION="${SONARQUBE_VERSION:-9.9.0.65466}"   # Recommend 9.9 LTS+ for Java 17
SONARQUBE_DIR="/opt/sonarqube"
SONARQUBE_ZIP="/tmp/sonarqube-${SONARQUBE_VERSION}.zip"
SONAR_USER="sonar"
SONAR_GROUP="sonar"
JAVA_HOME_DIR="/usr/lib/jvm/java-17-amazon-corretto"   # fixed to Java 17

# --- Utilities ---
log() { echo -e "\n#### $* ####"; }

ensure_dependencies() {
  log "Installing required dependencies"
  "$PKG_MGR" -y install unzip tree git wget curl chrony
  systemctl enable --now chronyd
}

set_timezone_utc() {
  log "Setting timezone to UTC (optional)"
  timedatectl set-timezone UTC || true
  timedatectl || true
}

install_java_17() {
  log "Installing Java 17 (Amazon Corretto)"
  rpm --import https://yum.corretto.aws/corretto.key || true
  curl -fsSL -o /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo
  "$PKG_MGR" -y install java-17-amazon-corretto-devel

  # Set alternatives (make default)
  alternatives --install /usr/bin/java  java  "${JAVA_HOME_DIR}/bin/java"  2
  alternatives --install /usr/bin/javac javac "${JAVA_HOME_DIR}/bin/javac" 2
  alternatives --set java  "${JAVA_HOME_DIR}/bin/java"
  alternatives --set javac "${JAVA_HOME_DIR}/bin/javac"

  echo "JAVA is now:"
  java -version 2>&1 | sed 's/^/  /'
}

apply_kernel_parameters() {
  log "Setting required kernel parameter vm.max_map_count=262144"
  cat >>/etc/sysctl.d/99-sonarqube.conf <<'EOF'
vm.max_map_count=262144
EOF
  sysctl --system
}

ensure_sonar_user() {
  log "Creating service user 'sonar' (if missing)"
  if id "$SONAR_USER" &>/dev/null; then
    echo "User '$SONAR_USER' already exists."
  else
    useradd -m -d "/home/${SONAR_USER}" -s /bin/bash "$SONAR_USER"
    # Optional: admin convenience
    echo "${SONAR_USER}   ALL=(ALL)       NOPASSWD: ALL" >> /etc/sudoers
  fi
}

install_sonarqube() {
  log "Downloading and installing SonarQube ${SONARQUBE_VERSION}"
  if [[ -d "${SONARQUBE_DIR}" ]]; then
    echo "SonarQube already present at ${SONARQUBE_DIR}"
    return
  fi

  wget -O "${SONARQUBE_ZIP}" "https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-${SONARQUBE_VERSION}.zip"
  unzip -q "${SONARQUBE_ZIP}" -d /opt
  mv "/opt/sonarqube-${SONARQUBE_VERSION}" "${SONARQUBE_DIR}"
  chown -R "${SONAR_USER}:${SONAR_GROUP}" "${SONARQUBE_DIR}"
  chmod -R 775 "${SONARQUBE_DIR}"
  rm -f "${SONARQUBE_ZIP}"

  echo "Installed to ${SONARQUBE_DIR}"
}

create_systemd_service() {
  log "Creating systemd service for SonarQube"
  cat >/etc/systemd/system/sonarqube.service <<EOF
[Unit]
Description=SonarQube service
After=network.target

[Service]
Type=forking
User=${SONAR_USER}
Group=${SONAR_GROUP}
Environment="JAVA_HOME=${JAVA_HOME_DIR}"
LimitNOFILE=65536
LimitNPROC=4096
ExecStart=${SONARQUBE_DIR}/bin/linux-x86-64/sonar.sh start
ExecStop=${SONARQUBE_DIR}/bin/linux-x86-64/sonar.sh stop
Restart=on-failure
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable sonarqube.service
}

add_bash_profile() {
  log "Adding .bash_profile for ${SONAR_USER} (optional)"
  cat >>"/home/${SONAR_USER}/.bash_profile" <<EOF
export JAVA_HOME=${JAVA_HOME_DIR}
export PATH=\$JAVA_HOME/bin:\$PATH
EOF
  chown "${SONAR_USER}:${SONAR_GROUP}" "/home/${SONAR_USER}/.bash_profile"
  chmod 644 "/home/${SONAR_USER}/.bash_profile"
}

open_firewall_port() {
  log "Opening firewall port 9000 (if firewalld is running)"
  if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-port=9000/tcp
    firewall-cmd --reload
  else
    echo "firewalld not active; skipping."
  fi
}

start_sonarqube_service() {
  log "Starting SonarQube (systemd)"
  systemctl start sonarqube.service
  sleep 3
  systemctl --no-pager --full status sonarqube.service || true
}

# --- Main ---
sonarqube_main() {
  ensure_dependencies
  set_timezone_utc
  ensure_sonar_user
  install_java_17
  apply_kernel_parameters
  install_sonarqube
  create_systemd_service
  add_bash_profile
  open_firewall_port
  start_sonarqube_service

  echo -e "\nSonarQube installation and setup completed."
  echo "Access:  http://<server-ip>:9000"
  echo "Logs:    ${SONARQUBE_DIR}/logs/"
  echo "Service: systemctl status sonarqube"
}

sonarqube_main "$@"