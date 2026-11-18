#!/bin/bash
# ==============================================================================
# CONFIGURAÇÃO AUTOMÁTICA DO CALAMARES PARA KERIGMA OS
# Localização: scripts/configure-calamares.sh
# ==============================================================================
set -e

CHROOT_PATH="$1"
CALAMARES_DIR="$CHROOT_PATH/etc/calamares"

mkdir -p "$CALAMARES_DIR/modules"

# 1. Módulo de Particionamento: Habilita "Apagar Disco" com EFI + Swap + Ext4 automático
cat > "$CALAMARES_DIR/modules/partition.conf" << "EOF"
efiSystemPartition:     "/boot/efi"
efiSystemPartitionSize: 512M
efiSystemPartitionName: EFI
userSwapChoices:
    - none
    - small
    - suspend
    - file
initialPartitioningChoice: erase
initialSwapChoice: small
defaultFileSystemType:  "ext4"
availableFileSystemTypes:  ["ext4", "btrfs", "xfs"]
enableLuksAutomatedPartitioning: true
EOF

# 2. Módulo de Bootloader: Usa GRUB nativo offline (Sem erro código 2 do bootloader-config)
cat > "$CALAMARES_DIR/modules/bootloader.conf" << "EOF"
efiBootLoader: "grub"
kernel: "/vmlinuz"
img: "/initrd.img"
fallback: "/initrd.img"
timeout: "5"
kernelLine: ", with Linux"
fallbackKernelLine: ", with Linux (recovery mode)"
grubInstall: "grub-install"
grubMkconfig: "grub-mkconfig"
grubCfg: "/boot/grub/grub.cfg"
grubProbe: "grub-probe"
efiBootMgr: "efibootmgr"
installEFIFallback: true
EOF

# 3. Script de Pré-Bootloader: Garante que /boot/grub exista no SSD antes do grub-mkconfig
cat > "$CALAMARES_DIR/modules/shellprocess-grubfix.conf" << "EOF"
i18n:
    name: "Preparando diretórios de inicialização do Kerigma OS..."
dontChroot: false
timeout: 30
script:
    - "mkdir -p /boot/grub"
    - "mkdir -p /boot/efi"
    - "rm -f /etc/sudoers.d/kerigma-live"
    - "rm -f /etc/sddm.conf.d/autologin.conf"
EOF

# 4. Settings Principal do Calamares (Remove o módulo problemático do Debian e usa o padrão limpo)
cat > "$CALAMARES_DIR/settings.conf" << "EOF"
modules-search: [ local, /usr/lib/calamares/modules ]

instances:
- id: grubfix
  module: shellprocess
  config: shellprocess-grubfix.conf

sequence:
- show:
  - welcome
  - locale
  - keyboard
  - partition
  - users
  - summary
- exec:
  - partition
  - mount
  - unpackfs
  - machineid
  - fstab
  - locale
  - keyboard
  - localecfg
  - luksbootkeyfile
  - users
  - displaymanager
  - networkcfg
  - hwclock
  - services-systemd
  - shellprocess@grubfix
  - initramfs
  - grubcfg
  - bootloader
  - umount
- show:
  - finished

branding: default
prompt-install: true
dont-chroot: false
oem-setup: false
disable-cancel: false
disable-cancel-during-exec: true
hide-back-and-next-during-exec: false
quit-at-end: false
EOF
