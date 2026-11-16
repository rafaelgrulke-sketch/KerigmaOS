#!/usr/bin/env bash
set -e

echo "=================================================="
echo "   Iniciando Atualização do KerigmaOS (v1.1)      "
echo "=================================================="

# 1. Instalar suporte ao Menu Global Dinâmico (GTK e Qt/KDE)
sudo chmod 0440 /etc/sudoers.d/kerigma 2>/dev/null || true
sudo apt-get -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false update
sudo apt-get install -y --no-install-recommends \
    appmenu-gtk2-module appmenu-gtk3-module \
    libdbusmenu-glib4 libdbusmenu-gtk3-4 libdbusmenu-qt5-2 \
    python3-pyqt5 libqt5svg5 qdbus-qt5 dconf-cli

# 2. Garantir o Símbolo Oficial do KerigmaOS
sudo mkdir -p /usr/share/pixmaps
cat << 'LOGOSVG' | sudo tee /usr/share/pixmaps/kerigma-logo.svg > /dev/null
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="kg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#007aff"/>
      <stop offset="100%" stop-color="#5856d6"/>
    </linearGradient>
  </defs>
  <rect width="112" height="112" x="8" y="8" rx="28" fill="url(#kg)"/>
  <path d="M42 32 v64 M42 64 L82 32 M56 52 L86 96" stroke="#ffffff" stroke-width="12" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
</svg>
LOGOSVG

# Criar ícone estilo Launchpad para a Dock
cat << 'LAUNCHSVG' | sudo tee /usr/share/pixmaps/kerigma-launchpad.svg > /dev/null
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <defs>
    <linearGradient id="lg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#1e1e2e"/>
      <stop offset="100%" stop-color="#2d2d44"/>
    </linearGradient>
  </defs>
  <rect width="112" height="112" x="8" y="8" rx="26" fill="url(#lg)" stroke="#4a4a6a" stroke-width="3"/>
  <rect x="28" y="28" width="20" height="20" rx="5" fill="#ff3b30"/>
  <rect x="54" y="28" width="20" height="20" rx="5" fill="#4cd964"/>
  <rect x="80" y="28" width="20" height="20" rx="5" fill="#007aff"/>
  <rect x="28" y="54" width="20" height="20" rx="5" fill="#ff9500"/>
  <rect x="54" y="54" width="20" height="20" rx="5" fill="#5856d6"/>
  <rect x="80" y="54" width="20" height="20" rx="5" fill="#5ac8fa"/>
  <rect x="28" y="80" width="20" height="20" rx="5" fill="#ffcc00"/>
  <rect x="54" y="80" width="20" height="20" rx="5" fill="#ff2d55"/>
  <rect x="80" y="80" width="20" height="20" rx="5" fill="#34c759"/>
</svg>
LAUNCHSVG

# 3. Criar o Kerigma Launchpad (Grade de Aplicativos em Tela Cheia estilo macOS)
cat << 'LAUNCHPY' | sudo tee /usr/local/bin/kerigma-launchpad > /dev/null
#!/usr/bin/env python3
import os
import glob
import subprocess
import configparser
from PyQt5.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout, QGridLayout,
    QLineEdit, QToolButton, QScrollArea, QFrame
)
from PyQt5.QtCore import Qt, QSize
from PyQt5.QtGui import QIcon, QFont, QCursor


