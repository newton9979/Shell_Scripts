#!/bin/bash
set -euo pipefail

# -----------------------------
# Configuration
# -----------------------------
TOMCAT_VERSION="9.0.115"
TOMCAT_TAR="apache-tomcat-${TOMCAT_VERSION}.tar.gz"
TOMCAT_DIR="/opt/apache-tomcat-${TOMCAT_VERSION}"
TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/${TOMCAT_TAR}"

# -----------------------------
# Install dependencies
# -----------------------------
install_dependencies() {
  echo "Installing dependencies..."
  sudo yum install -y wget tar
}

# -----------------------------
# Install Tomcat
# -----------------------------
install_tomcat() {
  echo "Installing Apache Tomcat..."

  if [ -d "$TOMCAT_DIR" ]; then
    echo "Tomcat already exists at $TOMCAT_DIR"
    return
  fi

  cd /opt

  echo "Downloading Tomcat..."
  sudo wget "$TOMCAT_URL"

  echo "Extracting Tomcat..."
  sudo tar -xzf "$TOMCAT_TAR"
  sudo rm -f "$TOMCAT_TAR"

  echo "Setting permissions..."
  sudo chmod +x "$TOMCAT_DIR/bin/"*.sh
}

# -----------------------------
# Create shortcuts
# -----------------------------
create_shortcuts() {
  echo "Creating command shortcuts..."

  sudo ln -sf "$TOMCAT_DIR/bin/startup.sh" /usr/bin/startTomcat
  sudo ln -sf "$TOMCAT_DIR/bin/shutdown.sh" /usr/bin/stopTomcat
}

# -----------------------------
# Verify Installation
# -----------------------------
verify_tomcat() {
  echo "================================="
  echo "Tomcat Verification"
  echo "================================="

  if [ -d "$TOMCAT_DIR" ]; then
    echo "Tomcat installed at: $TOMCAT_DIR"
    echo "Start Tomcat: startTomcat"
    echo "Stop Tomcat : stopTomcat"
  else
    echo "Tomcat installation failed."
  fi
}

# -----------------------------
# Main
# -----------------------------
main() {
  install_dependencies
  install_tomcat
  create_shortcuts
  verify_tomcat
}

main
