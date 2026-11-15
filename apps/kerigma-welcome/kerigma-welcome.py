#!/usr/bin/env python3
import os
import re
import subprocess
import urllib.request
from PyQt5.QtWidgets import (
    QApplication, QWidget, QVBoxLayout, QHBoxLayout, QLabel,
    QRadioButton, QButtonGroup, QPushButton, QProgressBar, QFrame, QMessageBox
)
from PyQt5.QtCore import QThread, pyqtSignal
from PyQt5.QtGui import QFont


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
            raise RuntimeError(f"Arquivo ZIM ({variant}) não encontrado no servidor Kiwix.")
        return base_url + matches[-1], matches[-1]

    def run(self):
        try:
            # 1. Baixar Modelo Google Gemma 3n via Ollama
            if self.ai_model != "none":
                self.status_signal.emit(f"Iniciando motor Ollama e baixando {self.ai_model}...")
                subprocess.Popen(["ollama", "serve"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                proc = subprocess.run(
                    ["ollama", "pull", self.ai_model],
                    capture_output=True, text=True
                )
                if proc.returncode != 0:
                    raise RuntimeError(f"Erro ao baixar modelo Gemma: {proc.stderr}")

            # 2. Baixar Base da Wikipédia via Kiwix
            if self.wiki_type != "none":
                self.status_signal.emit("Localizando última versão da Wikipédia em Português...")
                url, filename = self.get_latest_zim_url(self.wiki_type)
                dest_dir = os.path.expanduser("~/Documentos/Wikipedia")
                os.makedirs(dest_dir, exist_ok=True)
                dest_path = os.path.join(dest_dir, filename)

                self.status_signal.emit(f"Baixando {filename} (isso pode levar alguns minutos)...")
                proc = subprocess.run(["wget", "-c", "-O", dest_path, url])
                if proc.returncode != 0:
                    raise RuntimeError("Falha no download da Wikipédia. Verifique sua conexão.")

            self.finished_signal.emit(True, "Configuração concluída com sucesso!")
        except Exception as e:
            self.finished_signal.emit(False, str(e))


class KerigmaWelcome(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Kerigma Welcome — Configuração Inicial")
        self.setFixedSize(640, 540)
        self.selected_ai = "none"
        self.setup_ui()

    def setup_ui(self):
        self.setStyleSheet("""
            QWidget {
                background-color: #181824;
                color: #f0f0f5;
                font-family: 'Noto Sans', sans-serif;
            }
            QFrame#card {
                background-color: #222232;
                border-radius: 12px;
                border: 1px solid #323248;
            }
            QRadioButton {
                spacing: 8px;
                font-size: 13px;
                padding: 4px;
            }
            QPushButton#primary {
                background-color: #007aff;
                color: white;
                border-radius: 8px;
                padding: 10px 20px;
                font-weight: bold;
                font-size: 13px;
            }
            QPushButton#primary:hover {
                background-color: #0062cc;
            }
            QPushButton#primary:disabled {
                background-color: #3a3a52;
                color: #8888a0;
            }
            QProgressBar {
                border: none;
                border-radius: 5px;
                background-color: #2a2a3d;
                height: 10px;
                text-align: center;
            }
            QProgressBar::chunk {
                background-color: #007aff;
                border-radius: 5px;
            }
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(16)

        # Cabeçalho
        title = QLabel("Bem-vindo ao KerigmaOS")
        title.setFont(QFont("Noto Sans", 20, QFont.Bold))
        subtitle = QLabel("Personalize seus módulos offline de Inteligência Artificial (Google Gemma) e Conhecimento:")
        subtitle.setStyleSheet("color: #a0a0b8; font-size: 13px;")
        layout.addWidget(title)
        layout.addWidget(subtitle)

        # Card 1: Agente IA Local (Google Gemma 3n)
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

        # Card 2: Wikipédia Offline
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

        # Status e Progresso
        self.status_label = QLabel("Pronto para configurar.")
        self.status_label.setStyleSheet("color: #a0a0b8; font-size: 12px;")
        self.progress = QProgressBar()
        self.progress.setRange(0, 100)
        self.progress.setValue(0)
        layout.addWidget(self.status_label)
        layout.addWidget(self.progress)

        # Botões
        btn_layout = QHBoxLayout()
        btn_skip = QPushButton("Pular por enquanto")
        btn_skip.setStyleSheet("background: transparent; color: #a0a0b8; border: none;")
        btn_skip.clicked.connect(self.close)

        self.btn_install = QPushButton("Instalar Módulos Selecionados")
        self.btn_install.setObjectName("primary")
        self.btn_install.clicked.connect(self.start_setup)

        btn_layout.addWidget(btn_skip)
        btn_layout.addStretch()
        btn_layout.addWidget(self.btn_install)
        layout.addLayout(btn_layout)

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
            if os.path.exists(autostart_file):
                os.remove(autostart_file)
            cmd_hint = f" Use 'ollama run {self.selected_ai}' no terminal." if self.selected_ai != "none" else ""
            QMessageBox.information(self, "KerigmaOS", f"Módulos instalados com sucesso!{cmd_hint}")
            self.close()
        else:
            QMessageBox.warning(self, "Aviso", message)


if __name__ == "__main__":
    app = QApplication([])
    window = KerigmaWelcome()
    window.show()
    app.exec_()
