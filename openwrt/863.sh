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


# Compile
if [ "$BUILD_TOOLCHAIN" = "y" ]; then
    echo -e "\r\n${GREEN_COLOR}Building Toolchain ...${RES}\r\n"
    make -j$(nproc) toolchain/compile || make -j$(nproc) toolchain/compile V=s || exit 1
    mkdir -p toolchain-cache
    [ "$USE_GLIBC" = "y" ] && LIBC=glibc || LIBC=musl
    if [ "$USE_GCC13" = "y" ]; then
        tar -zcf toolchain-cache/toolchain_"$LIBC"_"$toolchain_arch"_13.tar.gz ./{build_dir,dl,staging_dir,tmp} && echo -e "${GREEN_COLOR} Build success! ${RES}"
    elif [ "$USE_GCC14" = "y" ]; then
        tar -zcf toolchain-cache/toolchain_"$LIBC"_"$toolchain_arch"_14.tar.gz ./{build_dir,dl,staging_dir,tmp} && echo -e "${GREEN_COLOR} Build success! ${RES}"
    elif [ "$USE_GCC15" = "y" ]; then
        tar -zcf toolchain-cache/toolchain_"$LIBC"_"$toolchain_arch"_15.tar.gz ./{build_dir,dl,staging_dir,tmp} && echo -e "${GREEN_COLOR} Build success! ${RES}"
    else
        tar -zcf toolchain-cache/toolchain_"$LIBC"_"$toolchain_arch"_11.tar.gz ./{build_dir,dl,staging_dir,tmp} && echo -e "${GREEN_COLOR} Build success! ${RES}"
    fi
    exit 0
else
    echo -e "\r\n${GREEN_COLOR}Building OpenWrt ...${RES}\r\n"
    sed -i "/BUILD_DATE/d" package/base-files/files/usr/lib/os-release
    sed -i "/BUILD_ID/aBUILD_DATE=\"$CURRENT_DATE\"" package/base-files/files/usr/lib/os-release
    make -j$(nproc) V=w IGNORE_ERRORS="n m"
fi

# Compile time
endtime=`date +'%Y-%m-%d %H:%M:%S'`
start_seconds=$(date --date="$starttime" +%s);
end_seconds=$(date --date="$endtime" +%s);
SEC=$((end_seconds-start_seconds));

