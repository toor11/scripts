--- Script Update Debian and Wordpress
```bash
#!/bin/bash
# auto-maintenance.sh
# Debian + WordPress automatic maintenance script

LOGFILE="/var/log/auto-maintenance.log"
DATE=$(date '+%Y-%m-%d %H:%M:%S')
echo "==== Maintenance started at $DATE ====" >> "$LOGFILE"

# --- Step 1: Enable unattended-upgrades if not already ---
if ! dpkg -l | grep -q unattended-upgrades; then
    echo "[INFO] Installing unattended-upgrades..." | tee -a "$LOGFILE"
    apt update && apt install -y unattended-upgrades apt-listchanges
    dpkg-reconfigure --priority=low unattended-upgrades
fi

# --- Step 2: Fix duplicate repo entries ---
echo "[INFO] Checking for duplicate APT repos..." | tee -a "$LOGFILE"
awk '/^deb / {print $0}' /etc/apt/sources.list /etc/apt/sources.list.d/* \
    2>/dev/null | sort | uniq -d | while read -r line; do
    echo "[FIX] Duplicate repo found: $line" | tee -a "$LOGFILE"
done

# --- Step 3: Refresh all apt GPG keys ---
echo "[INFO] Refreshing GPG keys..." | tee -a "$LOGFILE"
apt-key list 2>/dev/null | grep -E 'expired|EXPIRED' && apt-key adv --refresh-keys --keyserver keyserver.ubuntu.com

# --- Step 4: System update ---
echo "[INFO] Running apt update & upgrade..." | tee -a "$LOGFILE"
apt update && apt -y upgrade && apt -y autoremove && apt -y autoclean

# --- Step 5: WordPress updates ---
WP_PATH="/var/www/html"
if [ -d "$WP_PATH" ] && [ -f "$WP_PATH/wp-config.php" ]; then
    echo "[INFO] Updating WordPress..." | tee -a "$LOGFILE"
    if ! command -v wp &>/dev/null; then
        echo "[INFO] Installing WP-CLI..." | tee -a "$LOGFILE"
        curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
        php wp-cli.phar --info && chmod +x wp-cli.phar && mv wp-cli.phar /usr/local/bin/wp
    fi
    cd "$WP_PATH" || exit
    wp core update --allow-root | tee -a "$LOGFILE"
    wp plugin update --all --allow-root | tee -a "$LOGFILE"
    wp theme update --all --allow-root | tee -a "$LOGFILE"
else
    echo "[SKIP] No WordPress installation found at $WP_PATH" | tee -a "$LOGFILE"
fi

echo "==== Maintenance finished at $(date '+%Y-%m-%d %H:%M:%S') ====" >> "$LOGFILE"

```

Install

```
sudo nano /usr/local/bin/auto-maintenance.sh

sudo chmod +x /usr/local/bin/auto-maintenance.sh
```

CRON Job

```
sudo crontab -e

0 3 * * * /usr/local/bin/auto-maintenance.sh
```
