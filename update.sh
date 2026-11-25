#!/bin/bash
# ==============================================================================
# KERIGMA OS - ATUALIZADOR ONLINE E TRANSFORMAÇÃO VISUAL (v1.1)
# Localização no GitHub: update.sh
# ==============================================================================
set -euo pipefail

# >>> ALTERE PARA O SEU USUÁRIO/REPOSITÓRIO DO GITHUB <<<
GITHUB_REPO="SEU_USUARIO/SEU_REPOSITORIO"
GITHUB_BRANCH="main"
KERIGMA_VERSION="1.1.0"

echo "============================================================"
echo "   KERIGMA OS - ATUALIZAÇÃO ONLINE v${KERIGMA_VERSION}"
echo "============================================================"

# 1. Garante privilégios de root preservando o usuário real do Desktop
if [ "$(id -u)" -ne 0 ]; then
    echo ">>> Solicitando permissão de administrador (sudo)..."
    exec sudo GITHUB_REPO="$GITHUB_REPO" GITHUB_BRANCH="$GITHUB_BRANCH" bash "$0" "$@"
fi

TARGET_USER="${SUDO_USER:-$(logname 2>/dev/null || ls /home | head -n 1)}"
TARGET_UID="$(id -u "$TARGET_USER")"
TARGET_HOME="$(eval echo "~$TARGET_USER")"

if [ -z "$TARGET_USER" ] || [ ! -d "$TARGET_HOME" ]; then
    echo "ERRO: Não foi possível identificar o usuário da sessão gráfica."
    exit 1
fi

run_as_user() {
    sudo -u "$TARGET_USER" \
        env DISPLAY=":0" \
        XDG_RUNTIME_DIR="/run/user/$TARGET_UID" \
        DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$TARGET_UID/bus" \
        "$@"
}

echo ">>> [1/7] Instalando pacotes visuais e ferramentas de atualização..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq \
    plank \
    papirus-icon-theme \
    fonts-roboto \
    fonts-noto-color-emoji \
    dconf-cli \
    qdbus-qt5 \
    libkf5config-bin \
    kdialog \
    librsvg2-bin \
    curl \
    neofetch

echo ">>> [2/7] Configurando identidade oficial do Kerigma OS..."
cat > /etc/os-release << EOF
PRETTY_NAME="Kerigma OS ${KERIGMA_VERSION}"
NAME="Kerigma OS"
VERSION_ID="${KERIGMA_VERSION}"
VERSION="${KERIGMA_VERSION} (Bookworm)"
VERSION_CODENAME=bookworm
ID=kerigma
ID_LIKE=debian
HOME_URL="https://github.com/${GITHUB_REPO}"
SUPPORT_URL="https://github.com/${GITHUB_REPO}"
BUG_REPORT_URL="https://github.com/${GITHUB_REPO}/issues"
EOF

echo "${KERIGMA_VERSION}" > /etc/kerigma-version
cat > /etc/kerigma-updater.conf << EOF
GITHUB_REPO="${GITHUB_REPO}"
GITHUB_BRANCH="${GITHUB_BRANCH}"
EOF

echo ">>> [3/7] Gerando papel de parede exclusivo Kerigma OS (1920x1080)..."
WALL_DIR="/usr/share/wallpapers/KerigmaOS"
mkdir -p "$WALL_DIR"

cat > "$WALL_DIR/kerigma-wallpaper.svg" << 'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#0b1021"/>
      <stop offset="50%" stop-color="#17153b"/>
      <stop offset="100%" stop-color="#090d16"/>
    </linearGradient>
    <radialGradient id="glow1" cx="25%" cy="30%" r="50%">
      <stop offset="0%" stop-color="#ff2e93" stop-opacity="0.45"/>
      <stop offset="100%" stop-color="#ff2e93" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="glow2" cx="78%" cy="68%" r="48%">
      <stop offset="0%" stop-color="#00d2ff" stop-opacity="0.40"/>
      <stop offset="100%" stop-color="#00d2ff" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="wave" x1="0%" y1="0%" x2="100%" y2="0%">
      <stop offset="0%" stop-color="#ff2e93" stop-opacity="0.35"/>
      <stop offset="50%" stop-color="#7c3aed" stop-opacity="0.45"/>
      <stop offset="100%" stop-color="#00d2ff" stop-opacity="0.35"/>
    </linearGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#bg)"/>
  <rect width="1920" height="1080" fill="url(#glow1)"/>
  <rect width="1920" height="1080" fill="url(#glow2)"/>
  <path d="M0,760 C420,620 760,920 1220,700 C1540,545 1740,640 1920,580 L1920,1080 L0,1080 Z" fill="url(#wave)"/>
  <path d="M0,860 C520,730 980,980 1440,810 C1680,720 1820,760 1920,720 L1920,1080 L0,1080 Z" fill="#090d16" fill-opacity="0.55"/>
  <circle cx="960" cy="490" r="110" fill="none" stroke="#ffffff" stroke-opacity="0.14" stroke-width="2"/>
  <circle cx="960" cy="490" r="78" fill="none" stroke="#ff2e93" stroke-opacity="0.35" stroke-width="2"/>
  <text x="960" y="512" text-anchor="middle" fill="#ffffff" fill-opacity="0.90" font-family="Roboto, sans-serif" font-size="64" font-weight="300" letter-spacing="14">KERIGMA OS</text>
  <text x="960" y="555" text-anchor="middle" fill="#cbd5e1" fill-opacity="0.55" font-family="Roboto, sans-serif" font-size="18" letter-spacing="8">DEBIAN EDITION</text>
