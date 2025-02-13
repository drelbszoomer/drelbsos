# vim: set ft=make :

# Install System Flatpaks (Support for Rebasing)
_install-system-flatpaks:
    #!/usr/bin/bash
    IMAGE_INFO="/usr/share/ublue-os/image-info.json"
    BASE_IMAGE_NAME=$(jq -r '."base-image-name"' < $IMAGE_INFO)
    if [[ ${BASE_IMAGE_NAME} == 'silverblue' ]]; then
        FLATPAKS="gnome_flatpaks/flatpaks"
    fi
    FLATPAK_LIST="$(curl https://raw.githubusercontent.com/ublue-os/bazzite/main/installer/${FLATPAKS} | tr '\n' ' ')"
    flatpak --system -y install --reinstall --or-update ${FLATPAK_LIST}

# Configure grub bootmenu visibility. pass action 'help' for more info.
configure-grub ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    # Function to display usage/help with some color
    print_help() {
      echo -e "Usage: ujust configure-grub <option>"
      echo
      echo -e "Where <option> can be:"
      echo -e "  ${bold}${cyan}hide${normal} = GRUB is hidden after a successful boot, even for dual-boot setups."
      echo -e "  ${bold}${yellow}unhide${normal} = GRUB is hidden after a successful boot, but it will show if dual-booting."
      echo -e "  ${bold}${green}show${normal} = GRUB always shows on boot."
      echo
      echo "If <option> is omitted, you will be prompted to choose interactively."
    }
    # Function to get the current GRUB menu_auto_hide setting and explain it
    get_current_setting() {
      local CURRENT_SETTING
      CURRENT_SETTING=$(sudo grub2-editenv - list | grep menu_auto_hide | cut -d= -f2)
      if [ -z "$CURRENT_SETTING" ]; then
        echo "Current GRUB menu_auto_hide setting: ${bold}${red}Not Set (default to 0)${normal}"
        echo "Explanation:"
        echo "  - ${bold}0${normal}: GRUB always shows on boot."
        return 0
      else
        case "$CURRENT_SETTING" in
          0)
            echo "Current GRUB menu_auto_hide setting: ${bold}${green}0 (Always Show)${normal}"
            echo "Explanation:"
            echo "  - ${bold}0${normal}: GRUB always shows on boot."
            ;;
          1)
            echo "Current GRUB menu_auto_hide setting: ${bold}${yellow}1 (Hide After Successful Boot)${normal}"
            echo "Explanation:"
            echo "  - ${bold}1${normal}: GRUB is hidden after a successful boot, but it will show if dual-booting."
            ;;
          2)
            echo "Current GRUB menu_auto_hide setting: ${bold}${cyan}2 (Always Hide)${normal}"
            echo "Explanation:"
            echo "  - ${bold}2${normal}: GRUB is hidden after a successful boot, even for dual-boot setups."
            ;;
          *)
            echo "Current GRUB menu_auto_hide setting: ${bold}${red}Unknown${normal}"
            echo "Explanation:"
            echo "  - This setting is unrecognized. Reset it to 0, 1, or 2."
            ;;
        esac
      fi
    }
    # Interactive menu for choosing the new behavior
    interactive_menu() {
      local options=(
        "Always Hide Grub (menu_auto_hide=2)"
        "Hide After Successful Boot (menu_auto_hide=1)"
        "Always Show Grub (menu_auto_hide=0)"
        "Exit without changes"
      )
      local choice
      choice=$(ugum choose "${options[@]}")
      echo "$choice"
    }
    # Function to apply the selected setting
    apply_setting() {
      local selected_option="$1"
      # Support the interactive strings as well as short commands
      case "$(echo "$selected_option" | tr '[:upper:]' '[:lower:]')" in
        *"(menu_auto_hide=2)"*|hide)
          sudo grub2-editenv - set menu_auto_hide=2
          echo "GRUB menu is now set to ${bold}${cyan}Always Hide${normal}."
          ;;
        *"(menu_auto_hide=1)"*|unhide)
          sudo grub2-editenv - set menu_auto_hide=1
          echo "GRUB menu is now set to ${bold}${yellow}Hide After Successful Boot${normal}."
          ;;
        *"(menu_auto_hide=0)"*|show)
          sudo grub2-editenv - set menu_auto_hide=0
          echo "GRUB menu is now set to ${bold}${green}Always Show${normal}."
          ;;
        *"exit without changes"*|exit)
          echo "${bold}No changes were made. Exiting...${normal}"
          ;;
        help)
          print_help
          ;;
        *)
          echo "${bold}${red}Invalid option selected. No changes were made.${normal}"
          ;;
      esac
    }
    OPTION="{{ ACTION }}"   # from “configure-grub ACTION=...”
    if [ "$OPTION" == "help" ]; then
      print_help
      exit 0
    fi
    get_current_setting
    echo
    # If no ACTION was passed, go interactive
    if [ -z "$OPTION" ]; then
      NEW_SETTING=$(interactive_menu)
      if [ -n "$NEW_SETTING" ]; then
        apply_setting "$NEW_SETTING"
      else
        echo "${bold}No changes were made.${normal}"
      fi
    else
      apply_setting "$OPTION"
    fi

