set -e

read -p "Press Enter to continue..."

echo "Acquiring packages for building"

sudo apt install build-essential gawk gpg wget curl

# #######################################################################################
# STEP 1: MOVE CONFIGURATION FILES
# #######################################################################################

echo ""
echo "=== STEP 1: Moving configuration files ==="

echo "Moving dotfiles and configs..."
mv $HOME/base-debian/.config $HOME/
mv $HOME/base-debian/Pictures $HOME/
mv $HOME/base-debian/.vimrc $HOME/
mv $HOME/base-debian/.bashrc $HOME/
sudo cp $HOME/.bashrc /root/
sudo cp $HOME/.vimrc /root/
sudo install -D $HOME/base-debian/.root/.config/fastfetch/config.jsonc /root/.config/fastfetch/config.jsonc
sudo install -D $HOME/Pictures/Logos/debianroot.png /root/Pictures/Logos/debianroot.png

# Install BLE (Bash Completion/Verification)
git clone --recursive https://github.com/akinomyoga/ble.sh.git ~/.local/src/ble.sh
sudo make -C ~/.local/src/ble.sh install PREFIX=/usr/local

# Adding Google Chrome Repo
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list

sudo apt update
sudo apt modernize-sources -y

sleep 2

# #######################################################################################
# STEP 2: SET UP ZRAM SWAP
# #######################################################################################

echo ""
echo "=== STEP 2: Setting up zram swap ==="

# Install required packages including zstd
sudo apt install -y util-linux zstd

# Load zram module
sudo modprobe zram

# Create systemd service for zram
sudo tee /etc/systemd/system/zram-swap.service > /dev/null << 'EOF'
[Unit]
Description=Configures zram swap device
After=multi-user.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/zram-start.sh
ExecStop=/usr/local/bin/zram-stop.sh
TimeoutSec=30

[Install]
WantedBy=multi-user.target
EOF

# Create start script
sudo tee /usr/local/bin/zram-start.sh > /dev/null << 'EOF'
#!/bin/bash
set -e

# Check if zram0 already exists
if [ -b /dev/zram0 ]; then
    echo "zram0 already exists, skipping setup"
    exit 0
fi

# Load zram module with number of devices
modprobe zram num_devices=1

# Check available compression algorithms
echo "Available compression algorithms:"
cat /sys/block/zram0/comp_algorithm

# Set compression algorithm to zstd (with fallback)
if grep -q zstd /sys/block/zram0/comp_algorithm; then
    echo zstd > /sys/block/zram0/comp_algorithm
    echo "Using zstd compression"
elif grep -q lz4 /sys/block/zram0/comp_algorithm; then
    echo lz4 > /sys/block/zram0/comp_algorithm
    echo "zstd not available, falling back to lz4"
else
    echo "Warning: Neither zstd nor lz4 available, using default"
fi

# Verify selected algorithm
echo "Selected algorithm: $(cat /sys/block/zram0/comp_algorithm | grep -o '\[.*\]' | tr -d '[]')"

# Set device size
echo 8G > /sys/block/zram0/disksize

# Format as swap
/sbin/mkswap /dev/zram0

# Enable swap with priority
/sbin/swapon -p 100 /dev/zram0

echo "zram swap enabled: 8G with $(cat /sys/block/zram0/comp_algorithm | grep -o '\[.*\]' | tr -d '[]') compression"
EOF

# Create stop script
sudo tee /usr/local/bin/zram-stop.sh > /dev/null << 'EOF'
#!/bin/bash
set -e

# Disable swap if active
if grep -q "/dev/zram0" /proc/swaps; then
    /sbin/swapoff /dev/zram0
    echo "zram swap disabled"
fi

# Reset device if it exists
if [ -b /dev/zram0 ]; then
    echo 1 > /sys/block/zram0/reset
fi

# Unload module
rmmod zram 2>/dev/null || true
EOF

# Make scripts executable
sudo chmod +x /usr/local/bin/zram-start.sh
sudo chmod +x /usr/local/bin/zram-stop.sh

# Create zram status check script
sudo tee /usr/local/bin/zram-status.sh > /dev/null << 'EOF'
#!/bin/bash

echo "=== zram Status ==="
if [ -b /dev/zram0 ]; then
    echo "zram device: /dev/zram0"
    echo "Size: $(cat /sys/block/zram0/disksize | numfmt --to=iec)"
    echo "Algorithm: $(cat /sys/block/zram0/comp_algorithm | grep -o '\[.*\]' | tr -d '[]')"
    echo "Used: $(cat /sys/block/zram0/mem_used_total | numfmt --to=iec)"
    echo "Compression ratio: $(cat /sys/block/zram0/compr_data_size):$(cat /sys/block/zram0/orig_data_size)"
    echo ""
    echo "=== Swap Status ==="
    /sbin/swapon --show
else
    echo "zram device not found"
fi
EOF

sudo chmod +x /usr/local/bin/zram-status.sh

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable zram-swap.service
sudo systemctl start zram-swap.service

/usr/local/bin/zram-status.sh

sleep 2

# #######################################################################################
# STEP 3: INSTALL PACKAGES
# #######################################################################################

