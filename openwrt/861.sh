#!/bin/bash -e
export RED_COLOR='\e[1;31m'
export GREEN_COLOR='\e[1;32m'
export YELLOW_COLOR='\e[1;33m'
export BLUE_COLOR='\e[1;34m'
export PINK_COLOR='\e[1;35m'
export SHAN='\e[1;33;5m'
export RES='\e[0m'

GROUP=
group() {
    endgroup
    echo "::group::  $1"
    GROUP=1
}
endgroup() {
    if [ -n "$GROUP" ]; then
        echo "::endgroup::"
    fi
    GROUP=
}

#####################################
#  NanoPi R4S OpenWrt Build Script  #
#####################################

# IP Location
ip_info=`curl -s https://ip.cooluc.com`;
export isCN=`echo $ip_info | grep -Po 'country_code\":"\K[^"]+'`;

# script url
if [ "$isCN" = "CN" ]; then
    export mirror=raw.githubusercontent.com/gitbruc/cooluc-op/master
else
    export mirror=raw.githubusercontent.com/gitbruc/cooluc-op/master
fi

# github actions - automatically retrieve `github raw` links
if [ "$(whoami)" = "runner" ] && [ -n "$GITHUB_REPO" ]; then
    export mirror=raw.githubusercontent.com/$GITHUB_REPO/master
fi

# private gitea
export gitea=git.cooluc.com

# github mirror
if [ "$isCN" = "CN" ]; then
    export github="github.com"
else
    export github="github.com"
fi

# Check root
if [ "$(id -u)" = "0" ]; then
    echo -e "${RED_COLOR}Building with root user is not supported.${RES}"
    exit 1
fi

# Start time
starttime=`date +'%Y-%m-%d %H:%M:%S'`
CURRENT_DATE=$(date +%s)

# Cpus
cores=`expr $(nproc --all) + 1`

# $CURL_BAR
if curl --help | grep progress-bar >/dev/null 2>&1; then
    CURL_BAR="--progress-bar";
fi

if [ -z "$1" ] || [ "$2" != "nanopi-r4s" -a "$2" != "nanopi-r5s" -a "$2" != "x86_64" -a "$2" != "netgear_r8500" -a "$2" != "armv8" ]; then
    echo -e "\n${RED_COLOR}Building type not specified.${RES}\n"
    echo -e "Usage:\n"
    echo -e "nanopi-r4s releases: ${GREEN_COLOR}bash build.sh rc2 nanopi-r4s${RES}"
    echo -e "nanopi-r4s snapshots: ${GREEN_COLOR}bash build.sh dev nanopi-r4s${RES}"
    echo -e "nanopi-r5s releases: ${GREEN_COLOR}bash build.sh rc2 nanopi-r5s${RES}"
    echo -e "nanopi-r5s snapshots: ${GREEN_COLOR}bash build.sh dev nanopi-r5s${RES}"
    echo -e "x86_64 releases: ${GREEN_COLOR}bash build.sh rc2 x86_64${RES}"
    echo -e "x86_64 snapshots: ${GREEN_COLOR}bash build.sh dev x86_64${RES}"
    echo -e "netgear-r8500 releases: ${GREEN_COLOR}bash build.sh rc2 netgear_r8500${RES}"
    echo -e "netgear-r8500 snapshots: ${GREEN_COLOR}bash build.sh dev netgear_r8500${RES}"
    echo -e "armsr-armv8 releases: ${GREEN_COLOR}bash build.sh rc2 armv8${RES}"
    echo -e "armsr-armv8 snapshots: ${GREEN_COLOR}bash build.sh dev armv8${RES}\n"
    exit 1
fi

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
[ "$2" = "nanopi-r4s" ] && export platform="rk3399" toolchain_arch="nanopi-r4s"
[ "$2" = "nanopi-r5s" ] && export platform="rk3568" toolchain_arch="nanopi-r5s"
[ "$2" = "x86_64" ] && export platform="x86_64" toolchain_arch="x86_64"
[ "$2" = "netgear_r8500" ] && export platform="bcm53xx" toolchain_arch="bcm53xx"
[ "$2" = "armv8" ] && export platform="armv8" toolchain_arch="armsr-armv8"

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

