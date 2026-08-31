#!/bin/bash
# shellcheck disable=SC1091,SC2164
#
# Secure WireGuard server installer & client manager
# for Debian, Ubuntu, Fedora, CentOS/Rocky/AlmaLinux, and Arch.
#
# Companion to openvpn-install.sh in this repo — same interactive style,
# but sets up a WireGuard server instead of OpenVPN.
#
# Usage:
#   sudo ./wireguard-install.sh          # first run: installs & configures the server, adds a client
#   sudo ./wireguard-install.sh          # subsequent runs: menu to add/remove clients or uninstall
#
# What it does:
#   - Detects your distro and installs wireguard-tools (+ qrencode for phone setup)
#   - Generates server keys, writes /etc/wireguard/wg0.conf
#   - Enables IP forwarding and sets up NAT via iptables/nftables (adjusted for UFW if present)
#   - Opens the WireGuard UDP port (and enables it through ufw/firewalld if active)
#   - Generates a client keypair + config, and prints/saves a QR code for mobile clients
#   - Lets you add or revoke additional clients later, or fully uninstall

set -e

SERVER_WG_NIC="wg0"
SERVER_WG_CONF="/etc/wireguard/${SERVER_WG_NIC}.conf"
CLIENT_DIR="/etc/wireguard/clients"

function isRoot() {
	if [ "$EUID" -ne 0 ]; then
		echo "This script must be run as root. Try: sudo $0"
		exit 1
	fi
}

function checkOS() {
	if [[ -e /etc/debian_version ]]; then
		source /etc/os-release
		OS="${ID}" # debian or ubuntu
	elif [[ -e /etc/fedora-release ]]; then
		OS="fedora"
	elif [[ -e /etc/centos-release || -e /etc/redhat-release ]]; then
		source /etc/os-release
		OS="${ID}" # centos, rocky, almalinux
	elif [[ -e /etc/arch-release ]]; then
		OS="arch"
	else
		echo "Unsupported OS. This script supports Debian, Ubuntu, Fedora, CentOS/Rocky/AlmaLinux, and Arch."
		exit 1
	fi
}

function installQuestions() {
	echo "WireGuard server setup"
	echo "The following questions configure your WireGuard server."
	echo ""

	# Detect public IPv4, offer to override
	SERVER_PUB_IP=$(curl -s -4 https://ifconfig.co 2>/dev/null || true)
	read -rp "Public IPv4 or hostname for this server [${SERVER_PUB_IP}]: " -e -i "${SERVER_PUB_IP}" SERVER_PUB_IP

	read -rp "WireGuard UDP port [51820]: " -e -i "51820" SERVER_PORT

	# Detect default interface for NAT
	SERVER_PUB_NIC=$(ip -4 route ls | grep default | awk '{print $5}' | head -1)
	read -rp "Public network interface [${SERVER_PUB_NIC}]: " -e -i "${SERVER_PUB_NIC}" SERVER_PUB_NIC

	read -rp "WireGuard internal subnet [10.66.66.0/24]: " -e -i "10.66.66.0/24" SERVER_WG_SUBNET
	SERVER_WG_IPV4=$(echo "${SERVER_WG_SUBNET}" | sed -E 's/0\/[0-9]+$/1/')

	read -rp "First client name: " -e -i "client1" CLIENT_NAME

	read -rp "DNS to push to clients [1.1.1.1]: " -e -i "1.1.1.1" CLIENT_DNS

	echo ""
	echo "Ready to install with these settings. Press any key to continue, Ctrl+C to abort."
	read -n1 -r -s -p ""
}

function installWireGuard() {
	case "${OS}" in
		debian|ubuntu)
			apt-get update
			apt-get install -y wireguard iptables resolvconf qrencode
			;;
		fedora)
			dnf install -y wireguard-tools iptables qrencode
			;;
		centos|rocky|almalinux)
			yum install -y epel-release
			yum install -y wireguard-tools iptables qrencode
			;;
		arch)
			pacman -Syu --noconfirm wireguard-tools qrencode
			;;
	esac

	mkdir -p /etc/wireguard "${CLIENT_DIR}"
	chmod 700 /etc/wireguard

	# Server keys
	SERVER_PRIV_KEY=$(wg genkey)
	SERVER_PUB_KEY=$(echo "${SERVER_PRIV_KEY}" | wg pubkey)

	# Enable IP forwarding persistently
	echo "net.ipv4.ip_forward=1" >/etc/sysctl.d/99-wireguard-forward.conf
	sysctl --system

	cat >"${SERVER_WG_CONF}" <<EOF