echo ""
echo "=== STEP 3: Installing packages ==="

echo "Installing main packages..."
sudo apt install -y \
  bluez \
  brightnessctl \
  btop \
  chafa \
  cliphist \
  dunst \
  fastfetch \
  fbset \
  feh \
  firefox-esr-l10n-en-ca \
  flameshot \
  fonts-terminus \
  gimp \
  google-chrome-stable \
  lf \
  lxpolkit \
  network-manager \
  network-manager-applet \
  nftables \
  openssh-client \
  pavucontrol \
  pipewire \
  pipewire-pulse \
  pipewire-audio \
  pipewire-alsa \
  pkexec \
  psmisc \
  stterm \
  tar \
  tlp \
  tlp-rdw \
  unzip \
  vim \
  zip

  sudo ldconfig

sleep 2

# #######################################################################################
# STEP 4: INSTALL SYSTEMD-BOOT
# #######################################################################################

echo ""
echo "=== STEP 6: Installing systemd-boot ==="

echo "Installing systemd-boot packages..."
sudo apt install -y systemd-boot systemd-boot-efi
sudo bootctl --path=/boot/efi install

echo "Removing GRUB..."
sudo apt purge --allow-remove-essential -y \
  grub-common \
  grub-efi-amd64 \
  grub-efi-amd64-bin \
  grub-efi-amd64-signed \
  grub-efi-amd64-unsigned \
  grub2-common \
  shim-signed \
  ifupdown \
  nano \
  os-prober \
  vim-tiny \
  zutty

sudo apt autoremove --purge -y

echo ""
echo "Current EFI Boot Entries:"
sudo efibootmgr
echo ""
echo "Enter Boot ID of GRUB to delete (e.g. 0000):"
read -r BOOT_ID
sudo efibootmgr -b "$BOOT_ID" -B

sleep 2

# #######################################################################################
# STEP 5: CONFIGURE SYSTEM SERVICES
# #######################################################################################

echo ""
echo "=== STEP 8: Configuring system services ==="

echo "Configuring NetworkManager..."
sudo sed -i 's/managed=false/managed=true/g' /etc/NetworkManager/NetworkManager.conf
sudo rm -rf /etc/motd

echo "Setting up network interfaces..."
sudo tee /etc/network/interfaces > /dev/null << 'EOF'
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback
EOF

echo "Cleaning up and enabling services..."
sudo systemctl enable NetworkManager

sleep 2

# #######################################################################################
# STEP 6: SET UP NFTABLES FIREWALL
# #######################################################################################

echo ""
echo "=== STEP 9: Setting up nftables firewall ==="

echo "Creating nftables configuration..."
sudo tee /etc/nftables.conf > /dev/null << 'EOF'
#!/usr/sbin/nft -f

# Clear all prior state
flush ruleset

# Main firewall table
table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;
        
        # Allow loopback traffic (essential for system operation)
        iif "lo" accept comment "Accept any localhost traffic"
        
        # Allow established and related connections (return traffic)
        ct state established,related accept comment "Accept established/related connections"
        
        # Allow ICMP (ping, traceroute, etc.)
        ip protocol icmp accept comment "Accept ICMP"
        ip6 nexthdr ipv6-icmp accept comment "Accept ICMPv6"
        
        # Allow DHCP client (for getting IP from router)
        udp sport 67 udp dport 68 accept comment "Accept DHCP client"
        
        # Allow DNS responses (if using non-standard DNS servers)
        udp sport 53 accept comment "Accept DNS responses"
        tcp sport 53 accept comment "Accept DNS responses (TCP)"
        
        # Allow NTP (time synchronization)
        udp sport 123 accept comment "Accept NTP responses"
        
        # Allow local network discovery (mDNS/Avahi)
        udp dport 5353 accept comment "Accept mDNS (local discovery)"
        
        # Log dropped packets (useful for debugging, remove if too verbose)
        limit rate 5/minute log prefix "nftables dropped: " level info
        
        # Drop everything else
        counter drop
    }
    
    chain forward {
        type filter hook forward priority filter; policy drop;
        # No forwarding needed for desktop/laptop
    }
    
    chain output {
        type filter hook output priority filter; policy accept;
        
        # Allow all outbound traffic by default
        oif "lo" accept comment "Accept localhost traffic"
        ct state established,related accept comment "Accept established/related"
        ct state new accept comment "Allow new outbound connections"
    }
}

# Rate limiting table (optional - protects against some attacks)
table inet rate_limit {
    chain input {
        type filter hook input priority filter + 10; policy accept;
        
        # Rate limit ping to prevent ping floods
        ip protocol icmp limit rate 10/second accept
        ip6 nexthdr ipv6-icmp limit rate 10/second accept
    }
}
EOF

echo "Enabling and starting nftables..."
sudo systemctl enable nftables
sudo systemctl start nftables
sudo nft -f /etc/nftables.conf
sudo cp $HOME/base-debian/tlp.conf /etc/
sudo systemctl enable tlp.service

sleep 2

# #######################################################################################
# INSTALLATION COMPLETE
# #######################################################################################

echo ""
echo "=================================================="
echo "  INSTALLATION COMPLETE!"
echo "=================================================="
