#!/bin/bash
# ==============================================================================
# CONFIGURAÇÃO BLINDADA DO CALAMARES - KERIGMA OS
# Localização: scripts/configure-calamares.sh
# ==============================================================================
set -e

CHROOT_PATH="$1"
if [ -z "$CHROOT_PATH" ]; then
    echo "ERRO: Caminho do CHROOT não informado."
    exit 1
fi

ETC_CAL="$CHROOT_PATH/etc/calamares"
USR_CAL="$CHROOT_PATH/usr/share/calamares"
SBIN_DIR="$CHROOT_PATH/usr/local/sbin"

mkdir -p "$ETC_CAL/modules" "$USR_CAL/modules" "$SBIN_DIR"

# Limpa qualquer resquício de configuração padrão do Debian
rm -f "$ETC_CAL/settings.conf" "$USR_CAL/settings.conf"
rm -f "$ETC_CAL/modules/"*.conf

# ------------------------------------------------------------------------------
# SCRIPTS AUXILIARES (executados pelo Calamares dentro do sistema instalado)
# ------------------------------------------------------------------------------

# Pré-configuração (roda antes do módulo users)
cat > "$SBIN_DIR/kerigma-calamares-pre.sh" << 'EOF'
#!/bin/bash
set -e

mkdir -p /boot/grub /boot/efi

# Remove artefatos exclusivos da sessão Live
rm -f /etc/sudoers.d/kerigma-live
rm -f /etc/sddm.conf.d/autologin.conf
rm -f /etc/skel/Desktop/instalar-kerigma.desktop
rm -f /usr/share/applications/install-debian.desktop

# Remove o usuário Live antes da criação do usuário definitivo
if id "kerigma" >/dev/null 2>&1; then
    userdel -rf kerigma 2>/dev/null || true
fi

exit 0
EOF
chmod +x "$SBIN_DIR/kerigma-calamares-pre.sh"

# Pós-bootloader (garante GRUB funcional em UEFI Acer/genérico e BIOS Legacy)
cat > "$SBIN_DIR/kerigma-calamares-post.sh" << 'EOF'
#!/bin/bash
set -e

