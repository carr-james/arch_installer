#!/bin/bash

name=$(cat /tmp/user_name)

apps_path="/tmp/apps.csv"
curl https://raw.githubusercontent.com/carr-james/arch_installer/main/apps.csv > $apps_path

dialog \
    --title "Package Installer" \
    --msgbox "Welcome! This installer will help you get all the packages you need to get started fast!" \
    10 60

apps=("essential" "Essentials" on
      "network" "Networking" on
      "tools" "Useful Tools (highly recommended)" on
      "audio" "Audio" on
      "fonts" "Fonts" on 
      "tmux" "Tmux" on
      "notifier" "Notification Tools" on
      "git" "Git" on
      "i3" "i3 Window Manager" on
      "zsh" "The z-shell (zsh)" on
      "urxvt" "URxvt (terminal emulator)" on
      "neovim" "Neovim" on
      "firefox" "Firefox" off)

# TODO: make this nicer rather than hard coded
# groups=($(awk --field-separator ',' '{print $1}' apps.csv | uniq))
# auto_selected_groups=(essentials network tools tmux notifier git i3 zsh neovim urxvt)
# for i in "${!groups[@]}"; do
#    group="${groups[$i]}"
#
#    # if the current group is in the auto_selected_groups array
#    if [[ " ${auto_selected_groups[@]} " =~ " ${group} " ]]; then
#        groups[$i]="${groups[$i]} on"
#    else 
#        groups[$i]="${groups[$i]} off"
#    fi
# done

# TODO: see if we can enable/disable individual packages on a granular level
read -r -d '' message << EOM
Select the groups of applications you would like to install.

UP/DOWN to move cursor. 
SPACE to change selection.
ENTER to confirm selection.
EOM
dialog --checklist "$message" \
    0 0 0 \
    "${apps[@]}" 2> selected_app_groups

selected_app_groups=$(cat selected_app_groups) && rm selected_app_groups


# parse the csv for packages to install
selection="^$(echo $selected_app_groups | sed -e 's/ /,|^/g'),"
lines=$(grep -E "$selection" "$apps_path")
count=$(echo "$lines" | wc -l)
packages=$(echo "$lines" | awk -F, {'print $2'})

# for debugging
echo "$selection" "$lines" "$count" >> "/tmp/packages"


# update the system
pacman -Syu --noconfirm


# installing packages
rm -f /tmp/aur_queue


read -r -d '' message << EOM
The system will now install the selected packages.

This may take a while...
EOM
dialog \
    --title "Let's Go!"
    --msgbox "$message" 13 60

c=0
echo "$packages" | while read -r line; do
    c=$(( "$c" + 1))

    dialog \
        --title "Package Installation" \
        --infobox "Installing program $c out of $count: $line..." \
        8 70

    ((pacman --noconfirm --needed -S "$line" > /tmp/arch_install 2>&1) \
        || echo "$line" >> /tmp/aur_queue) \
        || echo "$line" >> /tmp/arch_install_failed
    
    # app specific post install commands
    if [ "$line" = "zsh" ]; then
        # set zsh as the default shell
        chsh -S "$(which zsh)" "$name"
    fi

    if [ "$line" = "networkmanager" ]; then
        systemctl enable NetworkManager.service
    fi
done


# switch to user and run the user installer
curl https://raw.githubusercontent.com/carr-james/arch_installer/main/install_user.sh > /tmp/install_user.sh;
sudo -u "$name" sh /tmp/install_user.sh
