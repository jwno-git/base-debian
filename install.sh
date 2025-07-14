set -e

read -p "Press Enter to continue..."

# #######################################################################################
# STEP 1: MOVE CONFIGURATION FILES
# #######################################################################################

echo ""
echo "=== STEP 1: Moving configuration files ==="

echo "Moving dotfiles and configs..."
mv /home/$USER/debgit/.config /home/$USER/
mv /home/$USER/debgit/.icons /home/$USER/
mv /home/$USER/debgit/.themes /home/$USER/
mv /home/$USER/debgit/.local /home/$USER/
mv /home/$USER/debgit/Documents /home/$USER/
mv /home/$USER/debgit/.root /home/$USER/
mv /home/$USER/debgit/Pictures /home/$USER/
mv /home/$USER/debgit/.vimrc /home/$USER/
mv /home/$USER/debgit/.bashrc /home/$USER/
mv /home/$USER/debgit/bookmarks.html /home/$USER/
sudo cp /home/$USER/.bashrc /root/

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
  curl \
  dunst \
  fastfetch \
  fbset \
  firefox-esr-l10n-en-ca \
  flatpak \
  fonts-font-awesome \
  fonts-terminus \
  gimp \
  google-chrome-stable \
  grim \
  imagemagick \
  jq \
  lf \
  libsixel-bin \
  libsixel-dev \
  libsixel1 \
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
  slurp \
  sway \
  swaybg \
  swappy \
  tar \
  tlp \
  tlp-rdw \
  unzip \
  vim \
  waybar \
  wireplumber \
  wf-recorder \
  wget \
  wlogout \
  wofi \
  xdg-desktop-portal-wlr \
  xwayland \
  zip

echo "Installing development packages (reduced set for hyprpicker only)..."
sudo apt install -y --no-install-recommends \
  build-essential \
  cmake \
  g++ \
  libcairo2-dev \
  libdrm-dev \
  libfuse2t64 \
  libgbm-dev \
  libgl1-mesa-dev \
  libinput-dev \
  libjpeg-dev \
  libmagic-dev \
  libpango1.0-dev \
  libpugixml-dev \
  libspa-0.2-bluetooth \
  libwayland-dev \
  libwebp-dev \
  libxkbcommon-dev \
  make \
  mpv \
  ninja-build \
  pkg-config \
  wayland-protocols

  sudo ldconfig

sleep 2

# #######################################################################################
# STEP 4: INSTALL FLATPAK APPLICATIONS & JOPLIN
# #######################################################################################

echo ""
echo "=== STEP 4: Installing Flatpak applications ==="

flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo

echo "Installing Flatpak applications..."
flatpak install -y --user flathub \
	org.kde.kdenlive \
	org.libreoffice.LibreOffice \
	org.gnome.eog \
	com.bitwarden.desktop \
	org.gnome.Calculator

echo "Configuring Flatpak overrides..."
flatpak override --user \
	--filesystem=xdg-config/gtk-3.0 \
	--filesystem=xdg-config/gtk-4.0 \
	--filesystem=/usr/share/themes:ro \
	--filesystem=/usr/share/icons:ro \
	--filesystem=home/.themes:ro \
	--filesystem=home/.icons:ro \
	--env=GTK_THEME=Tokyonight-Dark \
	--env=XCURSOR_THEME=RosePine \
	--env=XCURSOR_SIZE=32 \
	--socket=wayland \
	--talk-name=org.freedesktop.portal.Desktop

flatpak override --user org.kde.kdenlive \
  	--filesystem=home \
  	--env=QT_QPA_PLATFORM=wayland

flatpak override --user org.gnome.eog \
  	--filesystem=home

flatpak override --user org.libreoffice.Libreoffice \
	--filesystem=home

sleep 2

wget -O - https://raw.githubusercontent.com/laurent22/joplin/dev/Joplin_install_and_update.sh | bash

# #######################################################################################
# STEP 5: BUILD HYPR COMPONENTS FROM SOURCE (REDUCED SET)
# #######################################################################################

echo ""
echo "=== STEP 5: Building Hypr components from source (hyprpicker only) ==="

cd /home/$USER/
mkdir -p /home/$USER/.src

