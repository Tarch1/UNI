# Universal-Installation-Script
Problems with pacman? Try this :
pacman-key --populate artix

STEP:

Find your interface with: 

    ip a
    rfkill unblock all
    ip link interface up

then use connmanctl:

    scan wifi
    services
    agent on
    connect wifi_***_psk
    quit
After setup yout connecction run

    git clone https://github.com/Tarch1/Arch-tix
    cd Arch-tix/
  
adjust packages at the end of base_install

    chmod +x base_install
    bash base_install

then reboot

Use nmtui to connect on your network 
then personalize with 

    chmod +x full_setup
    bash full_setup

Reboot and Enjoy!

PS: if gnome on wayland not start's on machine's with hybrid gpu setup comment 
     
     DRIVER=="nvidia"......

at /lib/udev/rules.d/61-gdm.rules if doesn't work, move away   

     sudo mv /usr/share/xsessions/gnome-xorg.desktop /usr/share/xsessions/gnome-xorg.desktop.back

For increasing volume steps: (less value = more steps)

     gsettings set org.gnome.settings-daemon.plugins.media-keys volume-step 1

An addition for super+($number) navigation use: 
     
     for i in {1..9}; do gsettings set "org.gnome.shell.keybindings" "switch-to-application-$i" "[]"; done

checking that they are properly unset with gsettings list-recursively | grep switch-to-application | sort

Pipewire troubleshooting

If /etc/pipewire folder and its contents doesn't exist run

    cp -r /usr/share/pipewire /etc/

than be sure /home/!!!your username!!!/.config/autostart/pipewire.desktop exist in case copy it :

    cp -r ~/.UNI/Conf_files/Pipewire/ ~/.config/autostart/
    

and uncomment these 2 lines at the end of /etc/pipewire/pipewire.conf
    
    #{ path = "/usr/bin/pipewire" args = "-c pipewire-pulse.conf" }
    
 - if you have installed wireplumber
 
    { path = "wireplumber"  args = "" }

 - else
    
    #{ path = "/usr/bin/pipewire-media-session" args = "" }

At the very end if either else not worked in /etc/pulse/client.conf change from yes to no

    autospawn = yes
    ;autospawn = yes
