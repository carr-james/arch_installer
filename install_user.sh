#!/bin/bash

# e - script stops on error
# u - error if undefined variable
# o pipefail - script fails if command piped fails
set -euxo pipefail

mkdir -p "/home/$(whoami)/Documents"
mkdir -p "/home/$(whoami)/Downloads"


# This is the manual way to install packages from AUR
aur_manual_install() {
    curl -O "https://aur.archlinux.org/cgit/aur.git/snapshot/$1.tar.gz" \
        && tar -xvf "$1.tar.gz" \
        && cd "$1" \
        && makepkg --nocofirm -si \
        && cd - \
        && rm -rf "$1" "$1.tar.gz"
}


# Checks if a package can be found in the official repositories.
# If it isn't found then we try to install with yay, otherwise we
# try to manually install it.
aur_install() {
    qm=$(pacman -Qm | awk '{print $1}')
    for arg in "$@"; do
        if [[ "$qm" != *"$arg"* ]]; then
            yay --noconfirm -S "$arg" &>> /tmp/aur_install \
                || aur_manual_install "$arg" &>> /tmp/aur_install
        fi
    done
}


# install yay
cd /tmp
dialog --infobox "Installing \"Yay\", an AUR helper..." 10 60
aur_install yay


# install packages from aur_queue
count=$(wc -l < /tmp/aur_queue)
c=0
cat /tmp/aur_queue | while read -r line; do
    c=$(( "$c" + 1 ))

    dialog \
        --title "AUR Package Installation" \
        --infobox "Installing program $c out of $count: $line..." \
        8 70
    aur_install "$line"
done


# install the dotfiles
DOTFILES="/home/$(whoami)/.dotfiles"
if [ ! -d "$DOTFILES" ]; then
    git clone https://github.com/carr-james/dotfiles.git "$DOTFILES" >/dev/null
fi

source "$DOTFILES/zsh/.zshenv"
cd "$DOTFILES" && ./install.zsh
