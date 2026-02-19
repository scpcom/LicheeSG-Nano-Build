# Todo
- [ ] Download and mount the image to modify it (see https://unix.stackexchange.com/questions/316401/how-to-mount-a-disk-image-from-the-command-line)
- [ ] Deep Sleep to save battery?
- [ ] Fix all Todo in this document

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
- 8051 core simple run example
  - https://github.com/ret7020/sg2002-8051

## Hardware introduction

The hardware is pretty powerful for an embedded device, much more than the usual ESP32 boards while still maintaining a pretty small form factor. More details on the hardware can be found here:

- https://wiki.sipeed.com/hardware/en/lichee/RV_Nano/1_intro.html


## Toolchain

The actual toolchain is a Buildroot environment, which contains a fully functional but stripped down Linux kernel including some modules to support external devices and other hardware (e.g. LC-Displays). 

Unfortunately it is required to use an *older* toolchain (Kernel 5.10) to make sure all the SDK components are working as expected.

Especially the vector extensions are hard to use the right way with default gcc because the SOC does not have v1.0 extensions it has some `v0.7 t-head/xuantie` variant.

At least for glibc every code can be compiled with a default compiler. But this is only a side project in the debian repo:
https://github.com/scpcom/sophgo-sg200x-debian/tree/generic-toolchain
(it uses the same code branches, just the build environment/process is different)


## Basic setup

### Flashing the image

```bash
MICRO_SD_DEV="" # e.g. /dev/sdb
xzcat licheervnano-e_sd.img.xz | sudo dd of=$MICRO_SD_DEV bs=100M status=progress conv=fsync
```

### Wifi
Depending on the Hardware version you are using, the LicheeRV Nano has integrated WiFi, which often is the only way besides using an usb-to-serial adapter to get a shell.

Edit the file `/boot/wpa_supplicant.conf` and change `NAME` and `PASSWORD` accordingly:

```
ctrl_interface=/var/run/wpa_supplicant
ap_scan=1
network={
  ssid="NAME"
  psk="PASSWORD"
}
```

## Device mode (OTG) vs host mode

Depending on your use case, you might either control other devices with the lichee (device mode) or need to connect devices to the LicheeRV (host mode). In host mode you need to power the LicheeRV via `VSYS` pin.

### Power without USB-C (and via `VSYS`)

To power the LicheeRV without connecting a USB-C power supply, you have to connect a 5V power supply to the `VSYS` (+) pin as well as `GND` (-). The LicheeRV is pretty picky with voltages, so be sure to supply between 4.8V and 5.15V - with less it will not power on and more might damage the device permanently.

A device that comes in handy (especially when also using a battery) may be the `TP4057` (the 5V version), which is small, can deliver up to 5.10V and supports battery undervoltage and overvoltage protection. 

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

If you would like to use GPIO on the LicheeRV Nano, below is some useful information about how to get started. 
It has to be stated that depending on your device config many of the available GPIO PINs are already reserved for
internal purposes (e.g. WiFi or Bluetooth) and cannot be used without limitations.

To interact with GPIO you have to `export` the pin, specify the `direction` and then get or set the `value`. 

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

### LicheeRV GPIO Overview

Below is a GPIO Overview with the following columns:

- `Name`: PIN label on the PCB
- `Pin Num`: Number in order of PCB counting scheme
- `Dev num`: Linux device number for `sys/class` - `32 * <name-letter-mapping> + <name-number>`, e.g. `32 * A + 29` => `32 * 15 + 29 = 509`
  - Usually the `<name-letter-mapping>` is A=0, B=1, C=2, etc. but here it is some kind of a fixed or reversed scheme I could not find a reference to: 
    - P=11
    - B=14
    - A=15
- `Mem. Addr.`: Memory address to set GPIO modes
- `UART` / `PWM` / `SPI` / `I2C` / `AUX`: Specific GPIO functions referring to the column name
- `Notes`: Specifically refers to `scpcom/LicheeSG-Nano-Build` with the default image config for `licheervnano-e_sd.img.xz`.



| Name | Pin Num | Dev num | Mem         | UART      | PWM    | SPI       | I2C      | AUX       | Usage notes                 |
|------|---------|---------|-------------|-----------|--------|-----------|----------|-----------|-----------------------------|
| A17  | 19      | 497     | 0x0300_1040 | UART0 RX  | PWM 5  |           |          |           | Reserved for Serial (RX)    |
| A16  | 18      | 496     | 0x0300_1044 | UART0 TX  | PWM 4  |           |          |           | Reserved for Serial (TX)    |
| A15  | 17      | 495     | 0x0300_103C |           |        |           | I2C5 SCL |           | Reserved for I2C5 (Bitbang) |
| A24  | 25      | 504     | 0x0300_1060 |           |        | SPI4 CS   |          | EMMC D1   | Usable¹                     |
| A23  | 24      | 503     | 0x0300_105C |           |        | SPI4 MISO |          | EMMC CMD  | Not usable²                 |
| A27  | 23      | 507     | 0x0300_1058 |           |        |           | I2C5 SDA | EMMC D3   | Reserved for I2C5 (Bitbang) |
| A25  | 22      | 505     | 0x0300_1054 |           |        | SPI4 MOSI |          | EMMC D0   | Not usable²                 |
| A22  | 21      | 502     | 0x0300_1050 |           |        | SPI4 SCK  |          | EMMC CLK  | Usable¹                     |
| A26  | 20      | 506     | 0x0300_104C |           |        |           |          | EMMC D2   | Reserved for WiFi EN        |
| A19  | 26      | 499     | 0x0300_1064 | UART1 TX  | PWM 7  |           |          | JTAG TMS  | Untested                    |
| A18  | 27      | 498     | 0x0300_1068 | UART1 RX  | PWM 6  |           |          | JTAG TCK  | Untested                    |
| A29  | 29      | 508     | 0x0300_1074 | UART2 RX  |        |           |          | JTAG TDO  | Untested                    |
| B3   | 59      | 451     | 0x0300_10F8 |           |        |           |          | ADC1      | Untested                    |
| A28  | 28      | 509     | 0x0300_1070 | UART2 TX  |        |           |          | JTAG TDI  | Untested                    |
| P18  | 51      | 370     | 0x0300_10D0 | UART3 CTS | PWM 4³ | SPI2 CS   | I2C1 SCL | SDIO1 D3  | Reserved for WiFi           |
| P19  | 52      | 371     | 0x0300_10D4 | UART3 TX  | PWM 5³ |           |          | SDIO1 D2  | Reserved for WiFi           |
| P21  | 54      | 373     | 0x0300_10DC | UART3 RTS | PWM 7³ | SPI2 MISO | I2C1 SDA | SDIO1 D0  | Reserved for WiFi           |
| P22  | 55      | 374     | 0x0300_10E0 |           | PWM 8  | SPI2 MOSI | I2C3 SCL | SDIO1 CMD | Reserved for WiFi           |
| P23  | 56      | 375     | 0x0300_10E4 |           | PWM 9  | SPI2 SCK  | I2C3 SDA | SDIO1 CLK | Reserved for WiFi           |
| P20  | 53      | 372     | 0x0300_10D8 | UART3 RX  | PWM 6³ |           |          | SDIO1 D1  | Reserved for WiFi           |
| A14  | 15      | 494     | 0x0300_1038 |           |        |           |          |           | Untested                    |



- ¹ This GPIO can be used for input and output (e.g. push buttons) via the commands below
- ² This GPIO cannot be used for input and output by default, and it is unclear what is preventing it to work as expected
- ³ PWM has duplicate numbering for A and P in the diagram - it is unclear, what this implicates


To prepare a GPIO pin for a e.g. a push button, you can use the following commands:

```sh
devmem <mem> b 0x03
echo <dev num> > /sys/class/gpio/export
watch -n 1 -t cat /sys/class/gpio/gpio<dev num>/value


# Example for A24:
devmem 0x03001060 b 0x03
echo 504 > /sys/class/gpio/export
watch -n 1 -t cat /sys/class/gpio/gpio504/value
```



## Autorun applications

If you are planning to autorun applications (e.g. to run a UI right from the start), you can just put an entry in the `/etc/rc.local` script:

- Todo: example -

Also you can manage autorun placing sh files inside `/etc/init.d`. Create file with name `S<prior><name>`. Replace `<prior>` with priority of process and `<name>` can be random. Simple example:

```sh
#!/bin/sh
case $1 in
    	start)
        # Logic for command like /etc/init.d/S99my_app start
        devmem 0x03001068 32 0x6
        devmem 0x03001064 32 0x6
        /root/my_app /dev/ttyS1 500000 &
        ;;
    	stop)
        # Logic for command like /etc/init.d/S99my_app stop
        ;;
    	*)
        exit 1
        ;;
esac
```

By default `init.d` will start your run with `start` argument, but you can ignore argument processing, for example such way:

```sh
#!/bin/sh
devmem 0x03001068 32 0x6
devmem 0x03001064 32 0x6
/root/my_app /dev/ttyS1 500000 &
```

## Disabling WiFi for saving battery

To save battery, disabling WiFi might be an option. Here are some commands that might help.


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

### Adjusting Cpufreq

There might be a possibility to save power with adjusting the Cpufreq via CPU governor:

https://linux-sunxi.org/Cpufreq

**CAUTION:** This is untested at the moment and just meant as a starting point.

#### CPU governor - performance vs. ondemand

Both the chosen governor as well as the cpufreq limits can have a huge impact on power consumption, performance and even functionality on too low cpu_freq.

**performance**
If the lowest possible power consumption is not a priority, then the `performance` governor is a very good option. 

```bash

# power consumption does not matter, run at full performance
echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

```

**ondemand**

If you allow very low scaling_min_freq values with ondemand/interactive the system might behave laggy and some timing critical stuff (eg. reading out sensors or GPIO) won't work.
A good compromise between power consumption and a responsive system being able to operate at full performance when needed is

```bash
# power consumption is important, run on demand performance
echo ondemand > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor

echo 1008000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
echo 408000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq

echo 25 > /sys/devices/system/cpu/cpufreq/ondemand/up_threshold
echo 10 > /sys/devices/system/cpu/cpufreq/ondemand/sampling_down_factor
echo 1 > /sys/devices/system/cpu/cpufreq/ondemand/io_is_busy
```

## Pinmux configuration

You can use `devmem` command in user-space after Linux boot to configure pins functions but also you can do it via U-boot init code inside `build/boards/sg200x/sg2002_licheervnano_sd/u-boot/cvi_board_init.c` via `mmio_write_32` functions