# bpf
export ENABLE_BPF=$ENABLE_BPF

# print version
echo -e "\r\n${GREEN_COLOR}Building $branch${RES}\r\n"
if [ "$platform" = "x86_64" ]; then
    echo -e "${GREEN_COLOR}Model: x86_64${RES}"
elif [ "$platform" = "armv8" ]; then
    echo -e "${GREEN_COLOR}Model: armsr/armv8${RES}"
    [ "$1" = "rc2" ] && model="armv8"
elif [ "$platform" = "bcm53xx" ]; then
    echo -e "${GREEN_COLOR}Model: netgear_r8500${RES}"
    [ "$LAN" = "10.0.0.1" ] && export LAN="192.168.1.1"
elif [ "$platform" = "rk3568" ]; then
    echo -e "${GREEN_COLOR}Model: nanopi-r5s/r5c${RES}"
    [ "$1" = "rc2" ] && model="nanopi-r5s"
else
    echo -e "${GREEN_COLOR}Model: nanopi-r4s${RES}"
    [ "$1" = "rc2" ] && model="nanopi-r4s"
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

# clean old files
rm -rf openwrt master && mkdir master

# openwrt - releases
[ "$(whoami)" = "runner" ] && group "source code"
git clone --depth=1 https://$github/openwrt/openwrt -b $branch

# openwrt master
git clone https://$github/openwrt/openwrt master/openwrt --depth=1
git clone https://$github/openwrt/packages master/packages --depth=1
git clone https://$github/openwrt/luci master/luci --depth=1
git clone https://$github/openwrt/routing master/routing --depth=1

# openwrt-23.05
[ "$1" = "rc2" ] && git clone https://$github/openwrt/openwrt -b openwrt-23.05 master/openwrt-23.05 --depth=1

# immortalwrt master
git clone https://$github/immortalwrt/packages master/immortalwrt_packages --depth=1
[ "$(whoami)" = "runner" ] && endgroup

if [ -d openwrt ]; then
    cd openwrt
    [ "$1" = "rc2" ] && echo "$CURRENT_DATE" > version.date
    curl -Os https://$mirror/openwrt/patch/key.tar.gz && tar zxf key.tar.gz && rm -f key.tar.gz
else
    echo -e "${RED_COLOR}Failed to download source code${RES}"
    exit 1
fi

# tags
if [ "$1" = "rc2" ]; then
    git describe --abbrev=0 --tags > version.txt
else
    git branch | awk '{print $2}' > version.txt
fi

# feeds mirror
if [ "$1" = "rc2" ]; then
    packages="^$(grep packages feeds.conf.default | awk -F^ '{print $2}')"
    luci="^$(grep luci feeds.conf.default | awk -F^ '{print $2}')"
    routing="^$(grep routing feeds.conf.default | awk -F^ '{print $2}')"
    telephony="^$(grep telephony feeds.conf.default | awk -F^ '{print $2}')"
else
    packages=";$branch"
    luci=";$branch"
    routing=";$branch"
    telephony=";$branch"
fi
cat > feeds.conf <<EOF
src-git packages https://$github/openwrt/packages.git$packages
src-git luci https://$github/openwrt/luci.git$luci
src-git routing https://$github/openwrt/routing.git$routing
src-git telephony https://$github/openwrt/telephony.git$telephony
EOF

# Init feeds
[ "$(whoami)" = "runner" ] && group "feeds update -a"
./scripts/feeds update -a
[ "$(whoami)" = "runner" ] && endgroup

# 删除重复的软件包
rm -rf ../openwrt/feeds/luci/applications/luci-app-smartdns
rm -rf ../openwrt/feeds/packages/net/smartdns

# smartdns
git clone https://github.com/pymumu/openwrt-smartdns.git feeds/packages/net/smartdns
git clone https://github.com/pymumu/luci-app-smartdns.git feeds/luci/applications/luci-app-smartdns