echo "Cloning repositories..."
git clone https://github.com/hyprwm/hyprutils /home/$USER/.src/hyprutils
git clone https://github.com/hyprwm/hyprlang /home/$USER/.src/hyprlang
git clone https://github.com/hyprwm/hyprwayland-scanner /home/$USER/.src/hyprwayland-scanner
git clone https://github.com/hyprwm/hyprgraphics /home/$USER/.src/hyprgraphics
git clone https://github.com/hyprwm/hyprpicker /home/$USER/.src/hyprpicker

echo "Building Hyprutils..."
cd /home/$USER/.src/hyprutils/
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
cmake --build ./build --config Release --target all -j`nproc 2>/dev/null || getconf NPROCESSORS_CONF`
sudo cmake --install build

echo "Building Hyprlang..."
cd /home/$USER/.src/hyprlang/
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
cmake --build ./build --config Release --target hyprlang -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
sudo cmake --install ./build

echo "Building Hyprwayland-Scanner..."
cd /home/$USER/.src/hyprwayland-scanner/
cmake -DCMAKE_INSTALL_PREFIX=/usr -B build
cmake --build build -j `nproc`
sudo cmake --install build

echo "Building Hyprgraphics..."
cd /home/$USER/.src/hyprgraphics/
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
cmake --build ./build --config Release --target all -j`nproc 2>/dev/null || getconf NPROCESSORS_CONF`
sudo cmake --install build

echo "Building Hyprpicker..."
cd /home/$USER/.src/hyprpicker/
cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
cmake --build ./build --config Release --target hyprpicker -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
sudo cmake --install ./build

cd /home/$USER/

sleep 2

# #######################################################################################
# STEP 6: INSTALL SYSTEMD-BOOT
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
# STEP 7: SET UP THEMES AND ICONS
# #######################################################################################

echo ""
echo "=== STEP 7: Setting up themes and icons ==="

echo "Extracting theme archives..."
cd /home/$USER/.icons/
tar -xf BreezeX-RosePine-Linux.tar.xz
mv BreezeX-RosePine-Linux RosePine

cd /home/$USER/.themes/
tar -xf Tokyonight-Dark.tar.xz

echo "Installing themes system-wide..."
sudo cp -r /home/$USER/.icons/RosePine /usr/share/icons/
sudo cp -r /home/$USER/.themes/Tokyonight-Dark /usr/share/themes/

echo "Setting up root user configuration..."
sudo mkdir -p /root/.src
sudo mv /home/$USER/.root/.config /root/
sudo mv /home/$USER/.root/.vimrc /root/
sudo mv /home/$USER/.root/debianroot.png /root/
sudo mv /home/$USER/.root/tlp.conf /etc/

echo "Making scripts executable..."
sudo chmod +x /home/$USER/.local/scripts/toggle_record.sh
sudo chmod +x /home/$USER/.local/scripts/toggle_term.sh
sudo chmod +x /home/$USER/.local/scripts/help_desk.sh
sudo chmod +x /home/$USER/.local/scripts/vim-term.sh
sudo chmod +x /home/$USER/.local/scripts/wofi-ssh.sh

sleep 2

# #######################################################################################
# STEP 8: CONFIGURE SYSTEM SERVICES
# #######################################################################################

echo ""
echo "=== STEP 8: Configuring system services ==="

echo "Creating Bluetooth desktop entry..."
cat > /home/$USER/.local/share/applications/bluetoothctl.desktop << 'EOF'
[Desktop Entry]
Name=Bluetooth
Comment=Command-line Bluetooth manager
Exec=bash -c '/usr/bin/pkexec systemctl start bluetooth && footclient --app-id=bluetooth --title="Bluetooth Control" bluetoothctl'
Icon=bluetooth
Terminal=false
Type=Application
Categories=System;Settings;
StartupNotify=true
EOF

echo "Configuring NetworkManager..."
sudo sed -i 's/managed=false/managed=true/g' /etc/NetworkManager/NetworkManager.conf
sudo sed -i 's/Adwaita/RosePine/g' /usr/share/icons/default/index.theme
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
rm -rf /home/$USER/.root
sudo systemctl enable NetworkManager
systemctl --user enable pipewire
systemctl --user enable pipewire-pulse  
systemctl --user enable wireplumber

sleep 2

# #######################################################################################
# STEP 9: SET UP NFTABLES FIREWALL
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
sudo systemctl enable tlp.service

sleep 2

# #######################################################################################
# INSTALLATION COMPLETE
# #######################################################################################

echo ""
echo "=================================================="
echo "  INSTALLATION COMPLETE!"
echo "=================================================="