</svg>
EOF

rsvg-convert -w 1920 -h 1080 "$WALL_DIR/kerigma-wallpaper.svg" -o "$WALL_DIR/kerigma-wallpaper.png"
chmod 644 "$WALL_DIR/kerigma-wallpaper.png" "$WALL_DIR/kerigma-wallpaper.svg"

echo ">>> [4/7] Instalando comando permanente kerigma-update e atalho gráfico..."
cat > /usr/local/bin/kerigma-update << 'EOF'
#!/bin/bash
set -e

if [ -f /etc/kerigma-updater.conf ]; then
    source /etc/kerigma-updater.conf
fi

if [ -z "${GITHUB_REPO:-}" ] || [ "$GITHUB_REPO" = "SEU_USUARIO/SEU_REPOSITORIO" ]; then
    echo "ERRO: Configure GITHUB_REPO em /etc/kerigma-updater.conf"
    exit 1
fi

URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH:-main}/update.sh"
TMP_SCRIPT="/tmp/kerigma-online-update.sh"

echo ">>> Baixando atualização de: $URL"
curl -fsSL "$URL" -o "$TMP_SCRIPT"
bash -n "$TMP_SCRIPT"
chmod +x "$TMP_SCRIPT"
exec bash "$TMP_SCRIPT"
EOF
chmod +x /usr/local/bin/kerigma-update

cat > /usr/share/applications/kerigma-updater.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Atualizar Kerigma OS
Comment=Baixa e aplica a atualização mais recente do Kerigma OS online
Exec=konsole -e bash -c "kerigma-update; echo ''; read -p 'Pressione ENTER para fechar...'"
Icon=system-software-update
Terminal=false
Categories=System;Settings;
EOF
chmod 644 /usr/share/applications/kerigma-updater.desktop

echo ">>> [5/7] Criando tema KerigmaGlass e configurando o Dock (Plank)..."
PLANK_THEME_DIR="/usr/share/plank/themes/KerigmaGlass"
mkdir -p "$PLANK_THEME_DIR"
cat > "$PLANK_THEME_DIR/dock.theme" << 'EOF'
[PlankTheme]
TopRoundness=14
BottomRoundness=14
LineWidth=1
OuterStrokeColor=255;;255;;255;;45
FillStartColor=18;;20;;34;;210
FillEndColor=18;;20;;34;;210
InnerStrokeColor=255;;255;;255;;25

[PlankDockTheme]
HorizPadding=6
TopPadding=4
BottomPadding=3
ItemPadding=6
IndicatorSize=5
IconShadowSize=2
UrgentBounceHeight=1.5
LaunchBounceHeight=0.6
FadeOpacity=1
ClickTime=300
UrgentBounceTime=600
LaunchBounceTime=600
ActiveTime=300
SlideTime=300
FadeTime=250
HideTime=250
GlowSize=24
GlowTime=10000
GlowPulseTime=2000
GlowMode=1
UrgentHueShift=150
ItemMoveTime=450
CascadeHide=true
BadgeColor=255;;46;;147;;255
EOF

DOCK_DIR="$TARGET_HOME/.config/plank/dock1/launchers"
mkdir -p "$DOCK_DIR"
rm -f "$DOCK_DIR/"*.dockitem

add_dock_item() {
    local desktop_path="$1"
    local item_name="$2"
    if [ -f "$desktop_path" ]; then
        cat > "$DOCK_DIR/${item_name}.dockitem" << EOF
[PlankDockItemPreferences]
Launcher=file://${desktop_path}
EOF
    fi
}

