#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

dnf install -y fastfetch

#!/usr/bin/env bash

# Cancela o script se algum comando falhar
set -oue pipefail

### 1. INSTALAR REPOSITÓRIOS RPM FUSION ###
dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

### 2. INSTALAR DRIVER DA NVIDIA IGNORANDO SCRIPTS DE CONTAINER ###
# --setopt=tsflags=noscripts impede que o RPM tente compilar o modulo como root no container
dnf install -y \
    --allowerasing \
    --setopt=install_weak_deps=False \
    --setopt=tsflags=noscripts \
    akmod-nvidia \
    xorg-x11-drv-nvidia \
    xorg-x11-drv-nvidia-cuda \
    libva-nvidia-driver

### 3. ATIVAR O SERVIÇO DE VÍDEO HÍBRIDO ###
systemctl enable switcheroo-control.service
