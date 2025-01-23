ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-silverblue}"
ARG BASE_IMAGE_FLAVOR="${BASE_IMAGE_FLAVOR:-main}"
ARG IMAGE_FLAVOR="${IMAGE_FLAVOR:-main}"
ARG NVIDIA_FLAVOR=${NVIDIA_FLAVOR:-nvidia}""
ARG KERNEL_FLAVOR="${KERNEL_FLAVOR:-bazzite}"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG SOURCE_IMAGE="${SOURCE_IMAGE:-$BASE_IMAGE_NAME-$BASE_IMAGE_FLAVOR}"
ARG BASE_IMAGE="ghcr.io/ublue-os/${SOURCE_IMAGE}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-41}"
ARG SHA_HEAD_SHORT="${SHA_HEAD_SHORT}"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY}"

FROM ghcr.io/ublue-os/${KERNEL_FLAVOR}-kernel:${FEDORA_MAJOR_VERSION} AS kernel
FROM ghcr.io/ublue-os/akmods:${KERNEL_FLAVOR}-${FEDORA_MAJOR_VERSION} AS akmods
FROM ghcr.io/ublue-os/akmods-extra:${KERNEL_FLAVOR}-${FEDORA_MAJOR_VERSION} AS akmods-extra

FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS drelbsos

ARG IMAGE_NAME="${IMAGE_NAME:-drelbsos}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR:-ublue-os}"
ARG IMAGE_FLAVOR="${IMAGE_FLAVOR:-main}"
ARG NVIDIA_FLAVOR="${NVIDIA_FLAVOR:-nvidia}"
ARG KERNEL_FLAVOR="${KERNEL_FLAVOR:-bazzite}"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-silverblue}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-41}"
ARG SHA_HEAD_SHORT="${SHA_HEAD_SHORT}"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY}"

COPY system_files/desktop/shared system_files/desktop/${BASE_IMAGE_NAME} /

# Setup Copr repos
RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    curl -Lo /usr/bin/copr https://raw.githubusercontent.com/ublue-os/COPR-command/main/copr && \
    chmod +x /usr/bin/copr && \
    curl -Lo /etc/yum.repos.d/_copr_kylegospo-bazzite.repo https://copr.fedorainfracloud.org/coprs/kylegospo/bazzite/repo/fedora-"${FEDORA_MAJOR_VERSION}"/kylegospo-bazzite-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
    curl -Lo /etc/yum.repos.d/_copr_ublue-os-staging.repo https://copr.fedorainfracloud.org/coprs/ublue-os/staging/repo/fedora-"${FEDORA_MAJOR_VERSION}"/ublue-os-staging-fedora-"${FEDORA_MAJOR_VERSION}".repo?arch=x86_64 && \
    curl -Lo /etc/yum.repos.d/_copr_kylegospo-latencyflex.repo https://copr.fedorainfracloud.org/coprs/kylegospo/LatencyFleX/repo/fedora-"${FEDORA_MAJOR_VERSION}"/kylegospo-LatencyFleX-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
    curl -Lo /etc/yum.repos.d/_copr_kylegospo-rom-properties.repo https://copr.fedorainfracloud.org/coprs/kylegospo/rom-properties/repo/fedora-"${FEDORA_MAJOR_VERSION}"/kylegospo-rom-properties-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
    curl -Lo /etc/yum.repos.d/_copr_kylegospo-webapp-manager.repo https://copr.fedorainfracloud.org/coprs/kylegospo/webapp-manager/repo/fedora-"${FEDORA_MAJOR_VERSION}"/kylegospo-webapp-manager-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
    curl -Lo /etc/yum.repos.d/_copr_hhd-dev-hhd.repo https://copr.fedorainfracloud.org/coprs/hhd-dev/hhd/repo/fedora-"${FEDORA_MAJOR_VERSION}"/hhd-dev-hhd-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
    curl -Lo /etc/yum.repos.d/_copr_che-nerd-fonts.repo https://copr.fedorainfracloud.org/coprs/che/nerd-fonts/repo/fedora-"${FEDORA_MAJOR_VERSION}"/che-nerd-fonts-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
    curl -Lo /etc/yum.repos.d/_copr_rok-cdemu.repo https://copr.fedorainfracloud.org/coprs/rok/cdemu/repo/fedora-"${FEDORA_MAJOR_VERSION}"/rok-cdemu-fedora-"${FEDORA_MAJOR_VERSION}".rep && \
    curl -Lo /etc/yum.repos.d/_copr_rodoma92-rmlint.repo https://copr.fedorainfracloud.org/coprs/rodoma92/rmlint/repo/fedora-"${FEDORA_MAJOR_VERSION}"/rodoma92-rmlint-fedora-"${FEDORA_MAJOR_VERSION}".repo && \
    curl -Lo /etc/yum.repos.d/hardware:razer.repo https://download.opensuse.org/repositories/hardware:/razer/Fedora_"${FEDORA_MAJOR_VERSION}"/hardware:razer.repo && \
    rpm-ostree install \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm && \
    sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo && \
    curl -Lo /etc/yum.repos.d/negativo17-fedora-rar.repo https://negativo17.org/repos/fedora-rar.repo && \    
    /usr/libexec/containerbuild/cleanup.sh && \
    ostree container commit

