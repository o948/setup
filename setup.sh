#!/bin/bash
set -eu

apt update

# No annoying beeping
echo 'blacklist pcspkr' >/etc/modprobe.d/nobeep.conf

# No unnecessary packages
echo 'apt::install-recommends "false";' >/etc/apt/apt.conf.d/no-recommends.conf

# Latest kernel
source /etc/os-release
apt install -y -t "${VERSION_CODENAME}-backports" linux-image-amd64 firmware-linux

# X server
apt install -y xserver-xorg xinit libpam-systemd

# Things for building window manager
apt install -y wget unzip make g++ libx11-dev libxft-dev
# Things used by window manager
apt install -y suckless-tools xterm scrot
# Download, configure and build window manager
cd /usr/local/src/
wget https://github.com/o948/dwm/archive/my.zip
unzip my.zip
# Edit configuration before building
#vi dwm-my/config.{mk,h}
make -C dwm-my/ install
cd -

# Status bar
cat >/usr/local/bin/status <<'EOF'
#!/bin/bash
set -eu

while true; do
  s=
  s+="vol $(amixer get Master | grep -om1 '[0-9]*%') | "

  s+="wifi $(/sbin/iwgetid --raw || echo 'n/a') "
  s+="$(cat /proc/net/wireless | awk 'NR==3{print int($3 / 70 * 100)}')% | "

  s+="bat "
  case "$(cat /sys/class/power_supply/BAT0/status)" in
    Charging)    s+="+" ;;
    Discharging) s+="-" ;;
    *)           s+="?" ;;
  esac
  s+="$(cat /sys/class/power_supply/BAT0/capacity)% | "

  s+="$(date +'%Y-%m-%d %H:%M:%S')"

  xsetroot -name "$s"
  sleep 1
done
EOF
chmod +x /usr/local/bin/status

# Make xterm less ugly
cat >/etc/X11/xinit/.Xresources <<EOF
XTerm*background: black
XTerm*foreground: white
XTerm*faceName: monospace
XTerm*faceSize: 9
XTerm*VT100.translations: #override \
  Ctrl Shift <Key>C: copy-selection(CLIPBOARD, PRIMARY)
EOF

# Make startx run window manager and status bar
cat >/etc/X11/xinit/xinitrc <<EOF
status &
xrdb -merge /etc/X11/xinit/.Xresources
export _JAVA_AWT_WM_NONREPARENTING=1
exec dwm
EOF

# Configure keyboard layout: use capslock to switch LT layout
mkdir -p /etc/X11/xorg.conf.d
cat >/etc/X11/xorg.conf.d/40-keyboard.conf <<EOF
Section "InputClass"
  Identifier "system-keyboard"
  MatchIsKeyboard "on"
  Option "XkbLayout" "us,lt"
  Option "XkbModel" "pc105"
  Option "XkbVariant" ","
  Option "XkbOptions" "grp:caps_toggle,grp_led:caps"
EndSection
EOF

# Configure touchpad
mkdir -p /etc/X11/xorg.conf.d
cat >/etc/X11/xorg.conf.d/40-touchpad.conf <<EOF
Section "InputClass"
  Identifier "libinput touchpad"
  MatchIsTouchpad "on"
  MatchDevicePath "/dev/input/event*"
  Driver "libinput"
  Option "Tapping" "on"
  Option "AccelSpeed" "1"
EndSection
EOF

# Make function keys work
apt install -y alsa-utils acpi-support
# Volume keys
cat >/etc/acpi/events/vol-up <<EOF
event=button/volumeup
action=amixer set Master 5+
EOF
cat >/etc/acpi/events/vol-down <<EOF
event=button/volumedown
action=amixer set Master 5-
EOF
cat >/etc/acpi/events/vol-mute <<EOF
event=button/mute
action=amixer set Master toggle
EOF
cat >/etc/acpi/events/mic-mute <<EOF
event=button/f20
action=amixer set Capture toggle
EOF
# Mute when headphones are unplugged
cat >/etc/acpi/jack-mute.sh <<'EOF'
#!/bin/bash
if [[ $3 == "plug" ]]; then
  amixer set Master unmute
else
  amixer set Master mute
fi
EOF
chmod +x /etc/acpi/jack-mute.sh

cat >/etc/acpi/events/jack-mute <<EOF
event=jack/headphone
action=/etc/acpi/jack-mute.sh %e
EOF

# Brightness keys
if [[ -d /sys/class/backlight/intel_backlight ]]; then
cat >/etc/acpi/brightness.sh <<'EOF'
#!/bin/bash
set -eu

max=$(cat /sys/class/backlight/intel_backlight/max_brightness)
old=$(cat /sys/class/backlight/intel_backlight/brightness)
inc=$(( max / 20 ))

if [[ $1 == "+" ]]; then
  new=$(( old + inc ))
  if [[ $new -gt $max ]]; then
    new=$max
  fi
else
  new=$(( old - inc ))
  if [[ $new -lt 1 ]]; then
    new=1
  fi
fi

echo $new >/sys/class/backlight/intel_backlight/brightness
EOF
chmod +x /etc/acpi/brightness.sh

cat >/etc/acpi/events/brightness-up <<EOF
event=video/brightnessup
action=/etc/acpi/brightness.sh +
EOF
cat >/etc/acpi/events/brightness-down <<EOF
event=video/brightnessdown
action=/etc/acpi/brightness.sh -
EOF
fi

systemctl enable acpid
service acpid start

# Services for mounting storage and MTP devices
apt install -y udisks2 jmtpfs libblockdev-crypto2

# Useful command line tools
apt install -y man-db bash-completion mc vim htop wget
# Make vim the default editor
update-alternatives --set editor /usr/bin/vim.basic

# Software for media files
apt install -y moc mplayer feh evince gimp
# Fix mplayer audio pitch when changing playback speed
cat >/etc/mplayer/mplayer.conf <<EOF
af=scaletempo
EOF

# Software for the Internet
apt install -y transmission-gtk firefox-esr apulse
# Make firefox sound work without pulseaudio
cat >/usr/local/bin/firefox <<'EOF'
#!/bin/bash
exec apulse firefox-esr "$@"
EOF
chmod +x /usr/local/bin/firefox

# Software for programming
apt install -y git g++ default-jdk python3-pip gdb strace

# Password manager
apt install -y python3-gpg xsel
wget -P /usr/local/bin/ https://raw.githubusercontent.com/o948/pw/master/pw
chmod +x /usr/local/bin/pw

