/*
Program flashled flashes LED0, which is connected to pin 3 of the GPIO port C (PC3).
It takes #define statements from the header file "defBF706.h". Note it only uses
two, i.e. the port direction register (REG_PORTC_DIR_SET) and the port data
register (REG_PORTC_DATA). First, it enables output on pin3 of port C.
Next it enters a loop to pulse the pin. Note: the pit must be low for the LED 
to turn (since the LED's cathode is connected to the pin). There is an error in the
EVM manual, which states the pin must be high. 
 
Author: Patrick Gaydecki
Date  : 29.9.2017
 */ 
.section program;  
.global _main; 
.align 4;
# include <defBF706.h> 
# define mydelay 0x4000000

//#define REG_PORTC_DIR_SET 0x2004011C  /* PORTC Port x GPIO Direction Set Register */
//#define REG_PORTC_DATA    0x2004010C  /* PORTC Port x GPIO Data Register */
 
_main:
// Set the direction and data registers.
// Set bit 3, port C as output. 
    r0=0;
    r1=b#1000;
    [REG_PORTC_DIR_SET]=r1;
    p3=mydelay; 
// Endless loop.
flash: 
    bittgl(r0, 3);  // toggle LED
    [REG_PORTC_DATA]=r0;
    loop lc0=p3;    // delay
    nop;
    loop_end;
    jump flash;
_main.end:

