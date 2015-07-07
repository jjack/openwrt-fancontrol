# openwrt-fancontrol

A replacement for /sbin/fan_ctrl.sh, based on [this post](https://forum.openwrt.org/viewtopic.php?pid=280811#p280811) from the OpenWRT wrt1900ac forum.

To use it this:

* Download the new fan controller and save it to anwyhere you'd like and make it executable
```
chmod +x fancontrol.sh
```

* Test it to make sure it runs correctly
```
./fancontrol.sh verbose
```

* Let it run in the background and keep your router cool
```
./fancontrol.sh &
```

*	Disable the original fan controller in your cron by removing or commenting out the following line:
```
 */5 * * * * /sbin/fan_ctrl.sh
```