class KerigmaLaunchpad(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Kerigma Launchpad")
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.Tool)
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.showFullScreen()
        self.apps = self.load_applications()
        self.setup_ui()

    def load_applications(self):
        app_list = []
        seen_names = set()
        desktop_files = glob.glob("/usr/share/applications/*.desktop") + \
                        glob.glob(os.path.expanduser("~/.local/share/applications/*.desktop"))

        for filepath in sorted(desktop_files):
            cp = configparser.ConfigParser(interpolation=None)
            try:
                cp.read(filepath, encoding="utf-8")
                if "Desktop Entry" not in cp:
                    continue
                entry = cp["Desktop Entry"]
                if entry.get("NoDisplay", "false").lower() == "true":
                    continue
                if entry.get("Type", "") != "Application":
                    continue

                name = entry.get("Name[pt_BR]", entry.get("Name[pt]", entry.get("Name", "")))
                exec_cmd = entry.get("Exec", "")
                icon_name = entry.get("Icon", "application-x-executable")

                if not name or not exec_cmd or name in seen_names:
                    continue
                seen_names.add(name)

                # Limpar parâmetros %U, %F do comando Exec
                clean_exec = " ".join([p for p in exec_cmd.split() if not p.startswith("%")])
                app_list.append((name, clean_exec, icon_name))
            except Exception:
                continue

        return sorted(app_list, key=lambda x: x[0].lower())

    def setup_ui(self):
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)

        bg_frame = QFrame(self)
        bg_frame.setStyleSheet("""
            QFrame {
                background-color: rgba(16, 16, 28, 232);
            }
            QLineEdit {
                background-color: rgba(255, 255, 255, 28);
                border: 1px solid rgba(255, 255, 255, 45);
                border-radius: 10px;
                padding: 8px 16px;
                color: #ffffff;
                font-size: 14px;
            }
            QToolButton {
                background-color: transparent;
                color: #f2f2f7;
                border: none;
                border-radius: 14px;
                padding: 12px;
                font-size: 12px;
            }
            QToolButton:hover {
                background-color: rgba(255, 255, 255, 25);
            }
            QScrollArea {
                background: transparent;
                border: none;
            }
        """)

        frame_layout = QVBoxLayout(bg_frame)
        frame_layout.setContentsMargins(80, 45, 80, 60)
        frame_layout.setSpacing(30)

        # Barra de Busca Centralizada igual ao macOS Launchpad
        search_row = QHBoxLayout()
        search_row.addStretch()
        self.search_input = QLineEdit()
        self.search_input.setPlaceholderText("🔍  Buscar aplicativos...")
        self.search_input.setFixedWidth(320)
        self.search_input.setAlignment(Qt.AlignCenter)
        self.search_input.textChanged.connect(self. populate_grid)
        search_row.addWidget(self.search_input)
        search_row.addStretch()
        frame_layout.addLayout(search_row)

        # Grade de Aplicativos
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.viewport().setStyleSheet("background: transparent;")

        self.grid_container = QWidget()
        self.grid_container.setStyleSheet("background: transparent;")
        self.grid_layout = QGridLayout(self.grid_container)
        self.grid_layout.setSpacing(28)
        self.grid_layout.setAlignment(Qt.AlignTop | Qt.AlignHCenter)

        self.scroll.setWidget(self.grid_container)
        frame_layout.addWidget(self.scroll)
        main_layout.addWidget(bg_frame)

        self.populate_grid("")
        self.search_input.setFocus()

    def get_icon(self, icon_name):
        if os.path.isfile(icon_name):
            return QIcon(icon_name)
        icon = QIcon.fromTheme(icon_name)
        if icon.isNull():
            icon = QIcon.fromTheme("application-x-executable")
        return icon

    def populate_grid(self, filter_text):
        while self.grid_layout.count():
            item = self.grid_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        cols = 7
        row, col = 0, 0
        query = filter_text.strip().lower()

        for name, cmd, icon_name in self.apps:
            if query and query not in name.lower():
                continue

            btn = QToolButton()
            btn.setText(name[:18] + ("..." if len(name) > 18 else ""))
            btn.setToolTip(name)
            btn.setIcon(self.get_icon(icon_name))
            btn.setIconSize(QSize(64, 64))
            btn.setToolButtonStyle(Qt.ToolButtonTextUnderIcon)
            btn.setFixedSize(125, 115)
            btn.setCursor(QCursor(Qt.PointingHandCursor))
            btn.setFont(QFont("Noto Sans", 10))
            btn.clicked.connect(lambda checked, c=cmd: self.launch_app(c))

            self.grid_layout.addWidget(btn, row, col)
            col += 1
            if col >= cols:
                col = 0
                row += 1

    def launch_app(self, cmd):
        subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.close()

    def keyPressEvent(self, event):
        if event.key() == Qt.Key_Escape:
            self.close()

    def mousePressEvent(self, event):
        self.close()


if __name__ == "__main__":
    app = QApplication([])
    lp = KerigmaLaunchpad()
    lp.show()
    app.exec_()
LAUNCHPY
sudo chmod +x /usr/local/bin/kerigma-launchpad

