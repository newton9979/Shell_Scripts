#!/bin/bash
# ============================================================
# RHEL Environment Setup Script
# Author: Newton
# Date: 02/24/2026
# Installs:
#   - Basic utilities (tree, zip, wget)
#   - OpenJDK 21 (LTS)
#   - Apache Maven 3.9.12
#   - Apache Tomcat 9.0.115
# ============================================================

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

echo "Updating system..."
sudo yum update -y

# ------------------------------------------------------------
# Helper – append line to .bash_profile if not present
# ------------------------------------------------------------
append_to_profile_once() {
  local line="$1"
  grep -qxF "$line" "$PROFILE_FILE" 2>/dev/null || echo "$line" >> "$PROFILE_FILE"
}

# ------------------------------------------------------------
# Dependency installation
# ------------------------------------------------------------
ensure_dependencies() {
  echo "Installing dependency software: unzip tree git wget"
  sudo yum install -y unzip tree git wget
  echo "Dependencies installed."
}

# ------------------------------------------------------------
# Java installation
# ------------------------------------------------------------
java_install() {
  echo "Checking Java..."
  if ! java -version &>/dev/null; then
    echo "Java not found — installing OpenJDK 21..."
    sudo yum install -y java-21-openjdk-devel
    echo "Java installed."
  else
    echo "Java found: $(java -version 2>&1 | head -n 1)"
  fi
}

# ------------------------------------------------------------
# Maven installation
# ------------------------------------------------------------
Maven_install() {
  ensure_dependencies
  echo "Preparing to install Maven..."

  if [ ! -d "$MAVEN_DIR" ]; then
    cd /opt

    echo "Downloading Maven..."
    sudo wget -q "$MAVEN_URL"

    echo "Unzipping Maven..."
    sudo unzip -q "$MAVEN_ZIP"
    sudo rm -f "$MAVEN_ZIP"
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

# ------------------------------------------------------------
# Tomcat installation
# ------------------------------------------------------------
apache_tomcat_install() {
  ensure_dependencies
  echo "Preparing to install Tomcat..."

  if [ ! -d "$TOMCAT_DIR" ]; then
    cd /opt

    echo "Downloading Tomcat..."
    sudo wget -q "$TOMCAT_URL"

    echo "Unzipping Tomcat..."
    sudo unzip -q "$TOMCAT_ZIP"
    sudo rm -f "$TOMCAT_ZIP"
  else
    echo "Tomcat already installed at $TOMCAT_DIR"
  fi

  echo "Creating symlinks..."
  sudo ln -sf "$TOMCAT_DIR/bin/startup.sh" /usr/bin/startTomcat
  sudo ln -sf "$TOMCAT_DIR/bin/shutdown.sh" /usr/bin/stopTomcat
  sudo chmod +x "$TOMCAT_DIR/bin/"*.sh

  echo "Tomcat successfully installed."
  echo "Start using: startTomcat"
  echo "Stop using:  stopTomcat"
}

# ------------------------------------------------------------
# Verification
# ------------------------------------------------------------
verification() {
  echo "=============================="
  echo "Installed Software Versions:"
  echo "=============================="

  if java -version &>/dev/null; then
    echo "Java: $(java -version 2>&1 | head -n 1)"
  else
    echo "Java not installed."
  fi

  if mvn -version &>/dev/null; then
    echo "Maven: $(mvn -version | head -n 1)"
  else
    echo "Maven not installed."
  fi

  if [ -d "$TOMCAT_DIR" ]; then
    echo "Tomcat installed at: $TOMCAT_DIR"
  else
    echo "Tomcat not installed."
  fi
}

# ------------------------------------------------------------
# Install all
# ------------------------------------------------------------
install_all() {
  java_install
  ensure_dependencies
  Maven_install
  apache_tomcat_install
}

# ------------------------------------------------------------
# Menu
# ------------------------------------------------------------
main() {
  while true; do
    echo "====================================="
    echo "Please select an option:"
    echo "1. Install Java"
    echo "2. Install Dependency Software"
    echo "3. Install Maven"
    echo "4. Install Apache Tomcat"
    echo "5. Install All"
    echo "6. Verify Installations"
    echo "7. Exit"
    echo "====================================="
    read -rp "Enter choice (1–7): " choice

    case "$choice" in
      1) java_install ;;
      2) ensure_dependencies ;;
      3) Maven_install ;;
      4) apache_tomcat_install ;;
      5) install_all ;;
      6) verification ;;
      7) exit 0 ;;
      *) echo "Invalid option. Try again." ;;
    esac
  done
}

main
