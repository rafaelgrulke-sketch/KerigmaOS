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

# 2. Módulo GrubCfg: Garante a criação correta do /etc/default/grub
cat > "$CALAMARES_DIR/modules/grubcfg.conf" << "EOF"
---
overwrite: true
prefer_grub_d: false
keep_distributor: false
defaults:
    GRUB_TIMEOUT: 5
    GRUB_DEFAULT: "0"
    GRUB_HIDDEN_TIMEOUT: 0
    GRUB_TERMINAL: "console"
    GRUB_DISABLE_SUBMENU: "true"
    GRUB_DISABLE_RECOVERY: "false"
    GRUB_CMDLINE_LINUX_DEFAULT: "quiet splash"
    GRUB_DISTRIBUTOR: "KerigmaOS"
EOF

# 3. Módulo de Bootloader: Usa GRUB nativo com fallback EFI habilitado
cat > "$CALAMARES_DIR/modules/bootloader.conf" << "EOF"
---
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

# 4. Script Pré-Bootloader: Prepara diretórios e limpa arquivos da sessão Live
cat > "$CALAMARES_DIR/modules/shellprocess-grubfix.conf" << "EOF"
---
i18n:
    name: "Preparando diretórios de inicialização do Kerigma OS..."
dontChroot: false
timeout: 60
script:
- "mkdir -p /boot/grub"
- "mkdir -p /boot/efi"
- "rm -f /etc/sudoers.d/kerigma-live"
- "rm -f /etc/sddm.conf.d/autologin.conf"
EOF

# 5. Script Pós-Bootloader: Blindagem do GRUB para UEFI (Acer/Debian) e Legacy
cat > "$CALAMARES_DIR/modules/shellprocess-grubpost.conf" << "EOF"
---
i18n:
    name: "Finalizando e blindando o gerenciador de boot GRUB..."
dontChroot: false
timeout: 120
script:
- "-/usr/sbin/update-grub"
- "-/usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg"
- "if [ -d /sys/firmware/efi ]; then /usr/sbin/grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian --recheck --no-floppy || true; fi"
- "if [ -d /sys/firmware/efi ]; then /usr/sbin/grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --recheck --no-floppy || true; fi"
- "if [ -d /boot/efi/EFI ]; then mkdir -p /boot/efi/EFI/debian /boot/efi/EFI/BOOT /boot/efi/EFI/kerigmaos && cp -f /boot/grub/grub.cfg /boot/efi/EFI/debian/grub.cfg && cp -f /boot/grub/grub.cfg /boot/efi/EFI/BOOT/grub.cfg && cp -f /boot/grub/grub.cfg /boot/efi/EFI/kerigmaos/grub.cfg || true; fi"
EOF

# 6. Settings Principal do Calama
