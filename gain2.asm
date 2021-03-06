//Author: Patrick Gaydecki & PsiPhiTheta

.section program;
.align 4;
.global _main;
#include <defBF706.h>
 
_main:
call codec_configure; 
call sport_configure;
get_audio:
wait_left:
// Wait left flag in and read
R0=[REG_SPORT0_CTL_B]; CC=BITTST(R0, 31); if !CC jump wait_left;
// Write left out
R0=[REG_SPORT0_RXPRI_B]; [REG_SPORT0_TXPRI_A]=R0;                                         
wait_right:												
// Wait right flag in and read
R0=[REG_SPORT0_CTL_B]; CC=BITTST(R0, 31); if !CC jump wait_right;
// Write right out
R0=[REG_SPORT0_RXPRI_B]; [REG_SPORT0_TXPRI_A]=R0; 
jump get_audio;
._main.end:

// Function codec_configure initialises the ADAU1761 codec. Refer to the control register
// descriptions, page 51 onwards of the ADAU1761 data sheet.
codec_configure:
[--SP] = RETS; // Push stack (only for nested calls)
R1=0x01(X); R0=0x4000(X); call TWI_write; // Enable master clock, disable PLL
R1=0x7f(X); R0=0x40f9(X); call TWI_write; // Enable all clocks
R1=0x03(X); R0=0x40fa(X); call TWI_write; // Enable all clocks
R1=0x01(X); R0=0x4015(X); call TWI_write; // Set serial port master mode
R1=0x13(X); R0=0x4019(X); call TWI_write; // Set ADC to on, both channels
R1=0x21(X); R0=0x401c(X); call TWI_write; // Enable left channel mixer
R1=0x41(X); R0=0x401e(X); call TWI_write; // Enable right channel mixer
R1=0x03(X); R0=0x4029(X); call TWI_write; // Turn on power, both channels
R1=0x03(X); R0=0x402a(X); call TWI_write; // Set both DACs on
R1=0x01(X); R0=0x40f2(X); call TWI_write; // DAC gets L, R input from serial port
R1=0x01(X); R0=0x40f3(X); call TWI_write; // ADC sends L, R input to serial port
R1=0x0b(X); R0=0x400a(X); call TWI_write; // Set left line-in gain to 0 dB
R1=0x0b(X); R0=0x400c(X); call TWI_write; // Set right line-in gain to 0 dB

R1=0xd7(X); R0=0x4023(X); call TWI_write; // [MODIFIED] Set left headphone volume to -4 dB. Since we need LHPM=1, HPEN=1 and a gain of -4dB thus since LHPVOL ranges from 000000-111111 so we need 215 -> d7 (in hex)

R1=0xe7(X); R0=0x4024(X); call TWI_write; // Set right headphone volume to 0 dB
R1=0x00(X); R0=0x4017(X); call TWI_write; // Set codec default sample rate, 48 kHz
nop;
RETS = [SP++];                            // Pop stack (only for nested calls)
rts;
codec_configure.end:

// Function sport_configure initialises the SPORT0. Refer to pages 26-59, 26-67,
// 26-75 and 26-76 of the ADSP-BF70x Blackfin+ Processor Hardware Reference manual.
sport_configure:
R0=0x3F0(X); [REG_PORTC_FER]=R0;          // Set up Port C in peripheral mode
R0=0x3F0(X); [REG_PORTC_FER_SET]=R0;      // Set up Port C in peripheral mode
R0=0x2001973; [REG_SPORT0_CTL_A]=R0;      // Set up SPORT0 (A) as TX to codec, 24 bits
R0=0x0400001; [REG_SPORT0_DIV_A]=R0;      // 64 bits per frame, clock divisor of 1
R0=0x1973(X); [REG_SPORT0_CTL_B]=R0;      // Set up SPORT0 (B) as RX frm codec, 24 bits
R0=0x0400001; [REG_SPORT0_DIV_B]=R0;      // 64 bits per frame, clock divisor of 1
rts;
sport_configure.end:

// Function TWI_write is a simple driver for the TWI. Refer to page 24-15 onwards
// of the ADSP-BF70x Blackfin+ Processor Hardware Reference manual.
TWI_write:
R3=R0 <<0x8; R0=R0 >>>0x8; R2=R3|R0;      // Reverse low order and high order bytes
R0=0x3232(X); [REG_TWI0_CLKDIV]=R0;       // Set duty cycle
R0=0x008c(X); [REG_TWI0_CTL]=R0;          // Set pre-scale and enable TWI
R0=0x0038(X); [REG_TWI0_MSTRADDR]=R0;     // Address of codec
[REG_TWI0_TXDATA16]=R2;                   // Address of register to set, LSB then MSB
R0=0x00c1(X); [REG_TWI0_MSTRCTL]=R0;      // Command to send three bytes and enable TX
[--SP] = RETS; call delay; RETS = [SP++]; // Delay
[REG_TWI0_TXDATA8]=R1;                    // Data to write
[--SP] = RETS; call delay; RETS = [SP++]; // Delay
R0=0x050; [REG_TWI0_ISTAT]=R0;            // Clear TXERV interrupt
[--SP] = RETS; call delay; RETS = [SP++]; // Delay
R0=0x010; [REG_TWI0_ISTAT]=R0;            // Clear MCOMP interrupt
rts;
TWI_write.end:

// Function delay introduces a delay to allow TWI communication
delay:
p0=0x8000;
loop lc0=p0;
nop; nop; nop;
loop_end;
rts;
delay.end:
