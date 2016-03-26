# raspiap
Turn your Raspberry Pi into an Access Point

Based on the installer for the Realtek RTL8188CUS, from Paul Miller.

https://github.com/jchan172/raspberry_pi_wifi_ap

It's basically a fork, except it uses the hostapd from the repositories, not a custom one, and it only works for dongles using the nl80211 driver. It might work for Realtek dongles using the rtl871xdrv instead, but not the RTL8188.

Main references:
http://www.pi-point.co.uk/documentation/
http://elinux.org/RPI-Wireless-Hotspot
http://jacobsalmela.com/raspberry-pi-and-routing-turning-a-pi-into-a-router/

Usage:
sudo ./raspiap.sh
