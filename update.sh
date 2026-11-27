#!/bin/bash
# ==============================================================================
# KERIGMA OS - ATUALIZADOR ONLINE v1.2.0
# Dock macOS + Brave + Spotify + Kerigma IA (Ollama/Gemma) + Wikipédia (Kiwix)
# Localização no GitHub: update.sh
# ==============================================================================
set -euo pipefail

GITHUB_REPO="rafaelgrulke-sketch/KerigmaOS"
GITHUB_BRANCH="main"
KERIGMA_VERSION="1.2.0"

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

export DEBIAN_FRONTEND=noninteractive

echo ">>> [1/9] Instalando dependências base, temas e Wikipédia (Kiwix)..."
apt-get update -qq
apt-get install -y -qq \
    ca-certificates \
    curl \
    gnupg \
    plank \
    papirus-icon-theme \
    fonts-roboto \
    fonts-noto-color-emoji \
    dconf-cli \
    qdbus-qt5 \
    libkf5config-bin \
    kdialog \
    librsvg2-bin \
    kiwix-tools \
    neofetch

apt-get install -y -qq kiwix 2>/dev/null || true

echo ">>> [2/9] Instalando Brave Browser..."
if ! command -v brave-browser >/dev/null 2>&1; then
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        > /etc/apt/sources.list.d/brave-browser-release.list
    apt-get update -qq
    apt-get install -y -qq brave-browser || true
fi

echo ">>> [3/9] Instalando Spotify..."
if ! command -v spotify >/dev/null 2>&1; then
    SPOTIFY_OK=0
    if curl -fsSL https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg \
        | gpg --dearmor --yes -o /usr/share/keyrings/spotify.gpg 2>/dev/null; then
        echo "deb [signed-by=/usr/share/keyrings/spotify.gpg] http://repository.spotify.com stable non-free" \
            > /etc/apt/sources.list.d/spotify.list
        if apt-get update -qq && apt-get install -y -qq spotify-client; then
            SPOTIFY_OK=1
        fi
    fi

    if [ "$SPOTIFY_OK" -eq 0 ]; then
        echo ">>> Usando fallback Flatpak para o Spotify..."
        apt-get install -y -qq flatpak || true
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || true
        flatpak install -y --noninteractive flathub com.spotify.Client || true
    fi
fi

echo ">>> [4/9] Instalando Kerigma IA (Ollama + Launcher Gemma Local)..."
if ! command -v ollama >/dev/null 2>&1; then
    curl -fsSL https://ollama.com/install.sh | sh || true
fi
systemctl enable --now ollama 2>/dev/null || true

cat > /usr/local/bin/kerigma-ia << 'EOF'
#!/bin/bash
echo "============================================================"
echo "   KERIGMA IA - ASSISTENTE LOCAL OFFLINE (GEMMA)"
echo "============================================================"

if ! command -v ollama >/dev/null 2>&1; then
    echo "Ollama não encontrado. Execute 'kerigma-update' para instalar."
    read -p "Pressione ENTER para sair..."
    exit 1
fi

if ! pgrep -x ollama >/dev/null 2>&1; then
    echo ">>> Iniciando motor de IA local..."
    sudo systemctl start ollama 2>/dev/null || (nohup ollama serve >/dev/null 2>&1 & sleep 2)
fi

MODEL=$(ollama list 2>/dev/null | awk 'NR>1 && $1 ~ /^gemma/ {print $1; exit}')
if [ -z "$MODEL" ]; then
    echo ">>> Primeira execução: baixando modelo leve Gemma para uso offline..."
    if ollama pull gemma3n:e2b; then
        MODEL="gemma3n:e2b"
    elif ollama pull gemma3:4b; then
        MODEL="gemma3:4b"
    else
        ollama pull gemma2:2b
        MODEL="gemma2:2b"
    fi
fi

echo ">>> Modelo ativo: $MODEL (digite /bye para sair)"
echo ""
ollama run "$MODEL"
EOF
chmod +x /usr/local/bin/kerigma-ia

cat > /usr/share/applications/kerigma-ia.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Kerigma IA
Comment=Assistente de Inteligência Artificial local e offline
Exec=konsole -e /usr/local/bin/kerigma-ia
Icon=applications-science
Terminal=false
Categories=Utility;Development;
EOF
chmod 644 /usr/share/applications/kerigma-ia.desktop

echo ">>> [5/9] Configurando Wikipédia Offline (Kiwix)..."
mkdir -p /opt/kerigma/wikipedia "$TARGET_HOME/Wikipedia"
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/Wikipedia"

cat > /usr/local/bin/kerigma-wikipedia << 'EOF'
#!/bin/bash
if command -v kiwix-desktop >/dev/null 2>&1; then
    exec kiwix-desktop
fi

ZIM_FILE=$(find /opt/kerigma/wikipedia "$HOME/Wikipedia" -maxdepth 2 -name "*.zim" 2>/dev/null | head -n 1)
if [ -n "$ZIM_FILE" ]; then
    pkill -x kiwix-serve 2>/dev/null || true
    nohup kiwix-serve --port=8090 "$ZIM_FILE" >/dev/null 2>&1 &
    sleep 1
    xdg-open "http://localhost:8090" >/dev/null 2>&1 &