cat << 'LAUNCHDESK' | sudo tee /usr/share/applications/kerigma-launchpad.desktop > /dev/null
[Desktop Entry]
Type=Application
Name=Aplicativos (Launchpad)
Comment=Grade de todos os aplicativos instalados no KerigmaOS
Exec=/usr/local/bin/kerigma-launchpad
Icon=/usr/share/pixmaps/kerigma-launchpad.svg
Terminal=false
Categories=System;Utility;
LAUNCHDESK

# 4. Criar Widget Nativo da Barra Superior que mostra o nome do App Ativo (Estilo macOS Finder)
PLASMOID_DIR="/usr/share/plasma/plasmoids/org.kerigma.windowtitle"
sudo mkdir -p "$PLASMOID_DIR/contents/ui"

cat << 'METAEOF' | sudo tee "$PLASMOID_DIR/metadata.desktop" > /dev/null
[Desktop Entry]
Name=Kerigma Active App Title
Comment=Exibe o nome do aplicativo ativo na barra superior estilo macOS
Type=Service
X-KDE-ServiceTypes=Plasma/Applet
X-Plasma-API=declarativeappletscript
X-Plasma-MainScript=ui/main.qml
X-KDE-PluginInfo-Name=org.kerigma.windowtitle
X-KDE-PluginInfo-Version=1.0
METAEOF

cat << 'QMLEOF' | sudo tee "$PLASMOID_DIR/contents/ui/main.qml" > /dev/null
import QtQuick 2.0
import QtQuick.Layouts 1.1
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.components 2.0 as PlasmaComponents
import org.kde.taskmanager 0.1 as TaskManager

Item {
    id: root
    Layout.preferredWidth: titleLabel.implicitWidth + 18
    Layout.minimumWidth: titleLabel.implicitWidth + 18
    Layout.fillHeight: true
    Plasmoid.preferredRepresentation: Plasmoid.fullRepresentation

    TaskManager.ActivityInfo { id: activityInfo }
    TaskManager.VirtualDesktopInfo { id: virtualDesktopInfo }

    TaskManager.TasksModel {
        id: tasksModel
        sortMode: TaskManager.TasksModel.SortVirtualDesktop
        groupMode: TaskManager.TasksModel.GroupDisabled
        activity: activityInfo.currentActivity
        virtualDesktop: virtualDesktopInfo.currentDesktop
        filterByActivity: true
        filterByVirtualDesktop: true
    }

    function activeAppTitle() {
        for (var i = 0; i < tasksModel.count; i++) {
            var idx = tasksModel.index(i, 0);
            if (tasksModel.data(idx, TaskManager.AbstractTasksModel.IsActive)) {
                var app = tasksModel.data(idx, TaskManager.AbstractTasksModel.AppName);
                if (app && app.length > 0) return app;
            }
        }
        return "Finder";
    }

    PlasmaComponents.Label {
        id: titleLabel
        anchors.centerIn: parent
        text: activeAppTitle()
        font.bold: true
        font.pixelSize: 13
    }

    Connections {
        target: tasksModel
        function onActiveTaskChanged() { titleLabel.text = activeAppTitle(); }
        function onDataChanged() { titleLabel.text = activeAppTitle(); }
        function onCountChanged() { titleLabel.text = activeAppTitle(); }
    }
}
QMLEOF

# 5. Criar o comando de Atualização Contínua (kerigma-update) para futuras atualizações sem formatar
cat << 'UPDATESCRIPT' | sudo tee /usr/local/bin/kerigma-update > /dev/null
#!/usr/bin/env bash
echo "Buscando atualizações oficiais no repositório do KerigmaOS..."
curl -fsSL https://raw.githubusercontent.com/rafaelgrulke-sketch/KerigmaOS/main/update.sh | sudo bash
UPDATESCRIPT
sudo chmod +x /usr/local/bin/kerigma-update

cat << 'UPDATEDESK' | sudo tee /usr/share/applications/kerigma-update.desktop > /dev/null
[Desktop Entry]
Type=Application
Name=Atualizar KerigmaOS
Comment=Baixar última atualização do sistema direto do GitHub sem formatar
Exec=konsole -e /usr/local/bin/kerigma-update
Icon=/usr/share/pixmaps/kerigma-logo.svg
Terminal=false
Categories=System;
UPDATEDESK