# Install kernel
RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=bind,from=kernel,src=/tmp/rpms,dst=/tmp/kernel-rpms \
    rpm-ostree cliwrap install-to-root / && \
    echo "Will install ${KERNEL_FLAVOR} kernel" && \
    rpm-ostree override replace \
    --experimental \
        /tmp/kernel-rpms/kernel-[0-9]*.rpm \
        /tmp/kernel-rpms/kernel-core-*.rpm \
        /tmp/kernel-rpms/kernel-modules-*.rpm \
        /tmp/kernel-rpms/kernel-uki-virt-*.rpm && \
    rpm-ostree install \
        scx-scheds && \
    /usr/libexec/containerbuild/cleanup.sh && \
    ostree container commit

# Add ublue packages
RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=bind,from=akmods,src=/rpms,dst=/tmp/akmods-rpms \
    --mount=type=bind,from=akmods-extra,src=/rpms,dst=/tmp/akmods-extra-rpms \
    sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/_copr_ublue-os-akmods.repo && \
    rpm-ostree install \
        /tmp/akmods-rpms/kmods/*xone*.rpm \
        /tmp/akmods-rpms/kmods/*openrazer*.rpm \
        /tmp/akmods-rpms/kmods/*v4l2loopback*.rpm \
        /tmp/akmods-rpms/kmods/*wl*.rpm \
        /tmp/akmods-extra-rpms/kmods/*gcadapter_oc*.rpm \
        /tmp/akmods-extra-rpms/kmods/*nct6687*.rpm \
        /tmp/akmods-extra-rpms/kmods/*zenergy*.rpm \
        /tmp/akmods-extra-rpms/kmods/*vhba*.rpm \
        /tmp/akmods-extra-rpms/kmods/*ryzen-smu*.rpm && \
    rpm-ostree override replace \
        --experimental \
        --from repo=copr:copr.fedorainfracloud.org:ublue-os:staging \
            fwupd \
            fwupd-plugin-flashrom \
            fwupd-plugin-modem-manager \
            fwupd-plugin-uefi-capsule-data && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/rpmfusion-*.repo && \
    /usr/libexec/containerbuild/cleanup.sh && \
    ostree container commit

# Install codec stuff
RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/rpmfusion-*.repo && \
    rpm-ostree install \
        libaacs \
        libbdplus \
        libbluray && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/rpmfusion-*.repo && \
    /usr/libexec/containerbuild/cleanup.sh && \
    ostree container commit

# Remove unneeded packages
RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    rpm-ostree override remove \
        ublue-os-update-services \
        firefox \
        firefox-langpacks && \
    /usr/libexec/containerbuild/cleanup.sh && \
    ostree container commit

# Install new packages
RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    rpm-ostree install \
        python3-pip \
        libadwaita \
        duperemove \
        sqlite \
        xwininfo \
        xrandr \
        compsize \
        ryzenadj \
        input-remapper \
        tuned-profiles-cpu-partitioning \
        i2c-tools \
        udica \
        python3-icoextract \
        webapp-manager \
        zsh \
        btop \
        lshw \
        xdotool \
        wmctrl \
        libcec \
        yad \
        f3 \
        pulseaudio-utils \
        lzip \
        rar \
        libxcrypt-compat \
        mesa-libGLU \
        vulkan-tools \
        xwiimote-ng \
        twitter-twemoji-fonts \
        google-noto-sans-cjk-fonts \
        google-droid-sans-mono-fonts \
        lato-fonts \
        fira-code-fonts \
        nerd-fonts \
        fastfetch \
        vim \
        topgrade \
        ydotool \
        cdemu-daemon \
        cdemu-client \
        gcdemu \
        openrazer-daemon \
        egl-utils \
        ncdu \
        btrfs-assistant \
        lsb_release && \
    # DVD Audio Extractor
    # rpm-ostree install https://www.dvdae.com/dvdae/dvdae-8.6.0-0.x86_64.rpm && \
    # setcap cap_dac_override,cap_sys_rawio=ep /usr/bin/dvdae && \
    # setcap cap_dac_override,cap_sys_rawio=ep /usr/bin/dvdae-gui && \
    curl -Lo /usr/bin/installcab https://raw.githubusercontent.com/KyleGospo/steam-proton-mf-wmv/master/installcab.py && \
    chmod +x /usr/bin/installcab && \
    curl -Lo /usr/bin/install-mf-wmv https://github.com/KyleGospo/steam-proton-mf-wmv/blob/master/install-mf-wmv.sh && \
    chmod +x /usr/bin/install-mf-wmv && \
    /usr/libexec/containerbuild/cleanup.sh && \
    ostree container commit

# Configure GNOME overrides
RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    rpm-ostree install \
            rom-properties-gtk3 && \
    /usr/libexec/containerbuild/cleanup.sh && \
    ostree container commit

# Cleanup & Finalize
COPY system_files/overrides /
RUN rm -f /etc/profile.d/toolbox.sh && \
    mkdir -p /var/tmp && chmod 1777 /var/tmp && \
    sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nNoDisplay=true@g' /usr/share/applications/nvtop.desktop && \
    sed -i 's/#UserspaceHID.*/UserspaceHID=true/' /etc/bluetooth/input.conf && \
    sed -i "s/^SCX_SCHEDULER=.*/SCX_SCHEDULER=scx_lavd/" /etc/default/scx && \
    rm -f /usr/share/vulkan/icd.d/lvp_icd.*.json && \
    mkdir -p "/etc/profile.d/" && \
    ln -s "/usr/share/ublue-os/firstboot/launcher/login-profile.sh" \
    "/etc/profile.d/ublue-firstboot.sh" && \
    mkdir -p "/etc/xdg/autostart" && \
    echo "import \"/usr/share/ublue-os/just/81-bazzite-fixes.just\"" >> /usr/share/ublue-os/justfile && \
    echo "import \"/usr/share/ublue-os/just/84-bazzite-virt.just\"" >> /usr/share/ublue-os/justfile && \
    sed -i 's/stage/check/g' /etc/rpm-ostreed.conf && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_ublue-os-akmods.repo && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_kylegospo-bazzite.repo && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_ublue-os-staging.repo && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_kylegospo-latencyflex.repo && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_kylegospo-rom-properties.repo && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_kylegospo-webapp-manager.repo && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_hhd-dev-hhd.repo && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/_copr_che-nerd-fonts.repo && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/negativo17-fedora-rar.repo && \
    mkdir -p /etc/flatpak/remotes.d && \
    curl -Lo /etc/flatpak/remotes.d/flathub.flatpakrepo https://dl.flathub.org/repo/flathub.flatpakrepo && \
    systemctl enable input-remapper.service && \
    systemctl unmask bazzite-flatpak-manager.service && \
    systemctl enable bazzite-flatpak-manager.service && \
    systemctl enable incus-workaround.service && \
    systemctl enable bazzite-hardware-setup.service && \
    systemctl enable dev-hugepages1G.mount && \
    systemctl --global enable bazzite-user-setup.service && \
    systemctl --global enable podman.socket && \
    systemctl --global enable systemd-tmpfiles-setup.service && \
    sed -i 's@\[Desktop Entry\]@\[Desktop Entry\]\nNoDisplay=true@g' /usr/share/applications/yad-icon-browser.desktop && \
    sed -i '/^PRETTY_NAME/s/Bazzite/DrelbsOS/' /usr/lib/os-release && \
    curl -Lo /etc/dxvk-example.conf https://raw.githubusercontent.com/doitsujin/dxvk/master/dxvk.conf && \
    curl -Lo /usr/lib/sysctl.d/99-bore-scheduler.conf https://github.com/CachyOS/CachyOS-Settings/raw/master/usr/lib/sysctl.d/99-bore-scheduler.conf && \
    /usr/libexec/containerbuild/image-info && \
    /usr/libexec/containerbuild/build-initramfs && \
    /usr/libexec/containerbuild/cleanup.sh && \
    mkdir -p /var/tmp && \
    chmod 1777 /var/tmp && \
    ostree container commit

