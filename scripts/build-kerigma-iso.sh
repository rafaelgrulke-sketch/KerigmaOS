#!/bin/bash
# ==============================================================================
# KERIGMA OS - BUILD SCRIPT DEFINITIVO (ALL-IN EDITION)
# Localização: scripts/build-kerigma-iso.sh
# ==============================================================================
set -e

# Garante que o script está a correr como root
if [ "$(id -u)" -ne 0 ]; then
    exec sudo "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

export WORKDIR="$REPO_ROOT/kerigma_build"
export CHROOT="$WORKDIR/chroot"
export ISODIR="$WORKDIR/iso"
export DEBIAN_FRONTEND=noninteractive
export LC_ALL=POSIX

echo "=== [1/8] Limpando ambiente anterior e preparando diretórios ==="
rm -rf "$WORKDIR"
mkdir -p "$CHROOT" "$ISODIR/live" "$ISODIR/boot/grub" "$ISODIR/EFI/boot"

echo "=== [2/8] Executando Debootstrap (Debian Bookworm Minimal) ==="
debootstrap --arch=amd64 --variant=minbase bookworm "$CHROOT" http://deb.debian.org/debian/

echo "=== [3/8] Montando Sistemas de Arquivos Virtuais do Kernel (LFS Cap. 7.3) ==="
mkdir -pv "$CHROOT/dev" "$CHROOT/dev/pts" "$CHROOT/proc" "$CHROOT/sys" "$CHROOT/run"
mount -v --bind /dev "$CHROOT/dev"
mount -v --bind /dev/pts "$CHROOT/dev/pts"
mount -vt proc proc "$CHROOT/proc"
mount -vt sysfs sysfs "$CHROOT/sys"
mount -vt tmpfs tmpfs "$CHROOT/run"

if [ -h "$CHROOT/dev/shm" ]; then
    mkdir -pv "$CHROOT/$(readlink "$CHROOT/dev/shm")"
else
    mount -t tmpfs -o nosuid,nodev tmpfs "$CHROOT/dev/shm"
fi

echo "=== [4/8] Configurando o Sistema Base dentro do Chroot (LFS Cap. 7.5, 7.6 e 8) ==="
cat << 'EOF' | chroot "$CHROOT" /usr/bin/env -i HOME=/root TERM="$TERM" DEBIAN_FRONTEND=noninteractive PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash
set -e

# 1. Criação rigorosa da Hierarquia FHS
mkdir -pv /boot /boot/grub /boot/efi /home /mnt /opt /srv
mkdir -pv /etc/opt /etc/sysconfig /etc/calamares/modules /etc/skel/Desktop /etc/xdg/autostart
mkdir -pv /lib/firmware /var/lib/hwclock
install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp

ln -sfv /proc/self/mounts /etc/mtab

# 2. Repositórios completos
cat > /etc/apt/sources.list << "SOURCES"
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
SOURCES

apt-get update

# 3. Kernel, Headers, bc (necessário para compilar driver Wi-Fi), Live Boot e Firmwares
apt-get install -y \
    linux-image-amd64 linux-headers-amd64 live-boot systemd-sysv initramfs-tools \
    firmware-linux firmware-linux-free firmware-linux-nonfree \
    firmware-misc-nonfree firmware-realtek firmware-atheros \
    firmware-iwlwifi firmware-brcm80211 firmware-amd-graphics \
    intel-microcode amd64-microcode dkms build-essential bc kmod cpio libssl-dev git curl wget

# 4. Utilitários de Sistema, Compressão, GRUB Completo (UEFI + BIOS) e Calamares
apt-get install -y \
    locales tzdata sudo bash-completion \
    rsync parted gparted dosfstools mtools e2fsprogs btrfs-progs xfsprogs ntfs-3g \
    squashfs-tools xorriso isolinux syslinux-common syslinux-efi \
    grub-common grub2-common grub-pc-bin grub-efi-amd64 grub-efi-amd64-bin grub-efi-amd64-signed shim-signed efibootmgr os-prober \
    calamares calamares-settings-debian

