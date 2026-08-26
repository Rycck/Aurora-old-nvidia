#!/bin/bash

set -ouex pipefail

# Copy the contents of system_files/ of the git repo to /
cp -avf "/ctx/system_files"/. /

dnf install -y fastfetch

# Install the drivers
dnf install -y \
    dkms \
    gcc-c++ \
    libnvidia-fbc \
    libva-nvidia-driver \
    nvidia-driver \
    nvidia-driver-cuda \
    nvidia-modprobe \
    nvidia-persistenced \
    nvidia-settings

dnf download dkms-nvidia
rpm -i *dkms-nvidia*.rpm --noscripts --nodeps

# FIX: Changed package name to dkms-nvidia to match what was installed above
NVIDIA_VERSION=$(rpm -q --qf "%{VERSION}" dkms-nvidia)
KERNEL_VERSION="$(find "/usr/lib/modules" -maxdepth 1 -type d ! -path "/usr/lib/modules" -exec basename '{}' ';' | sort | grep -v kabi | tail -n 1)"

dkms install -m nvidia -v "${NVIDIA_VERSION}" -k "${KERNEL_VERSION}"

# Manual compression fallback: ensures modules are compressed even if DKMS hooks fail in the container
find "/lib/modules/${KERNEL_VERSION}/extra" -name "*.ko" -exec zstd --rm {} +
depmod -a "${KERNEL_VERSION}"

tee /usr/lib/modprobe.d/00-nouveau-blacklist.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF

echo nvidia >/usr/lib/modules-load.d/nvidia.conf
echo nvidia-uvm >>/usr/lib/modules-load.d/nvidia.conf

tee /usr/lib/bootc/kargs.d/00-nvidia.toml <<'EOF'
kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nvidia-drm.modeset=1"]
EOF

# Ensure the directory exists before running sed
mkdir -p /usr/lib/dracut/dracut.conf.d
touch /usr/lib/dracut/dracut.conf.d/99-nvidia.conf

# we must force driver load to fix black screen on boot for nvidia desktops
sed -i 's@omit_drivers@force_drivers@g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf

# as we need forced load, also must pre-load intel/amd iGPU else chromium web browsers fail to use hardware acceleration
sed -i 's@ nvidia @ i915 amdgpu nvidia @g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf

dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --zstd -v --add ostree -f "/lib/modules/$KERNEL_VERSION/initramfs.img"