# Remove pacotes Live sem jamais abortar a instalação caso algum não exista
DEBIAN_FRONTEND=noninteractive apt-get purge -y live-boot live-boot-initramfs-tools calamares 2>/dev/null || true
DEBIAN_FRONTEND=noninteractive apt-get autoremove -y 2>/dev/null || true
rm -f /home/*/Desktop/instalar-kerigma.desktop

# Garante symlinks do Kernel atualizados
KVER=$(ls /boot 2>/dev/null | grep "^vmlinuz-" | sed 's/^vmlinuz-//' | sort -V | tail -n 1)
if [ -n "$KVER" ]; then
    ln -sf "/boot/vmlinuz-$KVER" /vmlinuz
    ln -sf "/boot/initrd.img-$KVER" /initrd.img
fi

# Gera o menu principal /boot/grub/grub.cfg
/usr/sbin/update-grub || /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg

# Blindagem UEFI: instala entrada padrão + fallback removível e grava stub UUID
if [ -d /sys/firmware/efi ] && mountpoint -q /boot/efi; then
    /usr/sbin/grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=debian --recheck --no-floppy || true
    /usr/sbin/grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable --recheck --no-floppy || true

    ROOT_UUID=$(findmnt -no UUID / || true)
    if [ -n "$ROOT_UUID" ]; then
        mkdir -p /boot/efi/EFI/debian /boot/efi/EFI/BOOT
        cat > /boot/efi/EFI/debian/grub.cfg << STUB
search.fs_uuid $ROOT_UUID root
set prefix=(\$root)'/boot/grub'
configfile \$prefix/grub.cfg
STUB
        cp -f /boot/efi/EFI/debian/grub.cfg /boot/efi/EFI/BOOT/grub.cfg
    fi
fi

exit 0
EOF
chmod +x "$SBIN_DIR/kerigma-calamares-post.sh"

# ------------------------------------------------------------------------------
# MÓDULOS DO CALAMARES
# ------------------------------------------------------------------------------

# 1. UnpackFS: aponta exatamente para a imagem SquashFS do live-boot
cat > "$ETC_CAL/modules/unpackfs.conf" << 'EOF'
unpack:
  - source: "/run/live/medium/live/filesystem.squashfs"
    sourcefs: "squashfs"
    destination: ""
EOF

# 2. Particionamento: Apagar disco (EFI 512M + Swap + Ext4)
cat > "$ETC_CAL/modules/partition.conf" << 'EOF'
efiSystemPartition: "/boot/efi"
efiSystemPartitionSize: 512M
efiSystemPartitionName: EFI
userSwapChoices:
  - none
  - small
  - suspend
  - file
initialPartitioningChoice: erase
initialSwapChoice: small
defaultFileSystemType: "ext4"
availableFileSystemTypes: ["ext4", "btrfs", "xfs"]
enableLuksAutomatedPartitioning: true
EOF

# 3. Usuários: garante grupo sudo e permite senhas simples
cat > "$ETC_CAL/modules/users.conf" << 'EOF'
defaultGroups:
  - sudo
  - audio
  - video
  - plugdev
  - netdev
  - bluetooth
  - lp
  - cdrom
  - dip
autologinGroup: autologin
doAutologin: false
sudoersGroup: sudo
setRootPassword: true
doReusePassword: true
allowWeakPasswords: true
allowWeakPasswordsDefault: true
userShell: /bin/bash
EOF

# 4. Display Manager (SDDM + KDE Plasma)
cat > "$ETC_CAL/modules/displaymanager.conf" << 'EOF'
displaymanagers:
  - sddm
defaultDesktopEnvironment:
  executable: "startplasma-x11"
  desktopFile: "plasma"
basicSetup: false
sysconfigSetup: false
EOF

# 5. Serviços Systemd
cat > "$ETC_CAL/modules/services-systemd.conf" << 'EOF'
units:
  - name: "NetworkManager"
    action: "enable"
    mandatory: false
  - name: "sddm"
    action: "enable"
    mandatory: false
EOF

# 6. GrubCfg (/etc/default/grub)
cat > "$ETC_CAL/modules/grubcfg.conf" << 'EOF'
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

# 7. Bootloader GRUB
cat > "$ETC_CAL/modules/bootloader.conf" << 'EOF'
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

# 8. Shellprocess Pré e Pós
cat > "$ETC_CAL/modules/shellprocess-pre.conf" << 'EOF'
i18n:
  name: "Preparando sistema instalado do Kerigma OS..."
dontChroot: false
timeout: 120
script:
  - "/usr/local/sbin/kerigma-calamares-pre.sh"
EOF

cat > "$ETC_CAL/modules/shellprocess-post.conf" << 'EOF'
i18n:
  name: "Finalizando inicialização UEFI/BIOS do Kerigma OS..."
dontChroot: false
timeout: 180
script:
  - "/usr/local/sbin/kerigma-calamares-post.sh"
EOF

# 9. Settings Principal do Calamares (sem módulo 'packages')
cat > "$ETC_CAL/settings.conf" << 'EOF'
modules-search: [ local, /usr/lib/calamares/modules ]

instances:
  - id: pre
    module: shellprocess
    config: shellprocess-pre.conf
  - id: post
    module: shellprocess
    config: shellprocess-post.conf

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
      - shellprocess@pre
      - users
      - displaymanager
      - networkcfg
      - hwclock
      - services-systemd
      - initramfs
      - grubcfg
      - bootloader
      - shellprocess@post
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

# Espelha para /usr/share/calamares para impedir qualquer fallback
cp -rf "$ETC_CAL/"* "$USR_CAL/"
