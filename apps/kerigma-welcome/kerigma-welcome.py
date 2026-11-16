#!/usr/bin/env python3
import os
import re
import sys
import subprocess
import urllib.request
from PyQt5.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QRadioButton, QButtonGroup, QPushButton, QProgressBar,
    QFrame, QMessageBox, QStackedWidget
)
from PyQt5.QtCore import Qt, QThread, pyqtSignal
from PyQt5.QtGui import QFont, QIcon


class SetupWorker(QThread):
    status_signal = pyqtSignal(str)
    finished_signal = pyqtSignal(bool, str)

    def __init__(self, ai_model, wiki_type):
        super().__init__()
        self.ai_model = ai_model
        self.wiki_type = wiki_type

    def get_latest_zim_url(self, variant):
        base_url = "https://download.kiwix.org/zim/wikipedia/"
        req = urllib.request.urlopen(base_url, timeout=15)
        html = req.read().decode("utf-8", errors="ignore")
        pattern = rf'href="(wikipedia_pt_all_{variant}_[0-9\-]+\.zim)"'
        matches = sorted(re.findall(pattern, html))
        if not matches:
            raise RuntimeError(f"Arquivo ZIM ({variant}) não encontrado.")
        return base_url + matches[-1], matches[-1]

    def run(self):
        try:
            if self.ai_model != "none":
                self.status_signal.emit(f"Iniciando motor Ollama e baixando {self.ai_model}...")
                subprocess.Popen(["ollama", "serve"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                proc = subprocess.run(["ollama", "pull", self.ai_model], capture_output=True, text=True)
                if proc.returncode != 0:
                    raise RuntimeError(f"Erro ao baixar modelo Gemma: {proc.stderr}")

            if self.wiki_type != "none":
                self.status_signal.emit("Localizando última versão da Wikipédia em Português...")
                url, filename = self.get_latest_zim_url(self.wiki_type)
                dest_dir = os.path.expanduser("~/Documentos/Wikipedia")
                os.makedirs(dest_dir, exist_ok=True)
                dest_path = os.path.join(dest_dir, filename)

                self.status_signal.emit(f"Baixando {filename}...")
                proc = subprocess.run(["wget", "-c", "-O", dest_path, url])
                if proc.returncode != 0:
                    raise RuntimeError("Falha no download da Wikipédia.")

            self.finished_signal.emit(True, "Configuração concluída com sucesso!")
        except Exception as e:
            self.finished_signal.emit(False, str(e))


class KerigmaWelcome(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Bem-vindo ao KerigmaOS")
        self.setFixedSize(720, 540)
        self.setWindowIcon(QIcon("/usr/share/pixmaps/kerigma-logo.svg"))
        self.selected_ai = "none"
        self.is_live = os.path.exists("/run/live/medium") and ("--modules" not in sys.argv)
        self.setup_ui()

    def setup_ui(self):
        self.setStyleSheet("""
            QWidget {
                background-color: #14141f;
                color: #f0f0f7;
                font-family: 'Noto Sans', sans-serif;
            }
            QFrame#card {
                background-color: #202032;
                border-radius: 14px;
                border: 1px solid #32324c;
            }
            QPushButton#install_btn {
                background-color: #007aff;
                color: white;
                border-radius: 10px;
                padding: 16px;
                font-weight: bold;
                font-size: 15px;
            }
            QPushButton#install_btn:hover {
                background-color: #0062cc;
            }
            QPushButton#try_btn {
                background-color: #2c2c44;
                color: white;
                border-radius: 10px;
                padding: 16px;
                font-weight: bold;
                font-size: 14px;
                border: 1px solid #424264;
            }
            QPushButton#try_btn:hover {
                background-color: #383856;
            }
            QRadioButton {
                spacing: 8px;
                font-size: 13px;
                padding: 4px;
            }
            QProgressBar {
                border: none;
                border-radius: 5px;
                background-color: #2a2a3d;
                height: 10px;
            }
            QProgressBar::chunk {
                background-color: #007aff;
                border-radius: 5px;
            }
        """)

        main_layout = QVBoxLayout(self)
        self.stack = QStackedWidget()
        self.stack.addWidget(self.create_live_gate_page())
        self.stack.addWidget(self.create_modules_page())

        if self.is_live:
            self.stack.setCurrentIndex(0)
        else:
            self.stack.setCurrentIndex(1)

        main_layout.addWidget(self.stack)

    def create_live_gate_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(32, 32, 32, 32)
        layout.setSpacing(20)

        title = QLabel("KerigmaOS 1.0")
        title.setAlignment(Qt.AlignCenter)
        title.setFont(QFont("Noto Sans", 26, QFont.Bold))

        subtitle = QLabel("A elegância do macOS com o poder do Linux para desenvolvedores.\nEscolha como deseja iniciar o sistema:")
        subtitle.setAlignment(Qt.AlignCenter)
        subtitle.setStyleSheet("color: #a0a0bc; font-size: 14px;")

        layout.addWidget(title)
        layout.addWidget(subtitle)

        card = QFrame()
        card.setObjectName("card")
        c_layout = QVBoxLayout(card)
        c_layout.setContentsMargins(24, 24, 24, 24)
        c_layout.setSpacing(16)

        btn_install = QPushButton("💿  Instalar o KerigmaOS no Computador\n(Configurar idioma, teclado, disco e criar seu usuário e senha)")
        btn_install.setObjectName("install_btn")
        btn_install.clicked.connect(self.launch_installer)

        btn_try = QPushButton("🖥️  Experimentar o KerigmaOS sem Instalar (Modo Live)\n(Testar a área de trabalho, Dock, Ajustes e ferramentas agora)")
        btn_try.setObjectName("try_btn")
        btn_try.clicked.connect(lambda: self.stack.setCurrentIndex(1))

        c_layout.addWidget(btn_install)
        c_layout.addWidget(btn_try)
        layout.addWidget(card)
        layout.addStretch()
        return page

    def launch_installer(self):
        subprocess.Popen(["sudo", "calamares"])
        self.close()

    def create_modules_page(self):
        page = QWidget()
        layout = QVBoxLayout(page)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(14)

        title = QLabel("Configuração de IA & Conhecimento Offline")
        title.setFont(QFont("Noto Sans", 18, QFont.Bold))
        subtitle = QLabel("Escolha os módulos locais que deseja habilitar no seu KerigmaOS:")
        subtitle.setStyleSheet("color: #a0a0b8; font-size: 13px;")
        layout.addWidget(title)
        layout.addWidget(subtitle)

        ai_card = QFrame()
        ai_card.setObjectName("card")
        ai_layout = QVBoxLayout(ai_card)
        ai_title = QLabel("1. Agente de IA Local — Google Gemma 3n (Ollama)")
        ai_title.setFont(QFont("Noto Sans", 12, QFont.Bold))
        ai_layout.addWidget(ai_title)

        self.ai_group = QButtonGroup(self)
        ai_options = [
            ("none", "Não instalar modelo agora"),
            ("gemma3n:e2b", "Modo Leve — Google Gemma 3n E2B (Ideal para Notebooks e CPU)"),
            ("gemma3n:e4b", "Modo Performance — Google Gemma 3n E4B (Maior precisão em código e GPU)")
        ]
        for idx, (val, text) in enumerate(ai_options):
            rb = QRadioButton(text)
            rb.setProperty("value", val)
            if idx == 1:
                rb.setChecked(True)
            self.ai_group.addButton(rb)
            ai_layout.addWidget(rb)

        layout.addWidget(ai_card)

        wiki_card = QFrame()
        wiki_card.setObjectName("card")
        wiki_layout = QVBoxLayout(wiki_card)
        wiki_title = QLabel("2. Wikipédia Offline (Kiwix)")
        wiki_title.setFont(QFont("Noto Sans", 12, QFont.Bold))
        wiki_layout.addWidget(wiki_title)

        self.wiki_group = QButtonGroup(self)
        wiki_options = [
            ("none", "Não baixar Wikipédia agora"),
            ("nopic", "Versão Compacta — Apenas Texto em PT-BR (~4 GB)"),
            ("maxi", "Versão Completa — Texto + Imagens em PT-BR (~22 GB)")
        ]
        for idx, (val, text) in enumerate(wiki_options):
            rb = QRadioButton(text)
            rb.setProperty("value", val)
            if idx == 1:
                rb.setChecked(True)
            self.wiki_group.addButton(rb)
            wiki_layout.addWidget(rb)

        layout.addWidget(wiki_card)

        self.status_label = QLabel("Pronto para configurar.")
        self.status_label.setStyleSheet("color: #a0a0b8; font-size: 12px;")
        self.progress = QProgressBar()
        self.progress.setRange(0, 100)
        self.progress.setValue(0)
        layout.addWidget(self.status_label)
        layout.addWidget(self.progress)

        btn_layout = QHBoxLayout()
        btn_skip = QPushButton("Ir direto para a Área de Trabalho")
        btn_skip.setStyleSheet("background: transparent; color: #a0a0b8; border: none; font-weight: bold;")
        btn_skip.clicked.connect(self.close)

        self.btn_install = QPushButton("Baixar Módulos Selecionados")
        self.btn_install.setObjectName("install_btn")
        self.btn_install.setStyleSheet("padding: 10px 20px; font-size: 13px;")
        self.btn_install.clicked.connect(self.start_setup)

        btn_layout.addWidget(btn_skip)
        btn_layout.addStretch()
        btn_layout.addWidget(self.btn_install)
        layout.addLayout(btn_layout)
        return page

    def start_setup(self):
        self.selected_ai = self.ai_group.checkedButton().property("value")
        wiki_val = self.wiki_group.checkedButton().property("value")

        if self.selected_ai == "none" and wiki_val == "none":
            self.close()
            return

        self.btn_install.setEnabled(False)
        self.progress.setRange(0, 0)

        self.worker = SetupWorker(self.selected_ai, wiki_val)
        self.worker.status_signal.connect(self.status_label.setText)
        self.worker.finished_signal.connect(self.on_finished)
        self.worker.start()

    def on_finished(self, success, message):
        self.progress.setRange(0, 100)
        self.progress.setValue(100 if success else 0)
        self.status_label.setText(message)
        self.btn_install.setEnabled(True)

        if success:
            autostart_file = os.path.expanduser("~/.config/autostart/kerigma-welcome.desktop")
            if os.path.exists(autostart_file) and not self.is_live:
                os.remove(autostart_file)
            QMessageBox.information(self, "KerigmaOS", "Módulos configurados com sucesso!")
            self.close()
        else:
            QMessageBox.warning(self, "Aviso", message)


if __name__ == "__main__":
    app = QApplication([])
    window = KerigmaWelcome()
    window.show()
    app.exec_()