# 5. Ambiente Gráfico KDE Plasma + Estilo macOS + Rede + Áudio + Impressoras + Apps
apt-get install -y \
    plasma-desktop plasma-nm plasma-pa bluedevil powerdevil sddm \
    kde-config-gtk-style breeze-gtk-theme plank \
    konsole dolphin ark kde-spectacle gwenview okular kate vlc \
    network-manager bluez pipewire pipewire-audio pipewire-pulse wireplumber \
    cups system-config-printer ufw \
    python3 python3-pip python3-pyqt5 python3-requests kiwix-tools

# 6. Configuração de Locales e Fuso Horário
echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG=pt_BR.UTF-8 LC_ALL=pt_BR.UTF-8
ln -sfv /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

# 7. Configuração de Rede
echo "kerigma-os" > /etc/hostname
cat > /etc/hosts << "HOSTS"
127.0.0.1   localhost kerigma-os
::1         localhost kerigma-os
HOSTS

cat > /etc/nsswitch.conf << "NSS"
passwd: files systemd
group: files systemd
shadow: files
hosts: files mdns4_minimal [NOTFOUND=return] dns
networks: files
protocols: files
services: files
ethers: files
rpc: files
NSS

# 8. Driver Realtek RTL8192EU (TP-Link TL-WN823N v2/v3) via DKMS
rm -rf /usr/src/rtl8192eu-1.0
git clone https://github.com/clnhub/rtl8192eu-linux.git /usr/src/rtl8192eu-1.0 || git clone https://github.com/Mange/rtl8192eu-linux-driver.git /usr/src/rtl8192eu-1.0 || true
if [ -d "/usr/src/rtl8192eu-1.0" ]; then
    for kver in $(ls /lib/modules); do
        if [ -d "/lib/modules/$kver/build" ]; then
            dkms add -m rtl8192eu -v 1.0 || true
            dkms build -m rtl8192eu -v 1.0 -k "$kver" || true
            dkms install -m rtl8192eu -v 1.0 -k "$kver" || true
        fi
    done
    echo "blacklist rtl8xxxu" > /etc/modprobe.d/blacklist-rtl8xxxu.conf
fi

# 9. SOLUÇÃO DO CONFLITO DE BARRAS (Desativa a barra padrão do Debian/KDE)
rm -rf /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel
mkdir -p /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents
cat > /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js << "LAYOUT"
// Painel padrão do Debian/KDE removido para evitar conflito com a interface Kerigma OS
LAYOUT

cat > /etc/xdg/autostart/plank.desktop << "PLANK_AUTO"
[Desktop Entry]
Type=Application
Name=Kerigma Dock
Exec=plank
Icon=plank
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
PLANK_AUTO

# 10. SOLUÇÃO DOS ÍCONES DUPLICADOS DE INSTALAÇÃO
rm -f /usr/share/applications/install-debian.desktop
rm -f /etc/skel/Desktop/install-debian.desktop

cat > /usr/share/applications/calamares.desktop << "CALAMARES_DESK"
[Desktop Entry]
Type=Application
Version=1.0
Name=Instalar o Kerigma OS
GenericName=Instalador do Sistema
Comment=Instale o Kerigma OS no seu SSD ou HD de forma simples
Exec=sudo -E calamares
Icon=calamares
Terminal=false
StartupNotify=true
Categories=System;
CALAMARES_DESK

cp /usr/share/applications/calamares.desktop /etc/skel/Desktop/instalar-kerigma.desktop
chmod +x /etc/skel/Desktop/instalar-kerigma.desktop

