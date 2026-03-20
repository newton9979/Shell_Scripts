#!/bin/bash
set -euo pipefail

echo "==== Nexus 3.x Installation & Startup (systemctl via 'nexus' user) ===="

# ---------------------------
# CONFIG
# ---------------------------
NEXUS_TGZ="nexus-3.70.1-02-java8-unix.tar.gz"
NEXUS_DIR_EXTRACTED="nexus-3.70.1-02"
NEXUS_HOME="/opt/nexus"
NEXUS_DATA="/opt/sonatype-work/nexus3"
NEXUS_USER="nexus"
NEXUS_GROUP="nexus"
NEXUS_PORT="8081"

# ---------------------------
# PRECHECKS
# ---------------------------
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root (use sudo)."
  exit 1
fi

# ---------------------------
# PREREQS
# ---------------------------
echo "[1/10] Installing prerequisites..."
yum install -y wget curl tar tree

# ---------------------------
# JAVA 8 (Amazon Corretto)
# ---------------------------
echo "[2/10] Installing Amazon Corretto Java 8 (if missing)..."
if ! java -version 2>&1 | grep -q '1\.8\.0'; then
  rpm --import https://yum.corretto.aws/corretto.key || true
  curl -Lo /etc/yum.repos.d/corretto.repo https://yum.corretto.aws/corretto.repo
  yum install -y java-1.8.0-amazon-corretto-devel --nogpgcheck
fi
java -version

# ---------------------------
# DOWNLOAD & INSTALL NEXUS
# ---------------------------
echo "[3/10] Fetching and installing Nexus..."
cd /opt
if [[ ! -f "/opt/${NEXUS_TGZ}" ]]; then
  wget -q https://download.sonatype.com/nexus/3/${NEXUS_TGZ}
fi
if [[ ! -d "/opt/${NEXUS_DIR_EXTRACTED}" && ! -d "${NEXUS_HOME}" ]]; then
  tar -zxf ${NEXUS_TGZ}
fi
if [[ -d "/opt/${NEXUS_DIR_EXTRACTED}" && ! -d "${NEXUS_HOME}" ]]; then
  mv "/opt/${NEXUS_DIR_EXTRACTED}" "${NEXUS_HOME}"
fi

# ---------------------------
# CREATE NEXUS USER
# ---------------------------
echo "[4/10] Ensuring '${NEXUS_USER}' user exists..."
if ! id -u "${NEXUS_USER}" >/dev/null 2>&1; then
  useradd --system --create-home --shell /bin/bash "${NEXUS_USER}"
fi

# ---------------------------
# PERMISSIONS
# ---------------------------
echo "[5/10] Setting permissions..."
mkdir -p "${NEXUS_DATA}"
chown -R ${NEXUS_USER}:${NEXUS_GROUP} "${NEXUS_HOME}" "${NEXUS_DATA}"
chmod -R 775 "${NEXUS_HOME}" "${NEXUS_DATA}"

# ---------------------------
# CONFIGURE run_as_user
# ---------------------------
echo "[6/10] Configuring Nexus to run as '${NEXUS_USER}'..."
NEXUS_RC="${NEXUS_HOME}/bin/nexus.rc"
if grep -q '^#\?run_as_user=' "${NEXUS_RC}" 2>/dev/null; then
  sed -i "s|^#\?run_as_user=.*|run_as_user=\"${NEXUS_USER}\"|g" "${NEXUS_RC}"
else
  echo "run_as_user=\"${NEXUS_USER}\"" >> "${NEXUS_RC}"
fi

# ---------------------------
# CREATE SYSTEMD SERVICE
# ---------------------------
echo "[7/10] Creating systemd service (User=nexus)..."
cat >/etc/systemd/system/nexus.service <<'EOF'
[Unit]
Description=nexus service
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
ExecStart=/opt/nexus/bin/nexus start
ExecStop=/opt/nexus/bin/nexus stop
User=nexus
Restart=on-abort
TimeoutSec=600

[Install]
WantedBy=multi-user.target
EOF

# We need a daemon-reload; this still requires root. Do it now.
systemctl daemon-reload

# ---------------------------
# SUDOERS: ALLOW 'nexus' TO RUN LIMITED systemctl COMMANDS
# ---------------------------
echo "[8/10] Granting minimal sudo rights for systemctl (nexus only)..."
SUDOERS_FILE="/etc/sudoers.d/90-nexus-systemctl"
# On many distros, systemctl lives in /usr/bin; a /bin symlink may also exist. Allow both to be safe.
cat > "${SUDOERS_FILE}" <<'EOF'
# Allow nexus user to manage only the nexus service with systemctl without password
Cmnd_Alias NEXUS_CMDS = /usr/bin/systemctl status nexus, \
                        /usr/bin/systemctl start nexus, \
                        /usr/bin/systemctl stop nexus, \
                        /usr/bin/systemctl enable nexus, \
                        /usr/bin/systemctl daemon-reload, \
                        /bin/systemctl status nexus, \
                        /bin/systemctl start nexus, \
                        /bin/systemctl stop nexus, \
                        /bin/systemctl enable nexus, \
                        /bin/systemctl daemon-reload
nexus ALL=(ALL) NOPASSWD: NEXUS_CMDS
EOF
chmod 440 "${SUDOERS_FILE}"

# ---------------------------
# OPTIONAL: sysvinit link (legacy support)
# ---------------------------
echo "[9/10] Ensuring /etc/init.d symlink exists (legacy compatibility)..."
echo "[9/10] Checking /etc/init.d directory..."

if [ -d "/etc/init.d" ]; then
    echo "/etc/init.d exists — creating nexus symlink..."
    ln -sf "${NEXUS_HOME}/bin/nexus" /etc/init.d/nexus
else
    echo "/etc/init.d does NOT exist — creating directory..."
    mkdir -p /etc/init.d
    echo "Directory created. Creating nexus symlink now..."
    ln -sf "${NEXUS_HOME}/bin/nexus" /etc/init.d/nexus
fi

# ---------------------------
# STEP 17 & 18: RUN systemctl AS 'nexus' USER
# ---------------------------
echo "[10/10] Enabling & starting Nexus service AS '${NEXUS_USER}'..."
# These will run as nexus user using the limited sudo permissions above
su - ${NEXUS_USER} -c "sudo systemctl status nexus || true"
su - ${NEXUS_USER} -c "sudo systemctl enable nexus"
su - ${NEXUS_USER} -c "sudo systemctl daemon-reload"
su - ${NEXUS_USER} -c "sudo systemctl start nexus"
su - ${NEXUS_USER} -c "sudo systemctl status nexus || true"

# ---------------------------
# OUTPUT: URL & ADMIN PASSWORD (Step 19 & 20)
# ---------------------------
echo
echo "=========================================="
echo "     ✅ Nexus installation completed"
echo "=========================================="
IP="$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 || echo <server-ip>)"
echo "Access URL   : http://${IP}:${NEXUS_PORT}/"
echo "Login        : Click 'Sign in' (top-right)"
echo "Username     : admin"
if [[ -f "${NEXUS_DATA}/admin.password" ]]; then
  echo "Password     : $(cat "${NEXUS_DATA}/admin.password")"
else
  echo "Password file not ready yet; will appear at:"
  echo "  ${NEXUS_DATA}/admin.password"
fi
echo "=========================================="
