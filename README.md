# Mutuatech Linux

This is the home for scripts and other resources used to build the Mutuatech Linux, a preconfigured ArchLinux installation designed to be used by corporate fullstack developers.

Yet on it's alpha phase, but OK to use in your workstation or even laptop, this version still lacks a comprehensive documentation.

# Packages
ARCH: android-tools android-udev aria2 arp-scan atom bower bzip2 chromium cups dbeaver deadbeef dosfstools e2fsprogs fakeroot flashplugin font-bh-ttf foomatic-db-engine firefox freemind gdmap gephi ghostscript gimp git  gparted gsfonts gsmartcontrol gst-libav gst-plugins-bad gst-plugins-base gst-plugins-good gst-plugins-ugly gstreamer-vaapi gulp gutenprint hdparm hunspell hunspell-en i7z inkscape intel-ucode iotop jadx lftp libopenraw libreoffice-fresh linux-headers lighttpd midori mlocate netcat noto-fonts npm opera otf-overpass pepper-flash pgadmin4 pkgfile powertop qupzilla rdesktop recordmydesktop screen scribus sdparm seamonkey smbclient squashfs-tools surf systemd-swap tigervnc ttf-anonymous-pro ttf-arphic-uming ttf-baekmuk ttf-bitstream-vera ttf-cheapskate ttf-arphic-ukai ttf-croscore ttf-dejavu ttf-droid ttf-fira-mono ttf-freefont ttf-gentium ttf-hack ttf-inconsolata ttf-ionicons ttf-junicode ttf-liberation ttf-linux-libertine ttf-linux-libertine-g ttf-tibetan-machine ttf-ubraille ttf-ubuntu-font-family ttf-droid typescript unrar unzip usb_modeswitch vim virtualbox virtualbox-guest-utils virtualbox-guest-dkms vlc vym wget x264 xarchiver xdiskusage youtube-dl

AUR: android-platform-22 android-sdk android-sdk-build-tools-23.0.2 android-sdk-platform-tools astah-professional cntlm dbeaver editix-free ganttproject genymotion gst-plugin-libde265 libde265 hunspell-pt-br intellij-idea jdk oracle-datamodeler oracle-sqldeveloper packer projectlibre sublime-text-dev ttf-ms-fonts ttf-vista-fonts virtualbox-ext-oracle visual-studio-code xxdiff

Office AUR: acroread, acroread-fonts-systemwide

DEV: mysql postgresql r glpk gnuplot gdb ddd tomcat8 tomcat-native jad dia heimdall netbeans proguard eclipse-jee subversion

DEV AUR: wildfly jmeter modelio-bin, eclipse-subclipse, eclipse-pmd, eclipse-umlet wireshark-gtk

CONNECT AUR: skype lib32-apulse

Forensic: foremost, testdisk

To Classify: android-tools, cadaver davfs2 mplayer, mesa-demos, playonlinux wine-mono ntp wmctrl xdotool yarn bluez-utils bluez-firmware pulseaudio-alsa pulseaudio-bluetooth pavucontrol transset-df compton time thunderbird geeqie

HAND INSTALLED: Pentaho (all on /opt: data-integration, metadata-editor, pentaho-server, report-designer)

# Instructions about Pentaho, Android-SDK, Genymotion, Eclipse and possibly other packages

Packages that writes on /opt should have their affected /opt directory linked to /home/common/**/* -- dont forget to run 'fixCommonPermissions'.

Other packages download their binaries or use huge caches that could be shared among users -- Electron, Gradle, Maven, Node, NPM, Yarn, Genymotion, Eclipse... -- the same rule applies and the link should be placed on '/home/new_user' as well as on every user's home.

# Scripts
List explicit installed packages on a running ArchLinux system: pacman -Q | while read l; do p=${l/[^A-Za-z0-9_\.+-]*/}; if pacman -Qi $p | grep -i "Explicitly installed" &>/dev/null; then if pacman -Si $p &>/dev/null; then echo "arch: $p"; else echo "AUR: $p"; fi; fi; done

# Install Instructions
Here goes the instructions in case one wants to build, from ground up, this installation
1) Activate multilib in /etc/pacman.conf
2) Install JDK from AUR
3) Install all other packages
4) Further instructions on https://keep.google.com/u/0/#NOTE/1481562389052.1178388875