if [ "$platform" = "x86_64" ]; then
    if [ -f bin/targets/x86/64*/*-squashfs-combined-efi.img.gz ]; then
        echo -e "${GREEN_COLOR} Build success! ${RES}"
        echo -e " Build time: $(( SEC / 3600 ))h,$(( (SEC % 3600) / 60 ))m,$(( (SEC % 3600) % 60 ))s"
        if [ "$ALL_KMODS" = y ]; then
            cp -a bin/targets/x86/*/packages $kmodpkg_name
            rm -f $kmodpkg_name/Packages*
            # driver firmware
            cp -a bin/packages/x86_64/base/*firmware*.ipk $kmodpkg_name/
            bash kmod-sign $kmodpkg_name
            tar zcf x86_64-$kmodpkg_name.tar.gz $kmodpkg_name
            rm -rf $kmodpkg_name
        fi
        # OTA json
        if [ "$1" = "rc2" ]; then
            mkdir -p ota
            if [ "$MINIMAL_BUILD" = "y" ]; then
                BUILD_TYPE=minimal
            else
                BUILD_TYPE=releases
            fi
            VERSION=$(sed 's/v//g' version.txt)
            SHA256=$(sha256sum bin/targets/x86/64/*-generic-squashfs-combined-efi.img.gz | awk '{print $1}')
            cat > ota/fw.json <<EOF
{
  "x86_64": [
    {
      "build_date": "$CURRENT_DATE",
      "sha256sum": "$SHA256",
      "url": "https://x86.cooluc.com/$BUILD_TYPE/openwrt-23.05/v$VERSION/openwrt-$VERSION-x86-64-generic-squashfs-combined-efi.img.gz"
    }
  ]
}
EOF
        fi
        # Backup download cache
        if [ "$isCN" = "CN" ] && [ "$1" = "rc2" ]; then
            rm -rf dl/geo* dl/go-mod-cache
            tar cf ../dl.gz dl
        fi
        exit 0
    else
        echo -e "\n${RED_COLOR} Build error... ${RES}"
        echo -e " Build time: $(( SEC / 3600 ))h,$(( (SEC % 3600) / 60 ))m,$(( (SEC % 3600) % 60 ))s"
        echo
        exit 1
    fi
elif [ "$platform" = "armv8" ]; then
    if [ -f bin/targets/armsr/armv8*/*-squashfs-combined.img.gz ]; then
        echo -e "${GREEN_COLOR} Build success! ${RES}"
        echo -e " Build time: $(( SEC / 3600 ))h,$(( (SEC % 3600) / 60 ))m,$(( (SEC % 3600) % 60 ))s"
        if [ "$ALL_KMODS" = y ]; then
            cp -a bin/targets/armsr/armv8*/packages $kmodpkg_name
            rm -f $kmodpkg_name/Packages*
            # driver firmware
            cp -a bin/packages/aarch64_generic/base/*firmware*.ipk $kmodpkg_name/
            bash kmod-sign $kmodpkg_name
            tar zcf armv8-$kmodpkg_name.tar.gz $kmodpkg_name
            rm -rf $kmodpkg_name
        fi
        # OTA json
        if [ "$1" = "rc2" ]; then
            mkdir -p ota
            VERSION=$(sed 's/v//g' version.txt)
            SHA256=$(sha256sum bin/targets/armsr/armv8*/*-squashfs-combined.img.gz | awk '{print $1}')
            cat > ota/fw.json <<EOF
{
  "armsr,armv8": [
    {
      "build_date": "$CURRENT_DATE",
      "sha256sum": "$SHA256",
      "url": "https://github.com/sbwml/builder/releases/download/v$VERSION/openwrt-$VERSION-armsr-armv8-generic-squashfs-combined.img.gz"
    }
  ]
}
EOF
        fi
        exit 0
    else
        echo -e "\n${RED_COLOR} Build error... ${RES}"
        echo -e " Build time: $(( SEC / 3600 ))h,$(( (SEC % 3600) / 60 ))m,$(( (SEC % 3600) % 60 ))s"
        echo
        exit 1
    fi
