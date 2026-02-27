#!/bin/bash
# ============================================================
# RHEL Environment Setup Script
# Author: Newton
# Date: 02/27/2026
# Installs:
#   - Basic utilities (tree, zip, wget)
#   - OpenJDK 21 (LTS)
#   - Apache Maven 3.9.12
#   - Apache Tomcat 9.0.115
#   - SonarQube 9.6.1 (Java 17) 
#   - 26.2.0.119303 (Java 21)  
# ============================================================
# --------- Must run as root ----------
if [[ $(id -u) -ne 0 ]]; then
  echo "[ERROR] Run this script as root or with sudo."
  exit 1
fi

echo "Updating system..."
sudo yum update -y

set -euo pipefail

# Versions
MAVEN_VERSION="3.9.12"
MAVEN_ZIP="apache-maven-${MAVEN_VERSION}-bin.zip"
MAVEN_DIR="/opt/apache-maven-${MAVEN_VERSION}"
MAVEN_URL="https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/${MAVEN_ZIP}"

TOMCAT_VERSION="9.0.115"
TOMCAT_ZIP="apache-tomcat-${TOMCAT_VERSION}.zip"
TOMCAT_DIR="/opt/apache-tomcat-${TOMCAT_VERSION}"
TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/${TOMCAT_ZIP}"

PROFILE_FILE="${HOME}/.bash_profile"

# Utility: Install Dependencies
ensure_dependencies() {
  echo "Installing dependency software: unzip tree git wget curl"
  sudo yum install -y unzip tree git wget curl
  echo "Dependencies installed."
}

# Utility: Append only once
append_to_profile_once() {
  local line="$1"
  if ! grep -qxF "$line" "$PROFILE_FILE"; then
    echo "$line" >> "$PROFILE_FILE"
  fi
}

# Timezone + NTP
timezone() {
    echo "[INFO] Configuring NTP & timezone..."
    timedatectl set-ntp true
    timedatectl set-timezone UTC
    systemctl restart chronyd || systemctl restart systemd-timesyncd
}

# Install Java 21 (OpenJDK)
java_install() {
  echo "Checking Java..."
  if ! java -version &>/dev/null; then
    echo "Java not found — installing OpenJDK 21..."
    sudo yum install -y java-21-openjdk-devel
  else
    echo "Java found: $(java -version 2>&1 | head -n 1)"
  fi
}

# Install Java 17 (Amazon Corretto)
install_java_17_version() {
    if ! java -version 2>&1 | grep -q "17"; then
        echo "[INFO] Java 17 not found. Installing Corretto 17..."
        rpm --import https://yum.corretto.aws/corretto.key
        curl -Lo /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo
        dnf install -y java-17-amazon-corretto-devel --nogpgcheck
        #alternatives --config java
        # Prevent interactive Java alternatives prompt
            alternatives --set java /usr/lib/jvm/java-17-amazon-corretto/bin/java
            alternatives --set javac /usr/lib/jvm/java-17-amazon-corretto/bin/javac
    else
        echo "[INFO] Java 17 already installed."
    fi
}

# Install Java 21 (Amazon Corretto)
install_java_21_version() {
    if ! java -version 2>&1 | grep -q "21"; then
        echo "[INFO] Java 21 not found. Installing Corretto 21..."
        rpm --import https://yum.corretto.aws/corretto.key
        curl -Lo /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo
        dnf install -y java-21-amazon-corretto-devel --nogpgcheck
          # Prevent 'alternatives --config java' prompt
            alternatives --set java /usr/lib/jvm/java-21-amazon-corretto/bin/java
            alternatives --set javac /usr/lib/jvm/java-21-amazon-corretto/bin/javac

    else
        echo "[INFO] Java 21 already installed."
    fi
}

# Kernel Params
Kernel_Parameters() {
    echo "[INFO] Configuring kernel parameters for SonarQube..."
    sysctl -w vm.max_map_count=262144
    echo 'vm.max_map_count=262144' >> /etc/sysctl.conf
}

# ---------- Install Maven ----------
Maven_install() {
  ensure_dependencies
  java_install

  if [ ! -d "$MAVEN_DIR" ]; then
    cd /opt
    wget -q "$MAVEN_URL"
    unzip -q "$MAVEN_ZIP"
    rm -f "$MAVEN_ZIP"
  else
    echo "Maven already installed at $MAVEN_DIR"
  fi

  echo "Configuring Maven environment variables..."
  append_to_profile_once "export M2_HOME=${MAVEN_DIR}"
  append_to_profile_once "export MAVEN_HOME=${MAVEN_DIR}"
  append_to_profile_once "export PATH=\$PATH:\$M2_HOME/bin"

  source "$PROFILE_FILE"
  echo "Maven configured."
}

# ---------- Verify Maven ----------
verify_maven() {
    echo "------ Maven Verification ------"
    if command -v mvn >/dev/null 2>&1; then
        echo "Maven Installed: $(mvn -v | head -n 1)"
    else
        echo "[ERROR] Maven NOT installed!"
    fi
}

