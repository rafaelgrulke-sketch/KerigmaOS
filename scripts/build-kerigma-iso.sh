#!/bin/bash
# ==============================================================================
# KERIGMA OS - BUILD SCRIPT DEFINITIVO COM AUTO-TESTE COMPLETO
# Localização: scripts/build-kerigma-iso.sh
# ==============================================================================
set -e

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

cleanup_mounts() {
    umount -lf "$CHROOT/dev/shm" 2>/dev/null || true
    umount -lf "$CHROOT/dev/pts" 2>/dev/null || true
    umount -lf "$CHROOT/sys" 2>/dev/null || true
    umount -lf "$CHROOT/proc" 2>/dev/null || true
    umount -lf "$CHROOT/run" 2>/dev/null || true
    umount -lf "$CHROOT/dev" 2>/dev/null || true
}
trap cleanup_mounts EXIT

echo "=== [1/9] Limpando ambiente anterior e preparando diretórios ==="
rm -rf "$WORKDIR"
mkdir -p "$CHROOT" "$ISODIR/live" "$ISODIR/boot/grub" "$ISODIR/EFI/boot"

echo "=== [2/9] Executando Debootstrap (Debian Bookworm Minimal) ==="
debootstrap --arch=amd64 --variant=minbase bookworm "$CHROOT" http://deb.debian.org/debian/

echo "=== [3/9] Montando Sistemas de Arquivos Virtuais do Kernel ==="
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

echo "=== [4/9] Configurando o Sistema Base dentro do Chroot ==="
cat << 'EOF' | chroot "$CHROOT" /usr/bin/env -i HOME=/root TERM="$TERM" DEBIAN_FRONTEND=noninteractive PATH=/usr/bin:/usr/sbin:/bin:/sbin /bin/bash
set -e

mkdir -pv /boot /boot/grub /boot/efi /home /mnt /opt /srv
mkdir -pv /etc/opt /etc/sysconfig /etc/calamares/modules /etc/skel/Desktop /etc/xdg/autostart
mkdir -pv /lib/firmware /var/lib/hwclock
install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp

ln -sfv /proc/self/mounts /etc/mtab

cat > /etc/apt/sources.list << "SOURCES"
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
SOURCES

apt-get update

# Kernel, Headers, Live Boot e Firmwares
apt-get install -y \
    linux-image-amd64 linux-headers-amd64 live-boot systemd-sysv initramfs-tools \
    firmware-linux firmware-linux-free firmware-linux-nonfree \
    firmware-misc-nonfree firmware-realtek firmware-atheros \
    firmware-iwlwifi firmware-brcm80211 firmware-amd-graphics \
    intel-microcode amd64-microcode dkms build-essential bc kmod cpio libssl-dev git curl wget

# Utilitários, Teclado, GRUB Completo (UEFI + BIOS) e Calamares (SEM calamares-settings-debian)
apt-get install -y \
    locales tzdata console-setup keyboard-configuration sudo bash-completion \
    rsync parted gparted dosfstools mtools e2fsprogs btrfs-progs xfsprogs ntfs-3g \
    squashfs-tools xorriso isolinux syslinux-common syslinux-efi \
    grub-common grub2-common grub-pc-bin grub-efi-amd64 grub-efi-amd64-bin grub-efi-amd64-signed shim-signed efibootmgr os-prober \
    calamares

# Garante remoção do pacote problemático caso tenha entrado como recomendação
apt-get purge -y calamares-settings-debian 2>/dev/null || true

# KDE Plasma + Estilo macOS + Rede + Áudio + Apps + Python YAML
apt-get install -y \
    plasma-desktop plasma-nm plasma-pa bluedevil powerdevil sddm \
    kde-config-gtk-style breeze-gtk-theme plank \
    konsole dolphin ark kde-spectacle gwenview okular kate vlc \
    network-manager bluez pipewire pipewire-audio pipewire-pulse wireplumber \
    cups system-config-printer ufw \
    python3 python3-pip python3-pyqt5 python3-requests python3-yaml kiwix-tools

# Locales e Fuso Horário
echo "pt_BR.UTF-8 UTF-8" > /etc/locale.gen
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
update-locale LANG=pt_BR.UTF-8 LC_ALL=pt_BR.UTF-8
ln -sfv /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

# Rede
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

# Driver Realtek RTL8192EU (TP-Link TL-WN823N) via DKMS com fallback limpo para rtl8xxxu
rm -rf /usr/src/rtl8192eu-1.0
if git clone --depth 1 https://github.com/Mange/rtl8192eu-linux-driver.git /usr/src/rtl8192eu-1.0; then
    KVER=$(ls /lib/modules | sort -V | tail -n 1)
    if [ -d "/lib/modules/$KVER/build" ]; then
        if dkms add -m rtl8192eu -v 1.0 && dkms build -m rtl8192eu -v 1.0 -k "$KVER" && dkms install -m rtl8192eu -v 1.0 -k "$KVER"; then
            echo "blacklist rtl8xxxu" > /etc/modprobe.d/blacklist-rtl8xxxu.conf
        else
            echo "Aviso: DKMS rtl8192eu incompatível com $KVER; mantendo driver nativo rtl8xxxu do kernel."
            dkms remove -m rtl8192eu -v 1.0 --all 2>/dev/null || true
            rm -rf /usr/src/rtl8192eu-1.0
        fi
    fi
fi

