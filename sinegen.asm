//Author: Patrick Gaydecki & PsiPhiTheta

.section L1_data_a;  // Linker places 6 kHz LUT starting at 0x11800000

// **** INSERT CODE HERE ****
.BYTE4/r32 sin6[]=0.0r,0.7071068r,1.0r,0.7071068r,0.0r,-0.7071068r,-1.0r,-0.7071068r; // [INSERTED] Sets the 8 values required (since sampling frequency is 48kHz, 48/8=6kHz) for a 6kHz sine wave (used Signal Wizard). Uses interpolation. 

.section L1_data_b;  // Linker places 12 kHz LUT starting at 0x11900000

// **** INSERT CODE HERE **** 
.BYTE4/r32 sin12[]=0.0r,1.0r,0.0r,-1.0r,0.0r,1.0r,0.0r,-1.0r; // [INSERTED] Sets the 4 values required (since sampling frequency is 48kHz, 48/4=12kHz) for a 12kHz sine wave (used Signal Wizard). Uses interpolation. Repeated to two periods in order to have the same length as 6kHz sine for later sections. 

.section program; 
.global _main; 
.align 4;  
# include <defBF706.h>   

_main:
call codec_configure; 
call sport_configure;

// Set modulo addressing for each channel

// **** INSERT CODE HERE ****
P0=length(sin6)*4; // [INSERTED] Pointer register P0 holds the length of the 6kHz sine data (line 12) in bytes which is the same as the extended 12kHz sine data (line 17).
I0 = 0x11800000; B0 = I0; L0 = P0; // [INSERTED] Circular buffer initialised for 6kHz sine data (Base register, Index register, Length register & Pointer register)
I1 = 0x11900000; B1 = I1; L1 = P0; // [INSERTED] Circular buffer initialised for 12kHz sine data (Base register, Index register, Length register & Pointer register)

get_audio:
wait_left:
// Wait for left data then dummy read
R0=[REG_SPORT0_CTL_B]; 
CC=BITTST(R0, 31); 
if !CC jump wait_left;
R0=[REG_SPORT0_RXPRI_B];
// Load 6 kHz data from LUT and write to codec
// Note 8-bit shift right since codec is 24-bit 

// **** INSERT CODE HERE ****
R0 = [I0++]; // [INSERTED] Writes the 6kHz sine data for the left channel to the R0 register
R0 >>= 0x08; // [INSERTED] Brings the data (too big) into the codec's range


[REG_SPORT0_TXPRI_A]=R0;
wait_right:
// Wait for right data then dummy read
R0=[REG_SPORT0_CTL_B]; 
CC=BITTST(R0, 31); 
if !CC jump wait_right;
R0=[REG_SPORT0_RXPRI_B];
// Load 12 kHz data from LUT and write to codec
// Note 8-bit shift right since codec is 24-bit 

// **** INSERT CODE HERE ****
R1 = [I1++]; // [INSERTED] Writes the 12kHz sine data for the left channel to the R0 register
R1 >>= 0x08; // [INSERTED] Brings the data (too big) into the codec's range


[REG_SPORT0_TXPRI_A]=R1;
jump get_audio;
._main.end:

// Function codec_configure initialises the ADAU1761 codec. Refer to the control register
// descriptions, page 51 onwards of the ADAU1761 data sheet.
codec_configure:
[--SP] = RETS;                            // Push stack (only for nested calls)
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
R1=0xe7(X); R0=0x4023(X); call TWI_write; // Set left headphone volume to 0 dB
R1=0xe7(X); R0=0x4024(X); call TWI_write; // Set right headphone volume to 0 dB
R1=0x00(X); R0=0x4017(X); call TWI_write; // Set codec default sample rate, 48 kHz
NOP;
RETS = [SP++];                            // Pop stack (only for nested calls)
RTS;
codec_configure.end:

// Function sport_configure initialises the SPORT0. Refer to pages 26-59, 26-67,
// 26-75 and 26-76 of the ADSP-BF70x Blackfin+ Processor Hardware Reference manual.
sport_configure:
R0=0x3F0(X); [REG_PORTC_FER]=R0;          // Set up Port C in peripheral mode
R0=0x3F0(X); [REG_PORTC_FER_SET]=R0;      // Set up Port C in peripheral mode
R0=0x2001973; [REG_SPORT0_CTL_A]=R0;      // Set up SPORT0 (A) as TX to codec, 24 bits
R0=0x0400001; [REG_SPORT0_DIV_A]=R0;      // 64 bits per frame, clock divisor of 1
R0=0x1973(X); [REG_SPORT0_CTL_B]=R0;      // Set up SPORT0 (B) as RX from codec, 24 bits
R0=0x0400001; [REG_SPORT0_DIV_B]=R0;      // 64 bits per frame, clock divisor of 1
RTS;
sport_configure.end:

// Function TWI_write is a simple driver for the TWI. Refer to page 24-15 onwards
// of the ADSP-BF70x Blackfin+ Processor Hardware Reference manual.
TWI_write:
R3=R0 <<0x8; R0=R0 >>>0x8; R2=R3|R0;      // Reverse low order and high order bytes
R0=0x3232(X); [REG_TWI0_CLKDIV]=R0;       // Set duty cycle
R0=0x008c(X); [REG_TWI0_CTL]=R0;          // Set prescale and enable TWI
R0=0x0038(X); [REG_TWI0_MSTRADDR]=R0;     // Address of codec
[REG_TWI0_TXDATA16]=R2;                   // Address of register to set, LSB then MSB
R0=0x00c1(X); [REG_TWI0_MSTRCTL]=R0;      // Command to send three bytes and enable tx
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
P0=0x8000;
loop LC0=P0;
NOP; NOP; NOP;
loop_end;
RTS;
delay.end:
