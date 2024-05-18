#!/bin/bash -e
export RED_COLOR='\e[1;31m'
export GREEN_COLOR='\e[1;32m'
export YELLOW_COLOR='\e[1;33m'
export BLUE_COLOR='\e[1;34m'
export PINK_COLOR='\e[1;35m'
export SHAN='\e[1;33;5m'
export RES='\e[0m'
export mirror=raw.githubusercontent.com/gitbruc/cooluc-op/master
export gitea=git.cooluc.com
export github="github.com"

# Source branch
if [ "$1" = "dev" ]; then
    export branch=openwrt-23.05
    export version=snapshots-23.05
    export toolchain_version=openwrt-23.05
elif [ "$1" = "rc2" ]; then
    latest_release="v$(curl -s https://$mirror/tags/v23)"
    export branch=$latest_release
    export version=rc2
    export toolchain_version=openwrt-23.05
fi

# lan
[ -n "$LAN" ] && export LAN=$LAN || export LAN=10.0.0.1

# platform
[ "$2" = "x86_64" ] && export platform="x86_64" toolchain_arch="x86_64"

# gcc13 & 14 & 15
if [ "$USE_GCC13" = y ]; then
    export USE_GCC13=y
    # use mold
    [ "$USE_MOLD" = y ] && USE_MOLD=y
elif [ "$USE_GCC14" = y ]; then
    export USE_GCC14=y
    # use mold
    [ "$USE_MOLD" = y ] && USE_MOLD=y
elif [ "$USE_GCC15" = y ]; then
    export USE_GCC15=y
    # use mold
    [ "$USE_MOLD" = y ] && USE_MOLD=y
fi

# use glibc
export USE_GLIBC=$USE_GLIBC

# lrng
export ENABLE_LRNG=$ENABLE_LRNG

# kernel build with clang lto
export KERNEL_CLANG_LTO=$KERNEL_CLANG_LTO

# print version
echo -e "\r\n${GREEN_COLOR}Building $branch${RES}\r\n"
if [ "$platform" = "x86_64" ]; then
    echo -e "${GREEN_COLOR}Model: x86_64${RES}"
fi
curl -s https://$mirror/tags/kernel-6.6 > kernel.txt
kmod_hash=$(grep HASH kernel.txt | awk -F'HASH-' '{print $2}' | awk '{print $1}' | md5sum | awk '{print $1}')
kmodpkg_name=$(echo $(grep HASH kernel.txt | awk -F'HASH-' '{print $2}' | awk '{print $1}')-1-$(echo $kmod_hash))
echo -e "${GREEN_COLOR}Kernel: $kmodpkg_name ${RES}"
rm -f kernel.txt

echo -e "${GREEN_COLOR}Date: $CURRENT_DATE${RES}\r\n"

if [ "$USE_GCC13" = "y" ]; then
    echo -e "${GREEN_COLOR}GCC VERSION: 13${RES}"
elif [ "$USE_GCC14" = "y" ]; then
    echo -e "${GREEN_COLOR}GCC VERSION: 14${RES}"
elif [ "$USE_GCC15" = "y" ]; then
    echo -e "${GREEN_COLOR}GCC VERSION: 15${RES}"
else
    echo -e "${GREEN_COLOR}GCC VERSION: 11${RES}"
fi
[ -n "$LAN" ] && echo -e "${GREEN_COLOR}LAN: $LAN${RES}" || echo -e "${GREEN_COLOR}LAN: 10.0.0.1${RES}"
[ "$USE_MOLD" = "y" ] && echo -e "${GREEN_COLOR}USE_MOLD: true${RES}" || echo -e "${GREEN_COLOR}USE_MOLD: false${RES}"
[ "$ENABLE_OTA" = "y" ] && echo -e "${GREEN_COLOR}ENABLE_OTA: true${RES}" || echo -e "${GREEN_COLOR}ENABLE_OTA: false${RES}"
[ "$ENABLE_BPF" = "y" ] && echo -e "${GREEN_COLOR}ENABLE_BPF: true${RES}" || echo -e "${GREEN_COLOR}ENABLE_BPF: false${RES}"
[ "$ENABLE_LTO" = "y" ] && echo -e "${GREEN_COLOR}ENABLE_LTO: true${RES}" || echo -e "${GREEN_COLOR}ENABLE_LTO: false${RES}"
[ "$ENABLE_LRNG" = "y" ] && echo -e "${GREEN_COLOR}ENABLE_LRNG: true${RES}" || echo -e "${GREEN_COLOR}ENABLE_LRNG: false${RES}"
[ "$BUILD_FAST" = "y" ] && echo -e "${GREEN_COLOR}BUILD_FAST: true${RES}" || echo -e "${GREEN_COLOR}BUILD_FAST: false${RES}"
[ "$MINIMAL_BUILD" = "y" ] && echo -e "${GREEN_COLOR}MINIMAL_BUILD: true${RES}" || echo -e "${GREEN_COLOR}MINIMAL_BUILD: false${RES}"
[ "$KERNEL_CLANG_LTO" = "y" ] && echo -e "${GREEN_COLOR}KERNEL_CLANG_LTO: true${RES}\r\n" || echo -e "${GREEN_COLOR}KERNEL_CLANG_LTO: false${RES}\r\n"


# 安装 feeds
[ "$(whoami)" = "runner" ] && group "feeds install -a"
./scripts/feeds install -a
[ "$(whoami)" = "runner" ] && endgroup

# loader dl
if [ -f ../dl.gz ]; then
    tar xf ../dl.gz -C .
fi


if [ "$USE_GCC13" = "y" ]; then
    echo -e "${GREEN_COLOR}GCC VERSION: 13${RES}"
elif [ "$USE_GCC14" = "y" ]; then
    echo -e "${GREEN_COLOR}GCC VERSION: 14${RES}"
elif [ "$USE_GCC15" = "y" ]; then
    echo -e "${GREEN_COLOR}GCC VERSION: 15${RES}"
else
    echo -e "${GREEN_COLOR}GCC VERSION: 11${RES}"
fi
[ -n "$LAN" ] && echo -e "${GREEN_COLOR}LAN: $LAN${RES}" || echo -e "${GREEN_COLOR}LAN: 10.0.0.1${RES}"
[ "$USE_MOLD" = "y" ] && echo -e "${GREEN_COLOR}USE_MOLD: true${RES}" || echo -e "${GREEN_COLOR}USE_MOLD: false${RES}"
[ "$ENABLE_OTA" = "y" ] && echo -e "${GREEN_COLOR}ENABLE_OTA: true${RES}" || echo -e "${GREEN_COLOR}ENABLE_OTA: false${RES}"
[ "$ENABLE_BPF" = "y" ] && echo -e "${GREEN_COLOR}ENABLE_BPF: true${RES}" || echo -e "${GREEN_COLOR}ENABLE_BPF: false${RES}"
[ "$ENABLE_LTO" = "y" ] && echo -e "${GREEN_COLOR}ENABLE_LTO: true${RES}" || echo -e "${GREEN_COLOR}ENABLE_LTO: false${RES}"
[ "$ENABLE_LRNG" = "y" ] && echo -e "${GREEN_COLOR}ENABLE_LRNG: true${RES}" || echo -e "${GREEN_COLOR}ENABLE_LRNG: false${RES}"
[ "$BUILD_FAST" = "y" ] && echo -e "${GREEN_COLOR}BUILD_FAST: true${RES}" || echo -e "${GREEN_COLOR}BUILD_FAST: false${RES}"
[ "$MINIMAL_BUILD" = "y" ] && echo -e "${GREEN_COLOR}MINIMAL_BUILD: true${RES}" || echo -e "${GREEN_COLOR}MINIMAL_BUILD: false${RES}"
[ "$KERNEL_CLANG_LTO" = "y" ] && echo -e "${GREEN_COLOR}KERNEL_CLANG_LTO: true${RES}\r\n" || echo -e "${GREEN_COLOR}KERNEL_CLANG_LTO: false${RES}\r\n"


###############################################
echo -e "\n${GREEN_COLOR}Patching ...${RES}\n"

# scripts
curl -sO https://$mirror/openwrt/scripts/00-prepare_base.sh
curl -sO https://$mirror/openwrt/scripts/01-prepare_base-mainline.sh
curl -sO https://$mirror/openwrt/scripts/02-prepare_package.sh
curl -sO https://$mirror/openwrt/scripts/03-convert_translation.sh
curl -sO https://$mirror/openwrt/scripts/04-fix_kmod.sh
curl -sO https://$mirror/openwrt/scripts/05-fix-source.sh
curl -sO https://$mirror/openwrt/scripts/99_clean_build_cache.sh
chmod 0755 *sh
[ "$(whoami)" = "runner" ] && group "patching openwrt"
bash 00-prepare_base.sh
bash 02-prepare_package.sh
bash 03-convert_translation.sh
bash 05-fix-source.sh
if [ "$platform" = "x86_64" ]; then
    bash 01-prepare_base-mainline.sh
    bash 04-fix_kmod.sh
fi
[ "$(whoami)" = "runner" ] && endgroup

if [ "$USE_GCC14" = "y" ] || [ "$USE_GCC15" = "y" ]; then
    rm -rf toolchain/binutils
    cp -a ../master/openwrt/toolchain/binutils toolchain/binutils
fi

rm -f 0*-*.sh
rm -rf ../master

# Load devices Config
if [ "$platform" = "x86_64" ]; then
    curl -s https://$mirror/openwrt/23-config-musl-x86 > .config
    ALL_KMODS=y
fi

# config-common
if [ "$MINIMAL_BUILD" = "y" ]; then
    curl -s https://$mirror/openwrt/23-config-minimal-common >> .config
    echo 'VERSION_TYPE="minimal"' >> package/base-files/files/usr/lib/os-release
else
    curl -s https://$mirror/openwrt/23-config-common >> .config
fi

# ota
[ "$ENABLE_OTA" = "y" ] && [ "$version" = "rc2" ] && echo 'CONFIG_PACKAGE_luci-app-ota=y' >> .config

# bpf
export ENABLE_BPF=$ENABLE_BPF
[ "$ENABLE_BPF" = "y" ] && curl -s https://$mirror/openwrt/generic/config-bpf >> .config

