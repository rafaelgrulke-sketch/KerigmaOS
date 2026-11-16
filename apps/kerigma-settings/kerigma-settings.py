#!/usr/bin/env python3
import subprocess
from PyQt5.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QPushButton, QListWidget, QListWidgetItem, QStackedWidget,
    QFrame, QMessageBox
)
from PyQt5.QtGui import QFont, QIcon


class KerigmaSettings(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Ajustes do Sistema — KerigmaOS")
        self.setFixedSize(820, 560)
        self.setWindowIcon(QIcon("/usr/share/pixmaps/kerigma-logo.svg"))
        self.setup_ui()

    def run_cmd(self, cmd):
        subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def setup_ui(self):
        self.setStyleSheet("""
            QWidget {
                background-color: #161622;
                color: #f2f2f7;
                font-family: 'Noto Sans', sans-serif;
            }
            QListWidget#sidebar {
                background-color: #1e1e2e;
                border-right: 1px solid #2e2e42;
                border-radius: 0px;
                padding: 12px 8px;
                font-size: 13px;
                outline: none;
            }
            QListWidget#sidebar::item {
                padding: 10px 14px;
                border-radius: 8px;
                margin-bottom: 4px;
                color: #c8c8d8;
            }
            QListWidget#sidebar::item:selected {
                background-color: #007aff;
                color: #ffffff;
                font-weight: bold;
            }
            QFrame#card {
                background-color: #222234;
                border-radius: 12px;
                border: 1px solid #32324a;
            }
            QPushButton#btn {
                background-color: #2e2e46;
                color: #ffffff;
                border-radius: 8px;
                padding: 10px 16px;
                border: 1px solid #3e3e5a;
                font-weight: bold;
                text-align: left;
            }
            QPushButton#btn:hover {
                background-color: #007aff;
                border-color: #007aff;
            }
            QPushButton#primary {
                background-color: #007aff;
                color: white;
                border-radius: 8px;
                padding: 10px 18px;
                font-weight: bold;
                text-align: left;
            }
            QPushButton#primary:hover {
                background-color: #0062cc;
            }
        """)

        main_layout = QHBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        self.sidebar = QListWidget()
        self.sidebar.setObjectName("sidebar")
        self.sidebar.setFixedWidth(235)

        categories = [
            "🎨  Aparência e Tema",
            "🪟  Janelas e Botões",
            "⚓  Dock e Barra Superior",
            "🤖  IA Gemma & Wikipédia",
            "🛍️  Loja de Apps e Sistema",
            "🖨️  Impressoras, Som e Rede",
            "💻  Sobre o KerigmaOS"
        ]
        for cat in categories:
            self.sidebar.addItem(QListWidgetItem(cat))

        self.stack = QStackedWidget()
        self.stack.addWidget(self.page_appearance())
        self.stack.addWidget(self.page_windows())
        self.stack.addWidget(self.page_dock())
        self.stack.addWidget(self.page_ai())
        self.stack.addWidget(self.page_system_tools())
        self.stack.addWidget(self.page_hardware())
        self.stack.addWidget(self.page_about())

        self.sidebar.currentRowChanged.connect(self.stack.setCurrentIndex)
        self.sidebar.setCurrentRow(0)

        main_layout.addWidget(self.sidebar)
        main_layout.addWidget(self.stack)

    def create_header(self, title_text, subtitle_text):
        box = QVBoxLayout()
        title = QLabel(title_text)
        title.setFont(QFont("Noto Sans", 18, QFont.Bold))
        sub = QLabel(subtitle_text)
        sub.setStyleSheet("color: #9898b0; font-size: 12px;")
        box.addWidget(title)
        box.addWidget(sub)
        return box

    def page_appearance(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(28, 28, 28, 28)
        layout.setSpacing(16)
        layout.addLayout(self.create_header("Aparência", "Personalize o estilo visual inspirado no macOS."))

        card = QFrame()
        card.setObjectName("card")
        c_layout = QVBoxLayout(card)
        c_layout.setSpacing(12)

        btn_dark = QPushButton("🌙  Ativar Modo Escuro (Kerigma Dark — Padrão)")
        btn_dark.setObjectName("primary")
        btn_dark.clicked.connect(lambda: self.apply_theme("BreezeDark"))

        btn_light = QPushButton("☀️  Ativar Modo Claro (Kerigma Light)")
        btn_light.setObjectName("btn")
        btn_light.clicked.connect(lambda: self.apply_theme("BreezeLight"))

        btn_wall = QPushButton("🖼️  Alterar Papel de Parede e Cores de Destaque")
        btn_wall.setObjectName("btn")
        btn_wall.clicked.connect(lambda: self.run_cmd("systemsettings5"))

        c_layout.addWidget(btn_dark)
        c_layout.addWidget(btn_light)
        c_layout.addWidget(btn_wall)

        layout.addWidget(card)
        layout.addStretch()
        return page

    def page_windows(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(28, 28, 28, 28)
        layout.setSpacing(16)
        layout.addLayout(self.create_header("Janelas e Botões", "Posição dos botões Fechar, Minimizar e Maximizar."))

        card = QFrame()
        card.setObjectName("card")
        c_layout = QVBoxLayout(card)
        c_layout.setSpacing(12)

        btn_mac = QPushButton("🔴🟡🟢  Botões na Esquerda — Estilo macOS (Padrão KerigmaOS)")
        btn_mac.setObjectName("primary")
        btn_mac.clicked.connect(lambda: self.set_window_buttons("mac"))

        btn_win = QPushButton("🗕 🗖 ✕  Botões na Direita — Estilo Windows 11")
        btn_win.setObjectName("btn")
        btn_win.clicked.connect(lambda: self.set_window_buttons("win"))

        c_layout.addWidget(btn_mac)
        c_layout.addWidget(btn_win)

        layout.addWidget(card)
        layout.addStretch()
        return page

    def page_dock(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(28, 28, 28, 28)
        layout.setSpacing(16)
        layout.addLayout(self.create_header("Dock e Barra Superior", "Configure a barra inferior centralizada com ampliação."))

        card = QFrame()
        card.setObjectName("card")
        c_layout = QVBoxLayout(card)
        c_layout.setSpacing(12)

        btn_dock_cfg = QPushButton("⚓  Personalizar Dock (Tamanho dos Ícones, Zoom e Ocultação)")
        btn_dock_cfg.setObjectName("primary")
        btn_dock_cfg.clicked.connect(lambda: self.run_cmd("plank --preferences"))

        btn_restart_dock = QPushButton("🔄  Reiniciar Dock Inferior")
        btn_restart_dock.setObjectName("btn")
        btn_restart_dock.clicked.connect(lambda: self.run_cmd("pkill plank; sleep 1; plank &"))

        c_layout.addWidget(btn_dock_cfg)
        c_layout.addWidget(btn_restart_dock)

        layout.addWidget(card)
        layout.addStretch()
        return page

    def page_ai(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(28, 28, 28, 28)
        layout.setSpacing(16)
        layout.addLayout(self.create_header("IA Gemma 3n & Wikipédia", "Módulos locais de Inteligência Artificial e enciclopédia offline."))

        card = QFrame()
        card.setObjectName("card")
        c_layout = QVBoxLayout(card)
        c_layout.setSpacing(12)

        btn_welcome = QPushButton("🚀  Gerenciar / Baixar Modelos Google Gemma (E2B / E4B) e Wikipédia")
        btn_welcome.setObjectName("primary")
        btn_welcome.clicked.connect(lambda: self.run_cmd("/usr/local/bin/kerigma-welcome --modules"))

        btn_wiki = QPushButton("📚  Abrir Wikipédia Offline (Kiwix Local Server)")
        btn_wiki.setObjectName("btn")
        btn_wiki.clicked.connect(lambda: self.run_cmd("/usr/local/bin/kerigma-wiki"))

        c_layout.addWidget(btn_welcome)
        c_layout.addWidget(btn_wiki)

        layout.addWidget(card)
        layout.addStretch()
        return page

    def page_system_tools(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(28, 28, 28, 28)
        layout.setSpacing(16)
        layout.addLayout(self.create_header("Loja de Apps e Utilitários", "Instale programas, monitore recursos e gerencie discos."))

        card = QFrame()
        card.setObjectName("card")
        c_layout = QVBoxLayout(card)
        c_layout.setSpacing(12)

        btn_store = QPushButton("🛍️  Abrir Loja de Aplicativos (Plasma Discover / Flatpak)")
        btn_store.setObjectName("primary")
        btn_store.clicked.connect(lambda: self.run_cmd("plasma-discover"))

        btn_mon = QPushButton("📊  Monitor de Atividade do Sistema (CPU, RAM e Processos)")
        btn_mon.setObjectName("btn")
        btn_mon.clicked.connect(lambda: self.run_cmd("plasma-systemmonitor"))

        btn_disk = QPushButton("💽  Utilitário de Discos e Formatação de Pendrives (Partition Manager)")
        btn_disk.setObjectName("btn")
        btn_disk.clicked.connect(lambda: self.run_cmd("partitionmanager"))

        c_layout.addWidget(btn_store)
        c_layout.addWidget(btn_mon)
        c_layout.addWidget(btn_disk)

        layout.addWidget(card)
        layout.addStretch()
        return page

    def page_hardware(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(28, 28, 28, 28)
        layout.setSpacing(16)
        layout.addLayout(self.create_header("Impressoras, Som e Conectividade", "Controle de periféricos USB, Wi-Fi, Bluetooth e Áudio."))

        card = QFrame()
        card.setObjectName("card")
        c_layout = QVBoxLayout(card)
        c_layout.setSpacing(12)

        btn_print = QPushButton("🖨️  Configurar Impressoras USB e de Rede (CUPS)")
        btn_print.setObjectName("primary")
        btn_print.clicked.connect(lambda: self.run_cmd("system-config-printer"))

        btn_audio = QPushButton("🔊  Mixer Avançado de Áudio e Microfone (PulseAudio / PipeWire)")
        btn_audio.setObjectName("btn")
        btn_audio.clicked.connect(lambda: self.run_cmd("pavucontrol"))

        btn_net = QPushButton("📶  Gerenciar Redes Wi-Fi, Cabo e VPN")
        btn_net.setObjectName("btn")
        btn_net.clicked.connect(lambda: self.run_cmd("kcmshell5 kcm_networkmanagement || systemsettings5"))

        btn_bt = QPushButton("🦷  Gerenciar Dispositivos Bluetooth")
        btn_bt.setObjectName("btn")
        btn_bt.clicked.connect(lambda: self.run_cmd("kcmshell5 kcm_bluetooth || systemsettings5"))

        c_layout.addWidget(btn_print)
        c_layout.addWidget(btn_audio)
        c_layout.addWidget(btn_net)
        c_layout.addWidget(btn_bt)

        layout.addWidget(card)
        layout.addStretch()
        return page

    def page_about(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(28, 28, 28, 28)
        layout.setSpacing(16)
        layout.addLayout(self.create_header("Sobre o KerigmaOS", "Especificações da distribuição."))

        card = QFrame()
        card.setObjectName("card")
        c_layout = QVBoxLayout(card)
        c_layout.setSpacing(10)

        info = QLabel(
            "<h2>KerigmaOS 1.0 Dev Edition</h2>"
            "<p><b>Base do Sistema:</b> Debian Bookworm 64-bit (Segurança UFW Ativa)</p>"
            "<p><b>Ambiente Gráfico:</b> KDE Plasma Custom + Kerigma Dock</p>"
            "<p><b>Suíte Integrada:</b> VSCodium, Node.js, Docker, Git, ZSH, VLC, Okular, Gwenview, Ark</p>"
            "<p><b>IA & Conhecimento Offline:</b> Ollama (Google Gemma 3n E2B/E4B) + Kiwix</p>"
        )
        info.setWordWrap(True)
        c_layout.addWidget(info)

        layout.addWidget(card)
        layout.addStretch()
        return page

    def apply_theme(self, scheme):
        self.run_cmd(f"plasma-apply-colorscheme {scheme}")
        QMessageBox.information(self, "KerigmaOS", f"Tema {scheme} aplicado com sucesso!")

    def set_window_buttons(self, style):
        if style == "mac":
            self.run_cmd("kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft 'XIA'")
            self.run_cmd("kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight ''")
        else:
            self.run_cmd("kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft 'M'")
            self.run_cmd("kwriteconfig5 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnRight 'IAX'")
        self.run_cmd("qdbus org.kde.KWin /KWin reconfigure")
        QMessageBox.information(self, "KerigmaOS", "Posição dos botões da janela atualizada!")


if __name__ == "__main__":
    app = QApplication([])
    win = KerigmaSettings()
    win.show()
    app.exec_()