FROM ghcr.io/ublue-os/akmods-nvidia:${KERNEL_FLAVOR}-${FEDORA_MAJOR_VERSION} AS nvidia-akmods

FROM drelbsos AS drelbsos-nvidia

ARG IMAGE_NAME="${IMAGE_NAME:-drelbsos-nvidia}"
ARG IMAGE_VENDOR="${IMAGE_VENDOR:-ublue-os}"
ARG IMAGE_FLAVOR="${IMAGE_FLAVOR:-nvidia}"
ARG NVIDIA_FLAVOR="${NVIDIA_FLAVOR:-nvidia}"
ARG KERNEL_FLAVOR="${KERNEL_FLAVOR:-bazzite}"
ARG IMAGE_BRANCH="${IMAGE_BRANCH:-main}"
ARG BASE_IMAGE_NAME="${BASE_IMAGE_NAME:-silverblue}"
ARG FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-41}"
ARG VERSION_TAG="${VERSION_TAG}"
ARG VERSION_PRETTY="${VERSION_PRETTY}"

# Install NVIDIA driver

RUN --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=bind,from=nvidia-akmods,src=/rpms,dst=/tmp/akmods-rpms \
    sed -i 's@enabled=0@enabled=1@g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo && \

    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/rpmfusion*.repo && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-cisco-openh264.repo && \
    rpm-ostree install /tmp/akmods-rpms/ublue-os/ublue-os-nvidia-addons-*.rpm && \
    sed -i '0,/enabled=0/{s/enabled=0/enabled=1/}' /etc/yum.repos.d/nvidia-container-toolkit.repo && \
    source /tmp/akmods-rpms/kmods/nvidia-vars && \

    rpm-ostree install \
      	libnvidia-fbc \
	libva-nvidia-driver \
	nvidia-driver \
	nvidia-driver-cuda \
	nvidia-modprobe \
	nvidia-persistenced \
	nvidia-settings \
	nvidia-container-toolkit ${VARIANT_PKGS} \
    /tmp/akmods-rpms/kmods/kmod-nvidia*.fc${RELEASE}.rpm && \

   sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/nvidia-container-toolkit.repo && \
   sed -i "s/^MODULE_VARIANT=.*/MODULE_VARIANT=$KERNEL_MODULE_TYPE/" /etc/nvidia/kernel.conf && \
   systemctl enable nvidia-persistenced.service && \
   systemctl enable ublue-nvctk-cdi.service && \
   semodule --verbose --install /usr/share/selinux/packages/nvidia-container.pp && \
   echo "options nvidia NVreg_TemporaryFilePath=/var/tmp" >> /usr/lib/modprobe.d/nvidia-atomic.conf && \
   cp /etc/modprobe.d/nvidia-modeset.conf /usr/lib/modprobe.d/nvidia-modeset.conf && \
   sed -i 's@omit_drivers@force_drivers@g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf && \
    rm -f /usr/share/vulkan/icd.d/nouveau_icd.*.json && \
    ln -s libnvidia-ml.so.1 /usr/lib64/libnvidia-ml.so && \
    sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo && \
    /usr/libexec/containerbuild/cleanup.sh && \
    ostree container commit

# Cleanup & Finalize
RUN mkdir -p /var/tmp && chmod 1777 /var/tmp && \
    /usr/libexec/containerbuild/image-info && \
    /usr/libexec/containerbuild/build-initramfs && \
    /usr/libexec/containerbuild/cleanup.sh && \
    ostree container commit