# LTO
export ENABLE_LTO=$ENABLE_LTO
[ "$ENABLE_LTO" = "y" ] && curl -s https://$mirror/openwrt/generic/config-lto >> .config

# glibc
[ "$USE_GLIBC" = "y" ] && {
    curl -s https://$mirror/openwrt/generic/config-glibc >> .config
    sed -i '/NaiveProxy/d' .config
}

# mold
[ "$USE_MOLD" = "y" ] && echo 'CONFIG_USE_MOLD=y' >> .config

# clang
if [ "$KERNEL_CLANG_LTO" = "y" ]; then
    curl -s https://$mirror/openwrt/generic/config-clang >> .config
fi

# openwrt-23.05 gcc11/13/14/15
[ "$(whoami)" = "runner" ] && group "patching toolchain"
if [ "$USE_GCC13" = "y" ] || [ "$USE_GCC14" = "y" ] || [ "$USE_GCC15" = "y" ]; then
    [ "$USE_GCC13" = "y" ] && curl -s https://$mirror/openwrt/generic/config-gcc13 >> .config
    [ "$USE_GCC14" = "y" ] && curl -s https://$mirror/openwrt/generic/config-gcc14 >> .config
    [ "$USE_GCC15" = "y" ] && curl -s https://$mirror/openwrt/generic/config-gcc15 >> .config
    curl -s https://$mirror/openwrt/patch/generic/200-toolchain-gcc-update-to-13.2.patch | patch -p1
    curl -s https://$mirror/openwrt/patch/generic/201-toolchain-gcc-add-support-for-GCC-14.patch | patch -p1
    curl -s https://$mirror/openwrt/patch/generic/202-toolchain-gcc-add-support-for-GCC-15.patch | patch -p1
    # gcc14/15 init
    cp -a toolchain/gcc/patches-13.x toolchain/gcc/patches-14.x
    curl -s https://$mirror/openwrt/patch/generic/gcc-14/910-mbsd_multi.patch > toolchain/gcc/patches-14.x/910-mbsd_multi.patch
    cp -a toolchain/gcc/patches-14.x toolchain/gcc/patches-15.x
    curl -s https://$mirror/openwrt/patch/generic/gcc-15/970-macos_arm64-building-fix.patch > toolchain/gcc/patches-15.x/970-macos_arm64-building-fix.patch
elif [ ! "$USE_GLIBC" = "y" ]; then
    curl -s https://$mirror/openwrt/generic/config-gcc11 >> .config
fi
[ "$(whoami)" = "runner" ] && endgroup

# clean directory - github actions
[ "$(whoami)" = "runner" ] && echo 'CONFIG_AUTOREMOVE=y' >> .config

# uhttpd
[ "$ENABLE_UHTTPD" = "y" ] && sed -i '/nginx/d' .config && echo 'CONFIG_PACKAGE_ariang=y' >> .config

# Toolchain Cache
if [ "$BUILD_FAST" = "y" ]; then
    [ "$USE_GLIBC" = "y" ] && LIBC=glibc || LIBC=musl
    [ "$isCN" = "CN" ] && github_proxy="http://gh.cooluc.com/" || github_proxy=""
    echo -e "\n${GREEN_COLOR}Download Toolchain ...${RES}"
    PLATFORM_ID=""
    [ -f /etc/os-release ] && source /etc/os-release
    if [ "$PLATFORM_ID" = "platform:el9" ]; then
        TOOLCHAIN_URL="http://127.0.0.1:8080"
    else
        TOOLCHAIN_URL="$github_proxy"https://github.com/sbwml/toolchain-cache/releases/latest/download
    fi
    if [ "$USE_GCC13" = "y" ]; then
        curl -L "$TOOLCHAIN_URL"/toolchain_"$LIBC"_"$toolchain_arch"_13.tar.gz -o toolchain.tar.gz $CURL_BAR
    elif [ "$USE_GCC14" = "y" ]; then
        curl -L "$TOOLCHAIN_URL"/toolchain_"$LIBC"_"$toolchain_arch"_14.tar.gz -o toolchain.tar.gz $CURL_BAR
    elif [ "$USE_GCC15" = "y" ]; then
        curl -L "$TOOLCHAIN_URL"/toolchain_"$LIBC"_"$toolchain_arch"_15.tar.gz -o toolchain.tar.gz $CURL_BAR
    else
        curl -L "$TOOLCHAIN_URL"/toolchain_"$LIBC"_"$toolchain_arch".tar.gz -o toolchain.tar.gz $CURL_BAR
    fi
    echo -e "\n${GREEN_COLOR}Process Toolchain ...${RES}"
    tar -zxf toolchain.tar.gz && rm -f toolchain.tar.gz
    mkdir bin
    find ./staging_dir/ -name '*' -exec touch {} \; >/dev/null 2>&1
    find ./tmp/ -name '*' -exec touch {} \; >/dev/null 2>&1
fi

# init openwrt config
rm -rf tmp/*
if [ "$BUILD" = "n" ]; then
    exit 0
else
    make defconfig
fi
