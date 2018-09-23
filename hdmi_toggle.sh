#!/bin/bash
# ugly udev hook to toggle display configuration


# grab the display and xauthority cookie
export DISPLAY=$(w -h -s | grep ":[0-9]\W" | head -1 | awk '{print $2}')
X_USER=$(w -h -s | grep ":[0-9]\W" | head -1 | awk '{print $1}')
export XAUTHORITY=/home/$X_USER/.Xauthority

# get the status of the external display
status=$(< /sys/class/drm/card0-HDMI-A-1/status)
case $status in
	disconnected)
		su $X_USER -c 'xrandr --output HDMI-1 --off'
		logger "disabled hdmi output for $X_USER"
		;;
	connected)
		while [[ $(< /sys/class/drm/card0-HDMI-A-1/enabled) -ne 'enabled' ]]; do
			su $X_USER -c 'xrandr --output HDMI-1 --auto'
			sleep 1;
		done

		su $X_USER -c 'xrandr --output HDMI-1 --auto --right-of eDP-1'
		logger "enabled hdmi output for $X_USER"
		;;
esac