# Remove barra padrão duplicada do Debian/KDE e ativa o Dock Plank
rm -rf /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel
mkdir -p /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents
cat > /usr/share/plasma/layout-templates/org.kde.plasma.desktop.defaultPanel/contents/layout.js << "LAYOUT"
// Painel padrão removido para manter apenas a barra e o Dock do Kerigma OS
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

# Ícone único de instalação no Desktop
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

# Usuário Live padrão
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

# Atualiza initramfs e garante symlinks /vmlinuz e /initrd.img na raiz
update-initramfs -u -k all
KVER=$(ls /boot | grep "^vmlinuz-" | sed 's/^vmlinuz-//' | sort -V | tail -n 1)
ln -sf "/boot/vmlinuz-$KVER" /vmlinuz
ln -sf "/boot/initrd.img-$KVER" /initrd.img

apt-get clean
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
EOF

echo "=== [5/9] Injetando Configurações do Calamares e Arquivos Kerigma ==="
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

echo "=== [6/9] Executando Auto-Teste Rigoroso de Integridade ==="
chroot "$CHROOT" bash -n /usr/local/sbin/kerigma-calamares-pre.sh
chroot "$CHROOT" bash -n /usr/local/sbin/kerigma-calamares-post.sh

chroot "$CHROOT" python3 - << 'PYTEST'
import yaml, glob, os

# 1. Valida sintaxe YAML de todos os arquivos do Calamares e do branding
conf_files = (
    glob.glob("/etc/calamares/modules/*.conf")
    + ["/etc/calamares/settings.conf", "/etc/calamares/branding/kerigma/branding.desc"]
)
for path in conf_files:
    assert os.path.exists(path), f"Arquivo obrigatório ausente: {path}"
    with open(path, "r") as f:
        data = yaml.safe_load(f)
    assert isinstance(data, dict) and len(data) > 0, f"YAML inválido ou vazio: {path}"

# 2. Valida sequência do settings.conf e existência de cada módulo (multiarch Debian + padrão)
mod_roots = [
    "/usr/lib/x86_64-linux-gnu/calamares/modules",
    "/usr/lib/calamares/modules",
]
with open("/etc/calamares/settings.conf") as f:
    s = yaml.safe_load(f)

exec_steps = []
for block in s["sequence"]:
    for phase in ("show", "exec"):
        if phase in block:
            for item in block[phase]:
                mod_name = item.split("@")[0]
                found = any(os.path.isdir(os.path.join(root, mod_name)) for root in mod_roots)
                assert found, f"Módulo do Calamares ausente em {mod_roots}: {mod_name}"
            if phase == "exec":
                exec_steps = block[phase]

assert "packages" not in exec_steps, "ERRO: módulo packages não pode estar ativo!"
assert "mount" in exec_steps and "unpackfs" in exec_steps and "grubcfg" in exec_steps and "bootloader" in exec_steps
assert exec_steps.index("shellprocess@pre") < exec_steps.index("users"), "shellprocess@pre deve rodar antes de users!"
assert exec_steps.index("bootloader") < exec_steps.index("shellprocess@post"), "shellprocess@post deve rodar após bootloader!"

# 3. Garante arquivos críticos de módulos, Kernel, Initrd e binários do GRUB
required_paths = [
    "/etc/calamares/modules/mount.conf",
    "/etc/calamares/modules/unpackfs.conf",
    "/etc/calamares/modules/fstab.conf",
    "/etc/calamares/modules/partition.conf",
    "/etc/calamares/modules/grubcfg.conf",
    "/etc/calamares/modules/bootloader.conf",
    "/vmlinuz",
    "/initrd.img",
    "/usr/sbin/grub-install",
    "/usr/sbin/grub-mkconfig",
    "/usr/sbin/update-grub",
    "/usr/bin/calamares",
    "/usr/bin/unsquashfs",
    "/usr/bin/rsync",
    "/usr/local/sbin/kerigma-calamares-pre.sh",
    "/usr/local/sbin/kerigma-calamares-post.sh",
]
for p in required_paths:
    assert os.path.exists(p), f"Recurso obrigatório ausente: {p}"

print("AUTO-TESTE RIGOROSO APROVADO COM 100% DE SUCESSO!")
PYTEST

echo "=== [7/9] Desmontando Sistemas Virtuais com Segurança ==="
cleanup_mounts
trap - EXIT

echo "=== [8/9] Gerando SquashFS (COM /boot INCLUSO) e Copiando Kernel/Initrd ==="
mksquashfs "$CHROOT" "$ISODIR/live/filesystem.squashfs" -comp zstd -Xcompression-level 15

KERNEL_VERSION=$(ls "$CHROOT/boot" | grep "^vmlinuz-" | sed 's/^vmlinuz-//' | sort -V | tail -n 1)
cp "$CHROOT/boot/vmlinuz-$KERNEL_VERSION" "$ISODIR/live/vmlinuz"
cp "$CHROOT/boot/initrd.img-$KERNEL_VERSION" "$ISODIR/live/initrd"

echo "=== [9/9] Criando Menu GRUB Híbrido (BIOS + UEFI) e Compilando ISO ==="
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
test -s "$REPO_ROOT/KerigmaOS-Complete-amd64.iso"
ls -lh "$REPO_ROOT/KerigmaOS-Complete-amd64.iso"
echo "=== CONCLUÍDO COM SUCESSO: $REPO_ROOT/KerigmaOS-Complete-amd64.iso ==="