# Add user to "input" group required by certain controller drivers
add-user-to-input-group:
    #!/usr/bin/bash
    if ! grep -q "input" /etc/group; then
      sudo bash -c 'grep "input" /lib/group >> /etc/group'
    fi
    sudo usermod -a -G input $USER

# Enable support for DisplayLink
enable-displaylink:
    systemctl enable --now displaylink.service

# Enable support for Tailscale
enable-tailscale:
    systemctl enable --now tailscaled.service

# Configure watchdog (default: enabled, recovers the system in the event of a malfunction)
configure-watchdog ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    WATCHDOG_STATE="$(rpm-ostree kargs)"
    CPU_MODEL=$(lscpu --json | jq -r '."lscpu"[7]."data"')
    OPTION={{ ACTION }}
    if [[ "$WATCHDOG_STATE" =~ (nowatchdog|modprobe\.blacklist=(iTCO_wdt|sp5100_tco)) ]]; then
        WATCHDOG_STATE="${red}${b}Disabled${n}"
    else
        WATCHDOG_STATE="${green}${b}Enabled${n}"
    fi
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust configure-watchdog <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'enable' to select Enable Watchdog"
      echo "  Use 'disable' to select Disable Watchdog"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}Watchdog configuration${normal}"
      echo "Having the watchdog enabled will let it recover the system in the event of a malfunction, however"
      echo "disabling the watchdog can give a potential performance improvement due to fewer interrupts"
      echo "Watchdog is $WATCHDOG_STATE"
      OPTION=$(Choose "Enable Watchdog" "Disable Watchdog")
    fi
    if [[ "${OPTION,,}" =~ ^enable ]]; then
      WATCHDOG_KARGS="--delete-if-present=nowatchdog"
      if [[ "$CPU_MODEL" =~ "Intel" ]]; then
        WATCHDOG_KARGS="$WATCHDOG_KARGS --delete-if-present=modprobe.blacklist=iTCO_wdt"
      elif [[ "$CPU_MODEL" =~ "AMD" ]]; then
        WATCHDOG_KARGS="$WATCHDOG_KARGS --delete-if-present=modprobe.blacklist=sp5100_tco"
      fi
      rpm-ostree kargs $WATCHDOG_KARGS
    elif [[ "${OPTION,,}" =~ ^disable ]]; then
      WATCHDOG_KARGS="--append-if-missing=nowatchdog"
      if [[ "$CPU_MODEL" =~ "Intel" ]]; then
        WATCHDOG_KARGS="$WATCHDOG_KARGS --append-if-missing=modprobe.blacklist=iTCO_wdt"
      elif [[ "$CPU_MODEL" =~ "AMD" ]]; then
        WATCHDOG_KARGS="$WATCHDOG_KARGS --append-if-missing=modprobe.blacklist=sp5100_tco"
      fi
      rpm-ostree kargs $WATCHDOG_KARGS
    fi

