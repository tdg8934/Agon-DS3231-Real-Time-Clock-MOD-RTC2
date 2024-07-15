eZ80 i2c assembly language example driver code for Olimex's MOD-RTC2 real time clock by Tim Gilmore and Richard Turnnidge July 2024
Youtube video demonstrations done by Luis of Learn Agon. 

UPDATE - settime MOSlet and clock.bin

settime.bin MOSlet to be placed in the MOS directory

clock.bin place wherever you want to call it from.

Usage:

*settime seconds minutes hours day date month year
eg.    *settime 0 23 18 2 21 7 24

For 0 seconds, 23 minutes past 6pm, Tuesday July 21st 2024

*load clock.bin
*run

UPDATE - new version, 'setrtc' is more efficent at sending i2c data

Usage:

*setrtc seconds minutes hours day date month year
eg.    *setrtc 0 23 18 2 21 7 24

UPDATE - rclock moslet to display time and date to upper right corner of screen. Removed day of the week #1-7 to display as hh/mm/ss    mm/dd/yy


Rclock.bin moslet to be placed in the MOS directory (replaces clock.bin)

Usage:

*rclock

- Note: also working on BBC BASIC usage to run rclock - (MOD-RTC2.BAS) - more to come ....

- Update - cleaned up rclock.asm unneaded routines. created rtime.bin and rdate.bin files for /MOS directory as moslets. In associated asm files, moved EQU for rtime and rdate x,y screen positions

- Usage: (delete previous versions of rtime.bin and rdate.bin from /mos and copy in new assembled or github versions for moslets
- *rtime
- *rdate
- *rclock
