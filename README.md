# openwrt-fancontrol

A replacement for /sbin/fan_ctrl.sh, based on [this post](https://forum.openwrt.org/viewtopic.php?pid=280811#p280811) from the OpenWRT wrt1900ac thread.

To use it:

* Download the new fan controller and save it /etc/ and make it executable
```
wget --no-check-certificate https://raw.githubusercontent.com/jjack/openwrt-fancontrol/master/fancontrol.sh -O /etc/fancontrol.sh
chmod +x fancontrol.sh
```

* Test it to make sure it runs correctly
```
/etc/fancontrol.sh verbose
```

* Let it run in the background to keep your router cool.
* You'll probably also want to start this on boot. In LuCI that's in System > Startup
```
/etc/fancontrol.sh &
```

*	Disable the original fan controller in your cron by removing or commenting out the following line.
*	In LuCI that's in System > Scheduled Tasks
```
 */5 * * * * /sbin/fan_ctrl.sh
```
