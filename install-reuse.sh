#!/bin/bash

trap "exit 1" TERM

function abort
{
    kill -s TERM $$
    exit 0
}

function selectMicroSD()
{
    lsblk 1>&2
    local USB_READER=$(lsblk -Sm | grep -i card | grep usb | cut -f1 -d' ')
    if [[ "$USB_READER" == '' ]]; then
        echo "No USB reader found! Exiting..." 1>&2
        abort
    fi

    echo "Using '$USB_READER'... Please confirm: [y/N]" 1>&2
    read ANSWER
    echo "The answer is '$ANSWER'" 1>&2

    if [[ "$ANSWER" != "y" ]]; then
        echo "Exiting now..." 1>&2
        abort
    fi

    if grep -qs "/dev/${USB_READER}1" /proc/mounts; then
        sudo umount "/dev/${USB_READER}1"
    fi

    if grep -qs "/dev/${USB_READER}2" /proc/mounts; then
        sudo umount "/dev/${USB_READER}2"
    fi
    echo $USB_READER
}

function diskcopy()
{
    local IN=$1
    local OUT=$2
    date
    local BEGIN=$(date +%s)
    echo "dd $IN $OUT"
    sudo dcfldd bs=4M if="$IN" of="/dev/$OUT"
    local END=$(date +%s)
    local ELAPSED=$((END - BEGIN))
    local MIN=$((ELAPSED / 60))
    local SEC=$((ELAPSED % 60))
    echo "Elapsed $MIN min $SEC sec"
}

function expandFS()
{
    local DEV=$1
    echo "d
2
n
p
2
131072

w" | sudo fdisk /dev/$DEV
    sudo e2fsck -f /dev/${DEV}2
    sudo resize2fs /dev/${DEV}2
}

function mountFS()
{
    local DEV=$1
    local PART=$2
    local TMP=~/tmp/$$-$PART
    mkdir -p "$TMP"    
    local DISK="/dev/${DEV}$PART"
    echo "Mounting '$DISK' into '$TMP'" 1>&2
    sudo mount "$DISK" "$TMP"
    echo $TMP
}

function umountFS()
{
    local MOUNTED=$1
    sudo umount "$MOUNTED"
    rm -r "$MOUNTED"
    echo "Unmounted and removed '$MOUNTED'" 1>&2
    sync
}

function dynamic_ip()
{
    local GW=$1
    local MASK=$2
    local DEST=$3
    local CFG="$DEST/etc/network/interfaces"
    sudo cp -v $CFG "$CFG.bak"
    echo "netmask $MASK" | sudo tee -a $CFG
    echo "gateway $GW" | sudo tee -a $CFG
}

#http://sizious.com/2015/08/28/setting-a-static-ip-on-raspberry-pi-on-raspbian-20150505/
function static_ip()
{
    local IP=$1
    local ROUTER=$2
    local DEST=$3
    local CONF="$DEST/etc/dhcpcd.conf"
    sudo cp -v $CONF "$CONF.orig"
    echo 'interface wlan0' | sudo tee -a $CONF
    echo "  static ip_address=$IP/24" | sudo tee -a $CONF
    echo "  static routers=$ROUTER" | sudo tee -a $CONF
    echo "  static domain_name_servers=8.8.8.8" | sudo tee -a $CONF
}

function generic_setup()
{
    local DEST=$1
    rm -fr $DEST/home/pi/.ssh
    mkdir $DEST/home/pi/.ssh
    cat ~/.ssh/id_rsa.pub >> $DEST/home/pi/.ssh/authorized_keys

    sudo cp -v $DEST/usr/share/zoneinfo/America/New_York $DEST/etc/localtime

    local RPI="$DEST/home/pi/git/rpi"
    rm -fr $RPI
    mkdir -p $RPI
    git clone https://github.com/petrum/rpi.git $RPI
    
    sudo cp -v $DEST/etc/wpa_supplicant/wpa_supplicant.conf $DEST/etc/wpa_supplicant/wpa_supplicant.conf.bak
    sudo cp -v ~/rpi-private/wpa_supplicant.conf $DEST/etc/wpa_supplicant
}

function sethostname()
{
    local PREFIX=$1
    local DEST=$2
    local BUILD=~/.rpi-counter.txt
    if [[ ! -f $BUILD ]]; then
        echo 0 > $BUILD
    fi
    local COUNTER=$(cat $BUILD)
    #local NAME=$(date +"$PREFIX-%Y%m%d-%H%M%S")
    local NAME="$PREFIX-$COUNTER"
    sudo sed -i "s/raspberrypi/$NAME/g" $DEST/etc/hosts
    sudo sed -i "s/raspberrypi/$NAME/g" $DEST/etc/hostname
    ((COUNTER++))
    echo $COUNTER > $BUILD
}

function enable_spi()
{
    local DEST=$1
    sudo sed -i 's|#dtparam=spi=on|dtparam=spi=on|g' $DEST/config.txt
}

function get_MAX7219array()
{
    local DEST=$1
    local NUM=$2
    rm -fr $DEST/home/pi/MAX7219array
    git clone https://github.com/JonA1961/MAX7219array.git $DEST/home/pi/MAX7219array
    sed -i "s/NUM_MATRICES = 8/NUM_MATRICES = $NUM/g" $DEST/home/pi/MAX7219array/MAX7219array.py
}
