# Todo
- [] GPIO via evdev events?
- [] Deep Sleep to save battery?
- [] Autorun example
- [] Fix all Todo in this document

# Best practice

Using the  LicheeSG-Nano-Build project with a LicheeRV Nano board opens up some interesting possibilities. However, the documentation may not be sufficient for several use cases. This document contains best practise solutions for some of them, as well as noteworthy information for getting started.

## References

The information in this document has been collected via the following references:

- Official docs: https://wiki.sipeed.com/hardware/en/lichee/RV_Nano/1_intro.html
  - It may also be worth translating the chinese docs, these contain more information
- Article with a huge amount of information about hardware: https://medium.com/@ret7020/licheerv-nano-ai-board-first-steps-d05e7999dd29
  - Repository with some more info https://github.com/ret7020/LicheeRVNano?tab=readme-ov-file
- Discussions in the following issues
  - https://github.com/scpcom/LicheeSG-Nano-Build/issues/19

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


## Basic setup


```bash
MICRO_SD_DEV="" # e.g. /dev/sdb
xzcat licheervnano-e_sd.img.xz | sudo dd of=$MICRO_SD_DEV bs=100M status=progress conv=fsync
```

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
```


## LCD Support

The LicheeRV has a connector for specific LC-Displays including a touch connector. Only very specific 31-pin / 6-pin LCDs can be connected. There are some officially supported displays, but they are hardly available. However, there is one 2.28" display that is readily available (e.g. via Aliexpress) and is supported out of the box with the latest image including touch support.

### Hardware

The LCD model number is 

`LHCM228TS003A`

Here are some Links to vendors (last update: 2025-12-04):

- Focus Display Store: https://aliexpress.com/item/1005006185077108.html
- Ecyberspaces: https://aliexpress.com/item/1005009508131601.html
- Maithoga: https://aliexpress.com/item/1005009881951326.html
- SURENOO (no touch?): https://aliexpress.com/item/1005009261668372.html
- B2B Baidu: https://b2b.baidu.com/land?id=39559f991fdef58e6c72b9f770bae1d810

**Connectors**
The connectors are a bit fiddly to get working, but this picture shows how it can be connected:

- Todo: add photo of connected display -

### Configuration


To enable the display, you need to change the `/boot/uEnv.txt`:

```
panel=st7701_hd228001c31
```

You might also want to turn on framebuffer support (which is required by some UI toolkits to paint onto the screen):
```
touch /boot/fb
```

### Controlling the display

After your display is connected and set up, you might want to control the brightness or other values:

Turn off display / disable backlight:
- The backlight is turned of while the display theretically is still fully functional
- This will not change the touch capabilities of the screen, so touch will still work when display is turned off
```bash
echo 0 > /sys/class/pwm/pwmchip8/pwm2/enable
```

Change Brightness (there is no information of how the display will react with changes in the long run, so be careful with non-default values): 
- default: `2000`
- minimum tested: `0`
- maximum tested: `2500` 
```bash
echo 1000 > /sys/class/pwm/pwmchip8/pwm2/duty_cycle
```

Resetting/shutting down the LCD itself maybe done via some GPIO operation. The pin for reset is called LCD0_RESET (= PWR_GPIO0 = GPIOE 0 = gpiochip480 offset 0)

This seems to work to:
- Reset/turn off LCD: `devmem 0x30010a4 32 0x04`
- Back to normal (may need to send LCD init cmds after re-enabling it): `devmem 0x30010a4 32 0x00`

### Initialize PWM

You probably won't need this, because the display works out of the box, but for the sake of completeness:

If the PWM is not initialized, yet you can do it with (this is normally done by `/etc/init.d/S04backlight`):

```bash
devmem 0x030010AC 32 0x04 # PINMUX PWM10

echo 2 > /sys/class/pwm/pwmchip8/export

echo 2500 > /sys/class/pwm/pwmchip8/pwm2/duty_cycle
echo 10000 > /sys/class/pwm/pwmchip8/pwm2/period
echo 1 > /sys/class/pwm/pwmchip8/pwm2/enable
```

`devmem` is just a tool for mmio (32 bit in this case).

## Audio support

The board has an integrated audio chip, but it might be much more comfortable to just use an external USB-C to 3.5mm Audio Adapter (e.g. the Apple USB-C Adapter is cheap and has acceptable quality).

To test audio output, you can copy over a file (e.g. via SSH) and then run:

```bash
aplay --device=hw:2,0 /root/sample-3s.wav
```

The `hw:2,0` is required to select the correct audio device, it might differ depending on your choice. To find the right device, you might use 

```bash
aplay -l
lsusb
```


## Low power modes

There is very little information about saving battery in the first place like hibernation or sleep modes. In fact the only resource I found is https://maixhub.com/discussion/100487 with the following conclusion:

> Yes, there is a low power mode. The device has three cores, one of which is an 8051 MCU core. This core can handle low power operations when Linux is not running, if it can be programmed. However, due to insufficient documentation, I couldn’t find any information on how to manage the 8051 core.