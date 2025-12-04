# Todo
- [] GPIO events?
- [] Deep Sleep?
- [] Autorun example

# Best practice

Using the  LicheeSG-Nano-Build project with a LicheeRV Nano board opens up some interesting possibilities. However, the documentation may not be sufficient for several use cases. This document contains best practise solutions for some of them, as well as noteworthy information for getting started.

## Hardware introduction

The hardware is pretty powerful for an embedded device, much more than the usual ESP32 boards while still being a pretty small form factor. More details on the hardware can be found here:

- https://wiki.sipeed.com/hardware/en/lichee/RV_Nano/1_intro.html


## Toolchain

The actual toolchain is a Buildroot environment, which contains a fully functional but stripped down Linux kernel including some modules to support external devices and other hardware (e.g. LC-Displays). 

Unfortunately it is required to use an *older* toolchain (Kernel 5.10) to make sure all the SDK components are working as expected.

Especially the vector extensions are hard to use the right way with default gcc because the SOC does not have v1.0 extensions it has some `v0.7 t-head/xuantie` variant.

At least for glibc every code can be compiled with a default compiler. But this is only a side project in the debian repo:
https://github.com/scpcom/sophgo-sg200x-debian/tree/generic-toolchain
(it uses the same code branches, just the build environment/process is different)

## Device mode (OTG) vs host mode

### Device mode (OTG) as default

The LicheeRV Nano main use case is KVM. Basically this means that the LicheeRV Nano acts as a "remote keyboard" and a "remote display" that can be controlled via WiFi. This comes in handy if you would like to remote control a server. To simulate a keyboard, USB On-The-Go (OTG) is required, which is a specific mode you have to put the USB-C port in. If you connect the LicheeRV via USB-C it is now detected as an external input device (e.g. a keyboard).

### Host mode for connecting devices via USB-C

To connect devices via USB-C (let's say a USB storage drive or a USB-C to 3.5mm Audio Jack Adapter), you need to put the LicheeRV Nano in `host mode`, that is able to detect connections and handle the hardware.

To do so, you need to modify files on the `boot` partition:

```bash
rm /boot/usb.dev
touch /boot/usb.host
```

After a reboot you can connect your devices.


## GPIO handling

If you would like to connect hardware buttons to the LicheeRV, you might need GPIO pins to handle events.

Here is some useful information about how to get started:


**1. Find the right number**
```
352 to 383: GPIO E0 to E31
384 to 415: GPIO D0 to D31
416 to 447: GPIO C0 to C31
448 to 479: GPIO B0 to B31
480 to 511: GPIO A0 to A31
```

**GPIO `A22` Output example:**
```bash
echo 502 > /sys/class/gpio/export
echo out > /sys/class/gpio/gpio502/direction
echo 1 > /sys/class/gpio/gpio502/value
```

**GPIO `A22` Input example:**
```bash
echo 502 > /sys/class/gpio/export
echo in > /sys/class/gpio/gpio502/direction
cat /sys/class/gpio/gpio502/value
```


## Autorun applications

If you are planning to autorun applications (e.g. to run a UI right from the start), you can just put an entry in the `/etc/rc.local` script:

- Todo: example -


## Wifi (enable, disable)

Depending on the Hardware version you are using, the LicheeRV Nano has integrated Wifi, which often is the only way besides using an usb-to-serial adapter to get a shell.

### Enable Wifi

Edit the file `boot/wpa_supplicant.conf` and change `NAME` and `PASSWORD` accordingly:

```
ctrl_interface=/var/run/wpa_supplicant
ap_scan=1
network={
  ssid="NAME"
  psk="PASSWORD"
}
```

### Disable Wifi (e.g. to save battery

Stop the wifi service:

```bash
/etc/init.d/S30wifi stop
```

You may also want to stop the modules found in `/etc/init.d/S25wifimod`:
```bash
rmmod 8733bs
rmmod aic8800_fdrv
rmmod aic8800_bsp
rmmod cfg80211
```

And maybe the last step is to set the `WiFi_EN` to `0`:
```bash
WiFi_EN_Pin=506 # GPIO A26
echo ${WiFi_EN_Pin} > /sys/class/gpio/export  # WiFi_EN
echo out > /sys/class/gpio/gpio${WiFi_EN_Pin}/direction
echo 0 > /sys/class/gpio/gpio${WiFi_EN_Pin}/value
```bash