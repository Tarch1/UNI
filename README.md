# Universal-Installation-Script

sudo -E hw-probe -all -upload

**Wifi-setup**

ip a

rfkill unblock all

ip link set <<interface>> up

connmanctl

	scan wifi

	services

	agent on

	connect wifi_***_psk

	quit

git clone https://github.com/Tarch1/Arch-tix

cd Arch-tix/

**Adjust packages at the end of base_install**

bash base_install

First setup use nmtui to connect on your network then personalize with

bash full_setup

Reboot and Enjoy!

Try to use https://gitea.arsenm.dev/Arsen6331/lure as AUR helper

DISABLING INTEL TURBO BOOST - https://wiki.archlinux.org/title/CPU_frequency_scaling#Disabling_Turbo_Boost

    echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo

# GNOME SETUP

In case of error with gdm use Ctrl+Alt+F2

    Increase volume steps by: (less value = more steps)

        gsettings set org.gnome.settings-daemon.plugins.media-keys volume-step 1

   Remove shortcut that coz with super+($number) with: 
     
        for i in {1..9}; do gsettings set "org.gnome.shell.keybindings" "switch-to-application-$i" "[]"; done

    and check that they are properly unset with:
    
        gsettings list-recursively | grep switch-to-application | sort

A list of useful gnome extension: 
    
    Blur my Shell - Desktop Cube - Unite - Night Theme Switcher - Vitals

Icons and cursor theme
    
    Extract from secondary drive in /OS/Linux/ the theme inside /home/tarch1/.local/share/icons

Install Bottles from Flatpak for managing Windows apps. 

TROUBLESHOOTIG

If gnome on wayland not start's on machine's with hybrid gpu try
     
    ln -s /dev/null /etc/udev/rules.d/61-gdm.rules

PIPEWIRE TROUBLESHOOTING

If /etc/pipewire/ folder and its contents doesn't exist run

    cp -r /usr/share/pipewire /etc/
    cp -r /usr/share/wireplumber /etc/

    than be sure /home/!!!your username!!!/.config/autostart/pipewire.desktop exist in case copy it :

    cp ~/UNI/Conf_files/Pipewire/pipewire.desktop ~/.config/autostart/
 
    if you have installed pipewire-media-session comment out at the Exec inside ~/.config/autostart/pipewire.desktop
 
    ###& /usr/bin/pipewire-media-session

and uncomment these 2 lines at the end of /etc/pipewire/pipewire.conf
    
    #{ path = "/usr/bin/pipewire" args = "-c pipewire-pulse.conf" }
    
    - if you have installed pipewire-media-session
 
       #{ path = "/usr/bin/pipewire-media-session" args = "" }

    - else if you have installed wireplumber replace the above command with
    
       { path = "wireplumber"  args = "" }

At the very end if everything else not worked in /etc/pulse/client.conf change from yes to no

    autospawn = yes
    ;autospawn = yes
	
	
EXTRA
Steam launch script for dlss and RT
	PROTON_ENABLE_NVAPI=1 VKD3D_CONFIG=dxr11 VKD3D_FEATURE_LEVEL=12_1 %command%	