[Interface]
Address = ${SERVER_WG_IPV4}/24
ListenPort = ${SERVER_PORT}
PrivateKey = ${SERVER_PRIV_KEY}
PostUp = iptables -A FORWARD -i ${SERVER_WG_NIC} -j ACCEPT; iptables -t nat -A POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE
PostDown = iptables -D FORWARD -i ${SERVER_WG_NIC} -j ACCEPT; iptables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE
EOF
	chmod 600 "${SERVER_WG_CONF}"

	# Open the port on whichever firewall is active
	if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
		ufw allow "${SERVER_PORT}"/udp
	elif command -v firewall-cmd >/dev/null 2>&1 && systemctl is-active --quiet firewalld; then
		firewall-cmd --permanent --add-port="${SERVER_PORT}"/udp
		firewall-cmd --reload
	fi

	systemctl enable --now wg-quick@"${SERVER_WG_NIC}"

	newClient
	echo ""
	echo "✅ WireGuard is installed and running. Config: ${SERVER_WG_CONF}"
}

function newClient() {
	CLIENT_PRIV_KEY=$(wg genkey)
	CLIENT_PUB_KEY=$(echo "${CLIENT_PRIV_KEY}" | wg pubkey)
	CLIENT_PSK=$(wg genpsk)

	# Pick the next free IP in the subnet based on existing peers
	LAST_OCTET=$(grep -c "^\[Peer\]" "${SERVER_WG_CONF}" 2>/dev/null || echo 0)
	CLIENT_WG_IPV4=$(echo "${SERVER_WG_IPV4}" | sed -E "s/\.[0-9]+$/.$((LAST_OCTET + 2))/")

	cat >>"${SERVER_WG_CONF}" <<EOF

[Peer]
# ${CLIENT_NAME}
PublicKey = ${CLIENT_PUB_KEY}
PresharedKey = ${CLIENT_PSK}
AllowedIPs = ${CLIENT_WG_IPV4}/32
EOF

	CLIENT_CONF="${CLIENT_DIR}/${CLIENT_NAME}.conf"
	cat >"${CLIENT_CONF}" <<EOF
[Interface]
PrivateKey = ${CLIENT_PRIV_KEY}
Address = ${CLIENT_WG_IPV4}/24
DNS = ${CLIENT_DNS}

[Peer]
PublicKey = ${SERVER_PUB_KEY}
PresharedKey = ${CLIENT_PSK}
Endpoint = ${SERVER_PUB_IP}:${SERVER_PORT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF
	chmod 600 "${CLIENT_CONF}"

	systemctl reload-or-restart wg-quick@"${SERVER_WG_NIC}" 2>/dev/null || wg syncconf "${SERVER_WG_NIC}" <(wg-quick strip "${SERVER_WG_NIC}")

	echo ""
	echo "Client config saved to ${CLIENT_CONF}"
	if command -v qrencode >/dev/null 2>&1; then
		echo "Scan this to import on mobile:"
		qrencode -t ansiutf8 <"${CLIENT_CONF}"
	fi
}

function revokeClient() {
	echo "Existing clients:"
	grep "^#" "${SERVER_WG_CONF}" | sed 's/# //'
	read -rp "Client name to revoke: " -e REVOKE_NAME

	# Remove the [Peer] block whose comment matches the client name
	sed -i "/^# ${REVOKE_NAME}$/,/^AllowedIPs/d" "${SERVER_WG_CONF}"
	sed -i '/^\[Peer\]$/{ N; /^\[Peer\]\n$/d }' "${SERVER_WG_CONF}"
	rm -f "${CLIENT_DIR}/${REVOKE_NAME}.conf"

	systemctl reload-or-restart wg-quick@"${SERVER_WG_NIC}" 2>/dev/null || wg syncconf "${SERVER_WG_NIC}" <(wg-quick strip "${SERVER_WG_NIC}")
	echo "Revoked ${REVOKE_NAME}."
}

function uninstallWg() {
	read -rp "This removes WireGuard and all configs. Continue? [y/n]: " -e -i "n" REMOVE
	if [[ $REMOVE == "y" ]]; then
		systemctl disable --now wg-quick@"${SERVER_WG_NIC}"
		case "${OS}" in
			debian|ubuntu) apt-get remove -y wireguard ;;
			fedora) dnf remove -y wireguard-tools ;;
			centos|rocky|almalinux) yum remove -y wireguard-tools ;;
			arch) pacman -Rns --noconfirm wireguard-tools ;;
		esac
		rm -rf /etc/wireguard
		echo "WireGuard removed."
	fi
}

function manageMenu() {
	echo "WireGuard is already installed. What do you want to do?"
	echo "   1) Add a new client"
	echo "   2) Revoke an existing client"
	echo "   3) Uninstall WireGuard"
	echo "   4) Exit"
	read -rp "Select an option [1-4]: " MENU_OPTION
	case "${MENU_OPTION}" in
		1)
			read -rp "New client name: " -e CLIENT_NAME
			read -rp "DNS to push to client [1.1.1.1]: " -e -i "1.1.1.1" CLIENT_DNS
			newClient
			;;
		2) revokeClient ;;
		3) uninstallWg ;;
		4) exit 0 ;;
		*) echo "Invalid option." ;;
	esac
}

# --- main ---
isRoot
checkOS

if [[ -e ${SERVER_WG_CONF} ]]; then
	manageMenu
else
	installQuestions
	installWireGuard
fi