eZ80 i2c assembly language example driver code for Olimex's MOD-RTC2 real time clock by Tim Gilmore July 2024


UPDATE - settime MOSlet and clock.bin

settime.bin MOSlet to be placed in the MOS directory

clock.bin place wherever you want to call it from.

Usage:

*settime seconds minutes hours day date month year
eg.    *settime 0 23 18 2 21 7 24

For 0 seconds, 23 minutes past 6pm, Tuesday July 21st 2024

UPDATE - new version, 'setrtc' is more efficent at sending i2c data

Usage:

*setrtc seconds minutes hours day date month year
eg.    *setrtc 0 23 18 2 21 7 24
