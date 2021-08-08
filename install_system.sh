#!/bin/bash

# install dialog as it is used heavily in the installer
pacman -Sy --noconfirm dialog


# enable time sync
timedatectl set-ntp true


# make sure the user is cool with erasing their storage device 
read -r -d '' message << EOM
This will install Arch Linux on your machine.

It will COMPLETELY ERASE whatever is currently on your hard drive.

Make a backup, use a different disk or test this out with a virtual machine first if you don't know what you are doing!

Do you want to continue with the installation?
EOM
dialog \
    --title "Are you sure?" \
    --defaultno \
    --yesno \
    "$message" \
    15 60 || exit


# ask user for a hostname
dialog \
    --no-cancel \
    --inputbox \
    "Enter a name for your machine." \
    10 60 2> comp
# TODO: check the hostname is valid and make user try again


# determine if system uses UEFI, otherise it is BIOS
uefi=false
ls /sys/firmware/efi/efivars 1>/dev/null 2>/dev/null && uefi=true


# selecting a storage device to install onto
devices_list=($(lsblk -d | awk '{print "/dev/" $1 " " $4 " on"}' | grep -E 'sd|dh|vd|nvme|mmcblk'))

read -r -d '' message << EOM
Which device would you like to install your new system onto?

UP/DOWN to move cursor. 
SPACE to change selection.
ENTER to confirm selection.

WARNING: Data on the selected device will be DESTROYED!
If you have multiple storage devices and are not 100% sure which is which then it is recommended to disconnect all devices except for the one you will use. 
EOM
dialog \
    --title "Choose you hard drive" \
    --nocancel \
    --radiolist \
    "$message" \
    20 60 4 "${devices_list[@]}" 2> hd

hd=$(cat hd) && rm hd


# sizing the partitions
default_swap_size="8"

read -r -d '' message << EOM
Your system will need three partitions: Boot, Root and Swap.

The boot partition will be 512M.
The swap partition will be configured now.
The root partition will use all remaining space.

Enter below the partition size (in Gb) for the swap partition. A good rule of thumb is to make it equal to the amount of RAM your system has.
If you don't enter anything, it will default to ${default_swap_size}G.
EOM
dialog \
    --no-cancel \
    --inputbox \
    "$message" \
    20 60 2> swap_size

swap_size=$(cat swap_size) && rm swap_size 

# TODO: prompt again if input is invalid instead of selecting the default
[[ $swap_size =~ ^[0-9]+$ ]] || swap_size=$default_swap_size


# erase storage device
dialog \
    --no-cancel \
    --title "Erase Storage Device" \
    --menu "Select the way you'll erase your storage device ($hd)" \
    15 60 4 \
    1 "Use dd (wipe everything)" \
    2 "Use schred (slow & secure)" \
    3 "No need - storage device is empty" 2> hd_eraser_selection

hd_eraser_selection=$(cat hd_eraser_selection); rm hd_eraser_selection

function eraseDisk() {
    case $1 in
        1) dd if=/dev/zero of="$hd" status=progress 2>&1 \
            | dialog \
            --title "Formatting $hd..." \
            --progressbox --stdout 20 60;;
        2) shred -v "$hd" \
            | dialog \
            --title "Formatting $hd..." \
            --progressbox --stdout 20 60;;
        3) ;;
    esac
}

eraseDisk "$hd_eraser_selection"


# create partitions
boot_partition_type=1
[ "$uefi" = true ] && boot_partition_type=4

# g - create non empty GPT partitoin tabl
# n - create new partition
# p - primary partition
# e - exteneded partition
# w - write the table to disk and exit
# empty lines are emulating hitting enter (i.e. default option)

partprobe "$hd"
fdisk "$hd" << EOF
g
n


+512M
t
$boot_partition_type
n


+${swap_size}G
n



w
EOF
partprobe "$hd"


# format partitions
mkswap "${hd}2"
swapon "${hd}2"

mkfs.ext4 "${hd}3"
mount "${hd}3" /mnt

if [ "$uefi" = true ]; then
    mkfs.fat -F32 "${hd}1"
    mkdir -p /mnt/boot/efi
    mount "${hd}1" /mnt/boot/efi
fi


# generate fstab and install arch linux
pacstrap /mnt base base-devel linux linux-firmware
genfstab -U /mnt >> /mnt/etc/fstab


# persist important values 
echo "$eufi" > /mnt/var_uefi"
echo "$hd" > /mnt/var_hd"
mv comp /mnt/comp

# download and run install_chroot script
curl https://raw.githubusercontent.com/carr-james/arch_installer/main/install_chroot.sh > /mnt/install_chroot.sh
arch-chroot /mnt bash install_chroot.sh

# clean up
rm  /mnt/var_uefi
rm  /mnt/var_hd
rm  /mnt/install_chroot.sh

# final message to user
read -r -d '' message << EOM
Congratulations! You've installed Arch Linux!

Do you want to reboot your computer?
EOM
dialog \
    --title "To reboot or not to reboot" \
    --yesno "$message" 20 60

response=$?
case $response in
    0) reboot;;
    1) clear;;
esac