else
    konsole -e bash -c '
        echo "============================================================"
        echo "   WIKIPÉDIA OFFLINE - KERIGMA OS"
        echo "============================================================"
        echo "Nenhum arquivo .zim encontrado em ~/Wikipedia."
        echo ""
        read -p "Deseja baixar a Wikipédia PT-BR compacta agora? (s/N): " RESP
        if [[ "$RESP" =~ ^[sS]$ ]]; then
            mkdir -p "$HOME/Wikipedia"
            echo ">>> Baixando biblioteca Kiwix..."
            xdg-open "https://library.kiwix.org/#lang=por&q=wikipedia" >/dev/null 2>&1 &
            echo "Salve o arquivo .zim na pasta ~/Wikipedia e abra o app novamente."
        fi
        read -p "Pressione ENTER para fechar..."
    '
fi
EOF
chmod +x /usr/local/bin/kerigma-wikipedia

cat > /usr/share/applications/kerigma-wikipedia.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Wikipédia Offline
Comment=Enciclopédia offline do Kerigma OS via Kiwix
Exec=/usr/local/bin/kerigma-wikipedia
Icon=accessories-dictionary
Terminal=false
Categories=Education;Reference;
EOF
chmod 644 /usr/share/applications/kerigma-wikipedia.desktop

echo ">>> [6/9] Atualizando identidade do sistema e comando kerigma-update..."
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

cat > /usr/local/bin/kerigma-update << 'EOF'
#!/bin/bash
set -e
source /etc/kerigma-updater.conf
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

echo ">>> [7/9] Gerando papel de parede Kerigma OS..."
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

echo ">>> [8/9] Configurando Dock inferior estilo macOS (Plank KerigmaMacOS)..."
PLANK_THEME_DIR="/usr/share/plank/themes/KerigmaMacOS"
mkdir -p "$PLANK_THEME_DIR"
cat > "$PLANK_THEME_DIR/dock.theme" << 'EOF'
[PlankTheme]
TopRoundness=18
BottomRoundness=18
LineWidth=1
OuterStrokeColor=255;;255;;255;;65
FillStartColor=24;;26;;40;;195
FillEndColor=18;;20;;32;;205
InnerStrokeColor=255;;255;;255;;30

[PlankDockTheme]
HorizPadding=10
TopPadding=6
BottomPadding=4
ItemPadding=8
IndicatorSize=4
IconShadowSize=3
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
GlowSize=26
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
add_dock_item "/usr/share/applications/brave-browser.desktop" "02-brave"

if [ -f "/usr/share/applications/spotify.desktop" ]; then
    add_dock_item "/usr/share/applications/spotify.desktop" "03-spotify"
elif [ -f "/var/lib/flatpak/exports/share/applications/com.spotify.Client.desktop" ]; then
    add_dock_item "/var/lib/flatpak/exports/share/applications/com.spotify.Client.desktop" "03-spotify"
fi

add_dock_item "/usr/share/applications/kerigma-ia.desktop" "04-kerigma-ia"
add_dock_item "/usr/share/applications/kerigma-wikipedia.desktop" "05-wikipedia"
add_dock_item "/usr/share/applications/org.kde.konsole.desktop" "06-konsole"
add_dock_item "/usr/share/applications/systemsettings.desktop" "07-settings"
add_dock_item "/usr/share/applications/kerigma-updater.desktop" "08-updater"

chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.config/plank"

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

run_as_user dconf write /net/launchpad/plank/docks/dock1/theme "'KerigmaMacOS'" || true
run_as_user dconf write /net/launchpad/plank/docks/dock1/position "'bottom'" || true
run_as_user dconf write /net/launchpad/plank/docks/dock1/alignment "'center'" || true
run_as_user dconf write /net/launchpad/plank/docks/dock1/icon-size 48 || true
run_as_user dconf write /net/launchpad/plank/docks/dock1/zoom-enabled true || true
run_as_user dconf write /net/launchpad/plank/docks/dock1/zoom-percent 155 || true
run_as_user dconf write /net/launchpad/plank/docks/dock1/hide-mode "'dodge-maximized'" || true
run_as_user dconf write /net/launchpad/plank/docks/dock1/show-dock-item false || true

echo ">>> [9/9] Aplicando Barra Superior macOS, Compositor KWin e iniciando o Dock..."
run_as_user kwriteconfig5 --file kdeglobals --group Icons --key Theme "Papirus-Dark"
run_as_user kwriteconfig5 --file kwinrc --group Compositing --key Enabled true
run_as_user kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft "XIA"
run_as_user kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight ""
run_as_user kwriteconfig5 --file kwinrc --group Plugins --key blurEnabled true
run_as_user kwriteconfig5 --file kwinrc --group Plugins --key contrastEnabled true

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

# Reinicia o Dock de forma desacoplada para não fechar ao final do script
pkill -u "$TARGET_USER" -x plank 2>/dev/null || true
sleep 1
run_as_user setsid -f plank >/dev/null 2>&1

echo "============================================================"
echo "   KERIGMA OS ATUALIZADO PARA v${KERIGMA_VERSION} COM SUCESSO!"
echo "   Apps no Dock: Arquivos, Brave, Spotify, Kerigma IA,"
echo "   Wikipédia Offline, Terminal, Configurações e Atualizador."
echo "============================================================"
