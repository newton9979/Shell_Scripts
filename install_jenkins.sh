#!/usr/bin/env bash
set -euo pipefail

# Jenkins Installation Script (based ONLY on your notes)
# Prerequisites:
#   - EC2 instance (t2.medium recommended)
#   - Run as root (or with sudo)
#   - Open TCP port 8080 in the Security Group

# -----------------------------
# Helper: require root
# -----------------------------
require_root() {
  if [[ "$EUID" -ne 0 ]]; then
    echo "Please run as root: sudo su -  or sudo $0"
    exit 1
  fi
}

# -----------------------------
# Main
# -----------------------------
main() {
  require_root

  echo ">>> Step 1: Ensure base utilities (wget, tree)"
  yum install -y wget tree

  echo ">>> Step 2: Add Jenkins repo & import key"
  wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
  rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

  echo ">>> Step 3: System upgrade (this may take a while)"
  yum upgrade -y

  echo ">>> Step 4: Install dependencies (fontconfig, Java 21), and Jenkins"
  yum install -y fontconfig java-21-openjdk
  yum install -y jenkins

  echo ">>> Step 5: Reload systemd and enable Jenkins"
  systemctl daemon-reload
  systemctl enable jenkins

  echo ">>> Step 6: Start Jenkins"
  systemctl start jenkins

  echo ">>> Step 7: Show Jenkins status (for quick verification)"
  systemctl status jenkins --no-pager || true

  echo ">>> Step 8: Print initial admin password"
  if [[ -f /var/lib/jenkins/secrets/initialAdminPassword ]]; then
    echo "Initial Admin Password:"
    cat /var/lib/jenkins/secrets/initialAdminPassword
    echo
  else
    echo "Initial admin password file not found yet. Jenkins may still be initializing. Try again in ~30-60 seconds:"
    echo "  cat /var/lib/jenkins/secrets/initialAdminPassword"
  fi

  echo "------------------------------------------------------------"
  echo "Jenkins is installing/running on port 8080."
  echo "Open your browser and go to:  http://<YOUR-SERVER-IP>:8080/"
  echo "Make sure port 8080 is allowed in the EC2 Security Group."
  echo
  echo "On the 'Unlock Jenkins' screen, paste the Initial Admin Password above."
  echo "Then click: 'Install suggested plugins'."
  echo
  echo "Create the first admin user (per your note):"
  echo "  Username: kkfunda"
  echo "  Password: kkfunda"
  echo "  Confirm:  kkfunda"
  echo "  Full Name: KK FUNDA"
  echo
  echo "Then: Save and Continue -> Save and Finish -> Start using Jenkins."
  echo "------------------------------------------------------------"
}

main "$@"