# Install and configure Decky Loader (https://github.com/SteamDeckHomebrew/decky-loader) and plugins for alternative handhelds
setup-decky ACTION="install":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    DECKY_STATE="${b}${red}Not Installed${n}"
    if [[ -d $HOME/homebrew/plugins ]]; then
      DECKY_STATE="${b}${green}Installed${n}"
    fi
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust setup-decky <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'install' to select Install Decky"
      echo "  Use 'prerelease' to select Install Decky Prerelease"
      exit 0
    fi
    if [[ "${OPTION,,}" =~ install ]]; then
      export HOME=$(getent passwd ${SUDO_USER:-$USER} | cut -d: -f6)
      if [ ! -L "/home/deck" ] && [ ! -e "/home/deck" ]  && [ "$HOME" != "/home/deck" ]; then
        echo "Making a /home/deck symlink to fix plugins that do not use environment variables."
        sudo ln -sf "$HOME" /home/deck
      fi
      curl -L https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_release.sh | sh
      sudo chcon -R -t bin_t $HOME/homebrew/services/PluginLoader
    fi
    if [[ "${OPTION,,}" =~ prerelease ]]; then
      export HOME=$(getent passwd ${SUDO_USER:-$USER} | cut -d: -f6)
      if [ ! -L "/home/deck" ] && [ ! -e "/home/deck" ]  && [ "$HOME" != "/home/deck" ]; then
        echo "Making a /home/deck symlink to fix plugins that do not use environment variables."
        sudo ln -sf "$HOME" /home/deck
      fi
      curl -L https://github.com/SteamDeckHomebrew/decky-installer/releases/latest/download/install_prerelease.sh | sh
      sudo chcon -R -t bin_t $HOME/homebrew/services/PluginLoader
    fi

# Ptyxis terminal transparency
ptyxis-transparency opacity="0.95":
    #!/usr/bin/bash
    set -euxo pipefail
    if [[ -n "$(echo "{{ opacity }}" | grep -v '^[.0-9]*$')" ]]; then
      printf "Value must be numeric: %s.\n" "{{ opacity }}"
    elif [[ $(echo "0<{{ opacity }} && 1>={{ opacity }}" | bc -q) -eq 1 ]]; then
      raw="$(gsettings get org.gnome.Ptyxis profile-uuids)"
      uuids="$(sed -En 's|[^0-9a-z]*||g; s|([0-9a-z]{32})|\1\n|gp' <<<${raw})"
      for i in ${uuids}; do
        location="org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/${i}/"
        gsettings set "${location}" opacity "{{ opacity }}"; done
      printf "Ptyxis opacity is now %s.\n" "{{ opacity }}"
    else
      printf "Value must be between 0 and 1: %s.\n" "{{ opacity }}"
    fi

# Configure snapshotting for /var/home
configure-snapshots ACTION="":
    #!/usr/bin/bash
    source /usr/lib/ujust/ujust.sh
    OPTION={{ ACTION }}
    if [ "$OPTION" == "help" ]; then
      echo "Usage: ujust configure-snapshots <option>"
      echo "  <option>: Specify the quick option to skip the prompt"
      echo "  Use 'enable' enable snapshotting of /var/home"
      echo "  Use 'disable' disable snapshotting of /var/home"
      echo "  Use 'wipe' disable snapshotting and remove all automatic snapshots of /var/home"
      exit 0
    elif [ "$OPTION" == "" ]; then
      echo "${bold}Snapper setup and configuration${normal}"
      OPTION=$(Choose "Enable Snapper" "Disable Snapper" "Wipe Snapper config and automatic snapshots")
    fi
    if [[ "${OPTION,,}" =~ ^enable ]]; then
      /usr/libexec/bazzite-snapper-config enable
    elif [[ "${OPTION,,}" =~ ^disable ]]; then
      /usr/libexec/bazzite-snapper-config disable
    elif [[ "${OPTION,,}" =~ ^wipe ]]; then
      /usr/libexec/bazzite-snapper-config wipe
    fi

