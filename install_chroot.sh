#!/bin/bash

# e - script stops on error
# u - error if undefined variable
# o pipefail - script fails if command piped fails
set -euxo pipefail

# load variables from file
uefi=$(cat /var_uefi)
hd=$(cat /var_hd)

# rename system
cat /comp > /etc/hostname && rm /comp

# install GRUB
pacman --noconfirm -S dialog
pacman --noconfirm -S grub

if [ "$uefi" = true ]; then
    pacman -S --noconfirm efibootmgr
    grub-install \
        --target=x86_64-efi \
        --bootloader-id=GRUB \
        --efi-directory=/boot/efi
else
    grub-install "$hd"
fi

grub-mkconfig -o /boot/grub/grub.cfg


# set hardware clock from system clock
hwclock --systohc
# TODO: add dialog to select from available timezones with `timedatectl list-timezones`
timedatectl set-timezone "Europe/London"


# configure locale
# TODO: add dialog to selct from available locales with `cat /etc/locale.gen`
# TODO: use sed to uncomment instead of appending the selected locale
echo "en_US.UTF-8.UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG-en_US.UTF-8" > /etc/locale.conf


# root password and user creation
function configure_user() {
    local name=${1:-none}

    if [ "$name" == none ]; then
        dialog --nocancel --inputbox "Enter your user name." 10 60 2> name
        name=$(cat name) && rm name
    fi

    dialog --nocancel --passwordbox "Enter your password." 10 60 2> pass1
    dialog --nocancel --passwordbox "Confirm your password." 10 60 2> pass2

    while [ "$(cat pass1)" != "$(cat pass2)" ]
    do
        dialog --nocancel --passwordbox "The passwords do not match.\n\nEnter your password again." 10 60 2> pass1
        dialog --nocancel --passwordbox "Confirm your password." 10 60 2> pass2
    done

    pass=$(cat pass1)
    rm pass1 pass2

    # create user if it doesn't exist already
    if [[ ! "$(id -u "$name" 2> /dev/null)" ]]; then
        useradd -m -g wheel -s /bin/bash "$name"
    fi

    # set user's password
    echo "$name:$pass" | chpasswd
    echo "$name" > /tmp/user_name
}

dialog \
    --title "Root password" \
    --msgbox "Let's set a password for the root user." \
    10 60
configure_user root

dialog \
    --title "Create user" \
    --msgbox "Let's create a user." \
    10 60
configure_user


# ask if user wants to install app and dotfiles
dialog \
    --title "Continue installation" \
    --yesno \
    "Arch Linx is freshly installed! Would you like to install app and dotfiles." \
    10 60 \
    && curl https://raw.githubusercontent.com/carr-james/arch_installer/main/install_apps.sh > /tmp/install_apps.sh \
    && bash /tmp/install_apps.sh