# ---------- Install Tomcat ----------
apache_tomcat_install() {
  ensure_dependencies
  java_install

  if [ ! -d "$TOMCAT_DIR" ]; then
    cd /opt
    wget -q "$TOMCAT_URL"
    unzip -q "$TOMCAT_ZIP"
    rm -f "$TOMCAT_ZIP"
  else
    echo "Tomcat already installed at $TOMCAT_DIR"
  fi

  ln -sf "$TOMCAT_DIR/bin/startup.sh" /usr/bin/startTomcat
  ln -sf "$TOMCAT_DIR/bin/shutdown.sh" /usr/bin/stopTomcat
  chmod +x "$TOMCAT_DIR/bin/"*.sh

  echo "Tomcat Installed Successfully!"
}

# ---------- Verify Tomcat ----------
verify_tomcat() {
    echo "------ Tomcat Verification ------"
    if [ -d "$TOMCAT_DIR" ]; then
        echo "Tomcat Installed at: $TOMCAT_DIR"
    else
        echo "[ERROR] Tomcat NOT installed!"
    fi
}

# ---------- Install SonarQube 9.6.1 ----------
install_sonarqube_9.6.1() {
    timezone
    ensure_dependencies
    install_java_17_version
    Kernel_Parameters

    SONARQUBE_VERSION="9.6.1"
    SONARQUBE_ZIP="sonarqube-${SONARQUBE_VERSION}.zip"
    SONARQUBE_DIR="/opt/sonarqube-${SONARQUBE_VERSION}"
    SONARQUBE_URL="https://binaries.sonarsource.com/Distribution/sonarqube/${SONARQUBE_ZIP}"

    if [ ! -d "$SONARQUBE_DIR" ]; then
        cd /opt
        wget -q "$SONARQUBE_URL"
        unzip -q "$SONARQUBE_ZIP"
        rm -f "$SONARQUBE_ZIP"
    fi

    if ! id -u sonar >/dev/null; then
        useradd sonar
    fi

    chown -R sonar:sonar "$SONARQUBE_DIR"
    chmod -R 775 "$SONARQUBE_DIR"

    echo "export JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto" >> /home/sonar/.bash_profile
    echo "export PATH=\$JAVA_HOME/bin:\$PATH" >> /home/sonar/.bash_profile

    sudo -u sonar "$SONARQUBE_DIR/bin/sonar.sh" start
}

# ---------- Install SonarQube 26.x ----------
install_sonarqube_26.2.0.119303() {
    timezone
    ensure_dependencies
    install_java_21_version
    Kernel_Parameters
        

    SONARQUBE_VERSION="26.2.0.119303"
    SONARQUBE_ZIP="sonarqube-${SONARQUBE_VERSION}.zip"
    SONARQUBE_DIR="/opt/sonarqube-${SONARQUBE_VERSION}"
    SONARQUBE_URL="https://binaries.sonarsource.com/Distribution/sonarqube/${SONARQUBE_ZIP}"

    if [ ! -d "$SONARQUBE_DIR" ]; then
        cd /opt
        wget -q "$SONARQUBE_URL"
        unzip -q "$SONARQUBE_ZIP"
        rm -f "$SONARQUBE_ZIP"
    fi

    if ! id -u sonar >/dev/null; then
        useradd sonar
    fi

    chown -R sonar:sonar "$SONARQUBE_DIR"
    chmod -R 775 "$SONARQUBE_DIR"
}

# ---------- Verify SonarQube ----------
verify_sonarqube() {
    echo "------ SonarQube Verification ------"

    if id -u sonar >/dev/null; then
        echo "Sonar user exists."
    else
        echo "[ERROR] Sonar user not found."
    fi

    if sudo -u sonar /opt/sonarqube*/bin/sonar.sh status >/dev/null 2>&1; then
        echo "SonarQube is running."
    else
        echo "[ERROR] SonarQube NOT running."
    fi
}

# ---------- Main Menu ----------
main() {
  while true; do
    echo "====================================="
    echo "Please select an option:"
    echo "1) Install Maven"
    echo "2) Install Tomcat"
    echo "3) Install SonarQube 9.6.1"
    echo "4) Install SonarQube 26.2.0.119303"
    echo "5) Verify Maven"
    echo "6) Verify Tomcat"
    echo "7) Verify SonarQube"
    echo "8) Exit"
    echo "====================================="
    read -rp "Enter your choice: " choice

    case $choice in
      1) Maven_install ;;
      2) apache_tomcat_install ;;
      3) install_sonarqube_9.6.1 ;;
      4) install_sonarqube_26.2.0.119303 ;;
      5) verify_maven ;;
      6) verify_tomcat ;;
      7) verify_sonarqube ;;
      8) exit 0 ;;
      *) echo "Invalid option, try again." ;;
    esac
  done
}

main