add_dock_item "/usr/share/applications/org.kde.dolphin.desktop" "01-dolphin"
add_dock_item "/usr/share/applications/org.kde.konsole.desktop" "02-konsole"
add_dock_item "/usr/share/applications/org.kde.kate.desktop" "03-kate"
add_dock_item "/usr/share/applications/vlc.desktop" "04-vlc"
add_dock_item "/usr/share/applications/systemsettings.desktop" "05-settings"
add_dock_item "/usr/share/applications/kerigma-updater.desktop" "06-updater"
add_dock_item "/usr/share/applications/kerigma-welcome.desktop" "07-welcome"

chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config/plank"

# Garante autostart do Plank
mkdir -p /etc/xdg/autostart
cat > /etc/xdg/autostart/plank.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Kerigma Dock
Exec=plank
Icon=plank
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF

run_as_user dconf write /net/launchpad/plank/docks/dock1/theme "'KerigmaGlass'" || true
run_as_user dconf write /net/launchpad/plank/docks/dock1/position "'bottom'" || true
run_as_user dconf write /net/launchpad/plank/docks/dock1/icon-size 44 || true
run_as_user dconf write /net/launchpad/plank/docks/dock1/zoom-enabled true || true
run_as_user dconf write /net/launchpad/plank/docks/dock1/zoom-percent 145 || true
run_as_user dconf write /net/launchpad/plank/docks/dock1/hide-mode "'intelligent'" || true
run_as_user dconf write /net/launchpad/plank/docks/dock1/show-dock-item false || true

echo ">>> [6/7] Aplicando tema visual, ícones, fontes e botões estilo macOS no KDE..."
if command -v lookandfeeltool >/dev/null 2>&1; then
    run_as_user lookandfeeltool -a org.kde.breezedark.desktop || true
fi

run_as_user kwriteconfig5 --file kdeglobals --group Icons --key Theme "Papirus-Dark"
run_as_user kwriteconfig5 --file kdeglobals --group General --key font "Roboto,10,-1,5,50,0,0,0,0,0"
run_as_user kwriteconfig5 --file kdeglobals --group General --key menuFont "Roboto,10,-1,5,50,0,0,0,0,0"
run_as_user kwriteconfig5 --file kdeglobals --group WM --key activeFont "Roboto,10,-1,5,75,0,0,0,0,0"

# Botões das janelas à esquerda (Fechar, Minimizar, Maximizar - estilo macOS)
run_as_user kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft "XIA"
run_as_user kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight ""
run_as_user kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key BorderSize "None"
run_as_user kwriteconfig5 --file kwinrc --group Plugins --key blurEnabled true
run_as_user kwriteconfig5 --file kwinrc --group Plugins --key contrastEnabled true

echo ">>> [7/7] Construindo Barra Superior estilo macOS e aplicando Papel de Parede..."
QDBUS_BIN="$(command -v qdbus-qt5 || command -v qdbus || true)"
if [ -n "$QDBUS_BIN" ] && pgrep -u "$TARGET_USER" plasmashell >/dev/null 2>&1; then
    PLASMA_JS='
var allPanels = panels();
for (var i = 0; i < allPanels.length; i++) {
    allPanels[i].remove();
}

var panel = new Panel;
panel.location = "top";
panel.height = 30;
panel.alignment = "center";

var kickoff = panel.addWidget("org.kde.plasma.kickoff");
kickoff.currentConfigGroup = ["General"];
kickoff.writeConfig("icon", "start-here-kde");
kickoff.writeConfig("alphaSort", true);

panel.addWidget("org.kde.plasma.appmenu");
panel.addWidget("org.kde.plasma.panelspacer");

var clock = panel.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("dateFormat", "shortDate");
clock.writeConfig("use24hFormat", 2);

panel.addWidget("org.kde.plasma.panelspacer");
panel.addWidget("org.kde.plasma.systemtray");

var allDesktops = desktops();
for (var j = 0; j < allDesktops.length; j++) {
    var d = allDesktops[j];
    d.wallpaperPlugin = "org.kde.image";
    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    d.writeConfig("Image", "file:///usr/share/wallpapers/KerigmaOS/kerigma-wallpaper.png");
}
'
    run_as_user "$QDBUS_BIN" org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$PLASMA_JS" || true
    run_as_user "$QDBUS_BIN" org.kde.KWin /KWin reconfigure || true
fi

# Reinicia o Plank Dock já com o tema KerigmaGlass
pkill -u "$TARGET_USER" -x plank 2>/dev/null || true
sleep 1
run_as_user nohup plank >/dev/null 2>&1 &

echo "============================================================"
echo "   KERIGMA OS ATUALIZADO COM SUCESSO PARA v${KERIGMA_VERSION}!"
echo "   Da próxima vez, basta abrir o app 'Atualizar Kerigma OS'"
echo "   ou digitar 'kerigma-update' no terminal."
echo "============================================================"
