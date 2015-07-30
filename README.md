# openwrt-fancontrol

A replacement for /sbin/fan_ctrl.sh, based on [this post](https://forum.openwrt.org/viewtopic.php?pid=280811#p280811) from the OpenWRT wrt1900ac thread.

To use it:

* Download the new fan controller, save it to  /etc/, and make it executable.
```
wget --no-check-certificate https://raw.githubusercontent.com/jjack/openwrt-fancontrol/master/fancontrol.sh -O /etc/fancontrol.sh
chmod +x fancontrol.sh
```

* Test it to make sure that it runs correctly.
```
/etc/fancontrol.sh verbose
```

* Let it run in the background to keep your router cool.
```
/etc/fancontrol.sh &
```

*	Disable the orginal fan controller.
*	Remove or comment out this line from /etc/crontabs/root (In LuCI, it's System > Scheduled Tasks)
```
 */5 * * * * /sbin/fan_ctrl.sh
```

## optional
* Have this run on boot.
* Add this to /etc/rc.local (In LuCI, it's System > Startup)
```
/etc/fancontrol.sh &
```