elif [ "$platform" = "bcm53xx" ]; then
    if [ -f bin/targets/bcm53xx/generic/*netgear_r8500-squashfs.chk ]; then
        echo -e "${GREEN_COLOR} Build success! ${RES}"
        echo -e " Build time: $(( SEC / 3600 ))h,$(( (SEC % 3600) / 60 ))m,$(( (SEC % 3600) % 60 ))s"
        if [ "$ALL_KMODS" = y ]; then
            cp -a bin/targets/bcm53xx/generic/packages $kmodpkg_name
            rm -f $kmodpkg_name/Packages*
            # driver firmware
            cp -a bin/packages/arm_cortex-a9/base/*firmware*.ipk $kmodpkg_name/
            bash kmod-sign $kmodpkg_name
            tar zcf bcm53xx-$kmodpkg_name.tar.gz $kmodpkg_name
            rm -rf $kmodpkg_name
        fi
        # OTA json
        if [ "$1" = "rc2" ]; then
            mkdir -p ota
            if [ "$MINIMAL_BUILD" = "y" ]; then
                BUILD_TYPE=minimal
            else
                BUILD_TYPE=releases
            fi
            VERSION=$(sed 's/v//g' version.txt)
            SHA256=$(sha256sum bin/targets/bcm53xx/generic/*-bcm53xx-generic-netgear_r8500-squashfs.chk | awk '{print $1}')
            cat > ota/fw.json <<EOF
{
  "netgear,r8500": [
    {
      "build_date": "$CURRENT_DATE",
      "sha256sum": "$SHA256",
      "url": "https://r8500.cooluc.com/$BUILD_TYPE/openwrt-23.05/v$VERSION/openwrt-$VERSION-bcm53xx-generic-netgear_r8500-squashfs.chk"
    }
  ]
}
EOF
        fi
        exit 0
    else
        echo -e "\n${RED_COLOR} Build error... ${RES}"
        echo -e " Build time: $(( SEC / 3600 ))h,$(( (SEC % 3600) / 60 ))m,$(( (SEC % 3600) % 60 ))s"
        echo
        exit 1
    fi
else
    if [ -f bin/targets/rockchip/armv8*/*-r5s-ext4-sysupgrade.img.gz ] || [ -f bin/targets/rockchip/armv8*/*-r5c-ext4-sysupgrade.img.gz ] || [ -f bin/targets/rockchip/armv8*/*-r4s-ext4-sysupgrade.img.gz ]; then
        if [ "$ALL_KMODS" = y ]; then
            cp -a bin/targets/rockchip/armv8*/packages $kmodpkg_name
            rm -f $kmodpkg_name/Packages*
            # driver firmware
            cp -a bin/packages/aarch64_generic/base/*firmware*.ipk $kmodpkg_name/
            bash kmod-sign $kmodpkg_name
            tar zcf aarch64-$kmodpkg_name.tar.gz $kmodpkg_name
            rm -rf $kmodpkg_name
        fi
        echo -e "${GREEN_COLOR} Build success! ${RES}"
        echo -e " Build time: ${GREEN_COLOR}$(( SEC / 3600 ))h,$(( (SEC % 3600) / 60 ))m,$(( (SEC % 3600) % 60 ))s${RES}"
        # OTA json
        if [ "$1" = "rc2" ]; then
            mkdir -p ota
            if [ "$MINIMAL_BUILD" = "y" ]; then
                BUILD_TYPE=minimal
            else
                BUILD_TYPE=releases
            fi
            VERSION=$(sed 's/v//g' version.txt)
            if [ "$model" = "nanopi-r4s" ]; then
                SHA256=$(sha256sum bin/targets/rockchip/armv8*/*-squashfs-sysupgrade.img.gz | awk '{print $1}')
                cat > ota/fw.json <<EOF
{
  "friendlyarm,nanopi-r4s": [
    {
      "build_date": "$CURRENT_DATE",
      "sha256sum": "$SHA256",
      "url": "https://r4s.cooluc.com/$BUILD_TYPE/openwrt-23.05/v$VERSION/openwrt-$VERSION-rockchip-armv8-friendlyarm_nanopi-r4s-squashfs-sysupgrade.img.gz"
    }
  ]
}
EOF
            elif [ "$model" = "nanopi-r5s" ]; then
                SHA256_R5C=$(sha256sum bin/targets/rockchip/armv8*/*-r5c-squashfs-sysupgrade.img.gz | awk '{print $1}')
                SHA256_R5S=$(sha256sum bin/targets/rockchip/armv8*/*-r5s-squashfs-sysupgrade.img.gz | awk '{print $1}')
                cat > ota/fw.json <<EOF
{
  "friendlyarm,nanopi-r5c": [
    {
      "build_date": "$CURRENT_DATE",
      "sha256sum": "$SHA256_R5C",
      "url": "https://r5s.cooluc.com/$BUILD_TYPE/openwrt-23.05/v$VERSION/openwrt-$VERSION-rockchip-armv8-friendlyarm_nanopi-r5c-squashfs-sysupgrade.img.gz"
    }
  ],
  "friendlyarm,nanopi-r5s": [
    {
      "build_date": "$CURRENT_DATE",
      "sha256sum": "$SHA256_R5S",
      "url": "https://r5s.cooluc.com/$BUILD_TYPE/openwrt-23.05/v$VERSION/openwrt-$VERSION-rockchip-armv8-friendlyarm_nanopi-r5s-squashfs-sysupgrade.img.gz"
    }
  ]
}
EOF
            fi
        fi
        # Backup download cache
        if [ "$isCN" = "CN" ] && [ "$version" = "rc2" ]; then
            rm -rf dl/geo* dl/go-mod-cache
            tar -cf ../dl.gz dl
        fi
        exit 0
    else
        echo -e "\n${RED_COLOR} Build error... ${RES}"
        echo -e " Build time: ${RED_COLOR}$(( SEC / 3600 ))h,$(( (SEC % 3600) / 60 ))m,$(( (SEC % 3600) % 60 ))s${RES}"
        echo
        exit 1
    fi
fi