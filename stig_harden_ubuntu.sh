#!/bin/bash

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

echo "Starting DISA-STIG Hardening for Ubuntu 22.04..."

# Update system
apt update && apt upgrade -y

# Install required packages
apt install -y ufw auditd audispd-plugins fail2ban libpam-pwquality

# --- STIG Requirement: V-260480 - Configure SSH ---
SSHD_CONFIG="/etc/ssh/sshd_config"
SSHD_CONFIG_DIR="/etc/ssh/sshd_config.d"
mkdir -p "$SSHD_CONFIG_DIR"

# Backup original SSH config
cp $SSHD_CONFIG ${SSHD_CONFIG}.bak

# Create STIG-compliant SSH config
cat << EOF > "$SSHD_CONFIG_DIR/99-stig.conf"
# STIG SSH Hardening
Port 22
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
MaxAuthTries 4
ClientAliveInterval 600
ClientAliveCountMax 0
AllowTcpForwarding no
AllowUsers ubuntu  # Replace 'ubuntu' with your username
EOF

# Include the custom config in main sshd_config
echo "Include /etc/ssh/sshd_config.d/*.conf" >> $SSHD_CONFIG

# Test SSH config and restart
ssh -t $SSHD_CONFIG && systemctl restart sshd

# --- STIG Requirement: V-260485 - Configure Firewall ---
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp  # SSH
ufw --force enable

# --- STIG Requirement: V-260492 - Configure Audit System ---
cat << EOF > /etc/audit/audit.rules
# STIG Audit Rules
-D
-b 8192
-f 1
-a always,exit -F arch=b64 -S adjtimex,settimeofday -F key=time-change
-a always,exit -F arch=b64 -S clock_settime -F key=time-change
-w /etc/localtime -p wa -k time-change
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
EOF

# Restart auditd
systemctl enable auditd
systemctl restart auditd

# --- STIG Requirement: V-260498 - Password Policy ---
cat << EOF > /etc/security/pwquality.conf
minlen = 14
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
difok = 8
EOF

# Update PAM configuration
sed -i '/pam_pwquality.so/s/$/ retry=3/' /etc/pam.d/common-password

# --- STIG Requirement: V-260504 - Disable Unused Filesystems ---
cat << EOF > /etc/modprobe.d/stig.conf
install cramfs /bin/true
install freevxfs /bin/true
install jffs2 /bin/true
install hfs /bin/true
install hfsplus /bin/true
install squashfs /bin/true
install udf /bin/true
install vfat /bin/true
EOF

# --- STIG Requirement: V-260510 - Secure Kernel Parameters ---
cat << EOF > /etc/sysctl.d/99-stig.conf
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.tcp_syncookies = 1
kernel.randomize_va_space = 2
fs.suid_dumpable = 0
EOF
sysctl -p /etc/sysctl.d/99-stig.conf

# --- STIG Requirement: V-260515 - File Permissions ---
chmod 644 /etc/passwd
chmod 600 /etc/shadow
chmod 644 /etc/group
chmod 600 /etc/gshadow
chmod 600 /etc/ssh/sshd_config
chmod -R 700 /etc/ssh/sshd_config.d

# --- STIG Requirement: V-260520 - Configure Fail2ban ---
cat << EOF > /etc/fail2ban/jail.local
[DEFAULT]
bantime = 3600
maxretry = 5

[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
EOF
systemctl enable fail2ban
systemctl restart fail2ban

# --- STIG Requirement: V-260525 - Remove Unnecessary Packages ---
apt purge -y telnet rsh-server nis

echo "Basic STIG Hardening Complete!"
echo "Next Steps:"
echo "1. Replace 'ubuntu' with your username in $SSHD_CONFIG_DIR/99-stig.conf"
echo "2. Copy your SSH public key to ~/.ssh/authorized_keys"
echo "3. Test SSH access before logging out"
echo "4. Review full STIG (V-260469 - V-260676) for additional requirements"
