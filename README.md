# Universal-Installation-Script

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

DISABLING INTEL TURBO BOOST

https://wiki.archlinux.org/title/CPU_frequency_scaling#Disabling_Turbo_Boost


GNOME SETUP

    Increase volume steps by: (less value = more steps)

        gsettings set org.gnome.settings-daemon.plugins.media-keys volume-step 1

   Remove shortcut that coz with super+($number) with: 
     
        for i in {1..9}; do gsettings set "org.gnome.shell.keybindings" "switch-to-application-$i" "[]"; done

    and check that they are properly unset with:
    
        gsettings list-recursively | grep switch-to-application | sort

A list of useful gnome extension: 
    
    Blur my Shell - Desktop Cube - Sound IO Device Chooser - Unite - Night Theme Switcher Dynamic Panel Transparency

Icons and cursor theme
    
    Extract from secondary drive in /OS/Linux/ the theme inside /home/tarch1/.local/share/icons

TROUBLESHOOTIG

If gnome on wayland not start's on machine's with hybrid gpu setup comment 
     
    sed -i 's/DRIVER=="nvidia"/#DRIVER=="nvidia"/g' /lib/udev/rules.d/61-gdm.rules

PIPEWIRE TROUBLESHOOTING

If /etc/pipewire/ folder and its contents doesn't exist run

    cp -r /usr/share/pipewire /etc/

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

At the very end if either else not worked in /etc/pulse/client.conf change from yes to no

    autospawn = yes
    ;autospawn = yes