# Run a one minute system benchmark
benchmark:
    echo 'Running a 1 minute benchmark ...'
    cd /tmp && stress-ng --matrix 0 -t 1m --times

# toggles password prompt feedback in terminal, where sudo password prompts will display asterisks when enabled
toggle-password-feedback ACTION="":
    #!/usr/bin/bash
    PWFEEDBACK_FILE="/etc/sudoers.d/enable-pwfeedback"
    OPTION={{ ACTION }}
    if [ "$OPTION" = "on" ]; then
      echo 'Defaults pwfeedback' | sudo tee $PWFEEDBACK_FILE
      echo "enabled, restart terminal to see changes"
    elif [ "$OPTION" = "off" ]; then
      sudo rm -f $PWFEEDBACK_FILE
      echo "disabled pwfeedback. restart your terminal to see changes"
    elif sudo test -f $PWFEEDBACK_FILE; then
      sudo rm -f $PWFEEDBACK_FILE
      echo "disabled pwfeedback. restart your terminal to see changes"
    else
      echo 'Defaults pwfeedback' | sudo tee $PWFEEDBACK_FILE
      echo "enabled, restart terminal to see changes"
    fi

# Install Bazzite Buddy plugin to easily access changelogs in game mode!
get-decky-bazzite-buddy:
    #!/bin/bash
    PLUGIN_URL="https://github.com/xXJSONDeruloXx/bazzite-buddy/releases/download/stable/bazzite-buddy.zip"
    PLUGIN_NAME="bazzite-buddy"
    PLUGIN_DIR="$HOME/homebrew/plugins"
    if [ ! -d "$PLUGIN_DIR" ]; then
      echo "Creating plugins directory with sudo..."
      sudo mkdir -p "$PLUGIN_DIR"
    fi
    # Change to the plugin directory
    cd "$PLUGIN_DIR" || { echo "Failed to navigate to plugins directory"; exit 1; }
    # Remove any existing plugin folder
    if [ -d "$PLUGIN_NAME" ]; then
      echo "Removing existing $PLUGIN_NAME directory with sudo..."
      sudo rm -rf "$PLUGIN_NAME"
    fi
    # Download the zip file
    echo "Downloading $PLUGIN_NAME from $PLUGIN_URL..."
    sudo curl -L -o "${PLUGIN_NAME}.zip" "$PLUGIN_URL"
    if [ $? -ne 0 ]; then
      echo "Download failed!"
      exit 1
    fi
    echo "Extracting $PLUGIN_NAME..."
    sudo unzip -o "${PLUGIN_NAME}.zip" -d .
    if [ $? -ne 0 ]; then
      echo "Extraction failed!"
      exit 1
    fi
    # Move the extracted files to the correct location if nested
    if [ -d "./${PLUGIN_NAME}/${PLUGIN_NAME}" ]; then
      echo "Fixing folder structure..."
      sudo mv ./${PLUGIN_NAME}/${PLUGIN_NAME}/* ./${PLUGIN_NAME}/
      sudo rm -rf ./${PLUGIN_NAME}/${PLUGIN_NAME}
    fi
    # Clean up the downloaded ZIP file
    echo "Cleaning up..."
    sudo rm -f "${PLUGIN_NAME}.zip"
    # Confirm installation
    echo "$PLUGIN_NAME has been installed successfully to $PLUGIN_DIR!"
    # Prompt user to restart Decky Loader
    echo "Please restart Decky Loader to activate the plugin."

# get logs for this boot and last boot, cleanly output in terminal as pastebin links, to simplify troubleshooting and issue reporting.
get-logs:
    #!/bin/bash
    set -euo pipefail
    source /usr/lib/ujust/ujust.sh
    # Get logs for this boot
    this_boot_logs=$(journalctl -b | fpaste 2>/dev/null)
    echo -e "${bold}Logs This Boot:${normal} $this_boot_logs"
    echo " "
    # Get logs for last boot
    last_boot_logs=$(journalctl -b -1 | fpaste 2>/dev/null)
    echo -e "${bold}Logs Last Boot:${normal} $last_boot_logs"
    echo " "