# 11. Criação do Utilizador Live Padrão (kerigma)
if ! id "kerigma" &>/dev/null; then
    useradd -m -s /bin/bash -G sudo,audio,video,plugdev,netdev,bluetooth,lp,cdrom,dip kerigma
    echo "kerigma:kerigma" | chpasswd
    echo "root:kerigma" | chpasswd
    echo "kerigma ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/kerigma-live
fi

mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf << "SDDM"
[Autologin]
User=kerigma
Session=plasma.desktop
SDDM

update-initramfs -u -k all || true

apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EOF

echo "=== [5/8] Injetando Configurações do Calamares e Arquivos Kerigma ==="
if [ -d "$REPO_ROOT/custom-files" ]; then
    cp -r "$REPO_ROOT/custom-files/"* "$CHROOT/" || true
fi
if [ -d "$REPO_ROOT/apps" ]; then
    mkdir -p "$CHROOT/opt/kerigma"
    cp -r "$REPO_ROOT/apps/"* "$CHROOT/opt/kerigma/" || true
fi
if [ -f "$REPO_ROOT/kerigma-welcome.py" ]; then
    cp "$REPO_ROOT/kerigma-welcome.py" "$CHROOT/usr/local/bin/"
    chmod +x "$CHROOT/usr/local/bin/kerigma-welcome.py"
fi
if [ -f "$REPO_ROOT/kerigma-welcome.desktop" ]; then
    cp "$REPO_ROOT/kerigma-welcome.desktop" "$CHROOT/etc/xdg/autostart/"
    cp "$REPO_ROOT/kerigma-welcome.desktop" "$CHROOT/usr/share/applications/"
fi

mkdir -p "$CHROOT/boot/grub" "$CHROOT/boot/efi"

bash "$SCRIPT_DIR/configure-calamares.sh" "$CHROOT"

echo "=== [6/8] Desmontando Sistemas Virtuais com Segurança (LFS Seção 7.13.2) ==="
umount -lf "$CHROOT/dev/shm" 2>/dev/null || true
umount -lf "$CHROOT/dev/pts" 2>/dev/null || true
umount -lf "$CHROOT/sys" 2>/dev/null || true
umount -lf "$CHROOT/proc" 2>/dev/null || true
umount -lf "$CHROOT/run" 2>/dev/null || true
umount -lf "$CHROOT/dev" 2>/dev/null || true

echo "=== [7/8] Gerando SquashFS (COM /boot INCLUSO) e Copiando Kernel/Initrd ==="
mksquashfs "$CHROOT" "$ISODIR/live/filesystem.squashfs" -comp zstd -Xcompression-level 15

KERNEL_VERSION=$(ls "$CHROOT/boot" | grep "vmlinuz-" | sed 's/vmlinuz-//' | sort -V | tail -n 1)
cp "$CHROOT/boot/vmlinuz-$KERNEL_VERSION" "$ISODIR/live/vmlinuz"
cp "$CHROOT/boot/initrd.img-$KERNEL_VERSION" "$ISODIR/live/initrd"

echo "=== [8/8] Criando Menu GRUB Híbrido (BIOS + UEFI) e Compilando ISO ==="
cat << 'GRUBCFG' > "$ISODIR/boot/grub/grub.cfg"
set default="0"
set timeout=5

menuentry "Iniciar Kerigma OS (Live Mode)" {
    linux /live/vmlinuz boot=live components quiet splash locales=pt_BR.UTF-8 keyboard-layouts=br
    initrd /live/initrd
}

menuentry "Iniciar Kerigma OS (Modo Seguro / Compatibilidade)" {
    linux /live/vmlinuz boot=live components nomodeset locales=pt_BR.UTF-8 keyboard-layouts=br
    initrd /live/initrd
}
GRUBCFG

grub-mkrescue -o "$REPO_ROOT/KerigmaOS-Complete-amd64.iso" "$ISODIR"
echo "=== CONCLUÍDO COM SUCESSO: $REPO_ROOT/KerigmaOS-Complete-amd64.iso ==="