# 6. Aplicar Barra Superior estilo macOS + Menu Global + Launchpad na Dock para o usuário atual e /etc/skel
TARGET_USER="${SUDO_USER:-kerigma}"
USER_HOME=$(eval echo "~$TARGET_USER")

sudo rm -f /etc/xdg/autostart/calamares-desktop-icon.desktop
rm -f "$USER_HOME/Desktop/install-debian.desktop" "$USER_HOME/Área de Trabalho/install-debian.desktop" 2>/dev/null || true

# Configurar GTK para exportar Arquivo, Editar, Visualizar para a barra superior
cat << 'GTKENV' | sudo tee /etc/profile.d/kerigma-appmenu.sh > /dev/null
export GTK_MODULES="appmenu-gtk-module"
export UBUNTU_MENUPROXY=1
GTKENV

sudo -u "$TARGET_USER" mkdir -p "$USER_HOME/.config/gtk-3.0" "$USER_HOME/.config/plank/dock1/launchers"
cat << 'GTKINI' | sudo -u "$TARGET_USER" tee "$USER_HOME/.config/gtk-3.0/settings.ini" > /dev/null
[Settings]
gtk-application-prefer-dark-theme=1
gtk-shell-shows-app-menu=1
gtk-shell-shows-menubar=1
GTKINI

# Fixar o Launchpad como primeiro ícone da Dock inferior (Plank)
cat << 'LPDOCK' | sudo -u "$TARGET_USER" tee "$USER_HOME/.config/plank/dock1/launchers/kerigma-launchpad.dockitem" > /dev/null
[PlankDockItemPreferences]
Launcher=file:///usr/share/applications/kerigma-launchpad.desktop
LPDOCK

# Script que transforma o painel do KDE na Barra Superior do macOS com Menu Dinâmico
cat << 'APPLYBAR' | sudo tee /usr/local/bin/kerigma-apply-topbar > /dev/null
#!/usr/bin/env bash
kwriteconfig5 --file kded5rc --group Module-appmenu --key autoload true
kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft "XIA"
kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight ""
qdbus-qt5 org.kde.kded5 /kded org.kde.kded5.loadModule appmenu 2>/dev/null || true
qdbus-qt5 org.kde.KWin /KWin reconfigure 2>/dev/null || true

JS_SCRIPT='
var allPanels = panels();
for (var i = 0; i < allPanels.length; i++) {
    allPanels[i].remove();
}
var topBar = new Panel("org.kde.panel");
topBar.location = "top";
topBar.height = 28;

var logoMenu = topBar.addWidget("org.kde.plasma.kickoff");
logoMenu.currentConfigGroup = ["General"];
logoMenu.writeConfig("icon", "/usr/share/pixmaps/kerigma-logo.svg");

topBar.addWidget("org.kerigma.windowtitle");
topBar.addWidget("org.kde.plasma.appmenu");
topBar.addWidget("org.kde.plasma.panelspacer");
topBar.addWidget("org.kde.plasma.systemtray");

var clock = topBar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
'
qdbus-qt5 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$JS_SCRIPT" 2>/dev/null || true

dconf write /net/launchpad/plank/docks/dock1/zoom-enabled true 2>/dev/null || true
dconf write /net/launchpad/plank/docks/dock1/icon-size 48 2>/dev/null || true
dconf write /net/launchpad/plank/docks/dock1/dock-items "['kerigma-launchpad.dockitem', 'kerigma-settings.dockitem', 'org.kde.dolphin.dockitem', 'org.kde.discover.dockitem', 'org.kde.konsole.dockitem', 'codium.dockitem', 'firefox-esr.dockitem', 'kerigma-installer.dockitem']" 2>/dev/null || true
pkill plank 2>/dev/null || true
nohup plank >/dev/null 2>&1 &
APPLYBAR
sudo chmod +x /usr/local/bin/kerigma-apply-topbar

# Executar a transformação visual imediatamente na sessão ativa
sudo -u "$TARGET_USER" DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$TARGET_USER")/bus" /usr/local/bin/kerigma-apply-topbar || true

echo "=================================================="
echo " Atualização concluída! Barra macOS e Launchpad   "
echo " ativados com sucesso no seu KerigmaOS!           "
echo "=================================================="
