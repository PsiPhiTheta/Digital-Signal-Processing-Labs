//Author: Patrick Gaydecki & PsiPhiTheta

.section L1_data_b;  // Linker places data starting at 0x11900000

// **** INSERT CODE HERE ****
.BYTE2 filter[]= "2kBandPass.txt"; // [INSERTED] Imports the (16-bit) 2k BandPass filter coeficient file 

.section program; 
.global _main;  
.align 4; 
# include <defBF706.h>  

_main:
call codec_configure; 
call sport_configure;
P0=length(filter)*2;

// Set up circular buffers

// **** INSERT CODE HERE ****
I0=0x11800000;B0=I0;L0=P0; // [INSERTED] Circular buffer initialised for input data (Base register, Index register, Length register & Pointer register)
I1=0x11900000;B1=I1;L1=P0; // [INSERTED] Circular buffer initialised for filter coefficients (Base register, Index register, Length register & Pointer register)
P0=length(filter)-1; // [INSERTED] Pointer register P0 is now intialised to hold the number of filter coeficients as defined in line 12 (i.e. k-1 iterations)

get_audio:
wait_left:
// Wait for left data then read 
R0=[REG_SPORT0_CTL_B]; 
CC=BITTST(R0, 31); 
if !CC jump wait_left;
R0=[REG_SPORT0_RXPRI_B];

// Convolution kernel

// **** INSERT CODE HERE ****
A0 = 0 || W[I0++]= R0.H || R1.H = W[I1++]; // [INSERTED] Acculumator register A0 initialised to 0 (cleared), Input audio data in R0.H fed into circular buffer I0 initialised before (16-bit), Filter coeficients in index register I0 are fed into R1.H (16-bit) then post-increments both for the next instruction. (exploits parallelism)
LOOP LC0 = P0; // [INSERTED] Start of convolution loop containing loop counter register LC0, controlled by condition in pointer register P0 (i.e. filter length-1 iterations)
A0 += R0.H * R1.H || R0.H = W[I0++] || R1.H = W[I1++]; // [INSERTED] Filter left by multiplying current input audio data in R0.H by current filter coeficients in R1.H via a 16-bit multiply into a 32-bit accumlator register A0. Then increments both I0 and I1 for the next multiplication. This shifted multiply accumulate (MAC) is the heart of convolution. (exploits parallelism)
LOOP_END; // [INSERTED] End of convolution loop
A0 += R0.H * R1.H || I0-=2; // [INSERTED] 16-bit multiplies the final values of input audio data in R0.H and filter coeficients in R1.H into 32-bit accumulator register A0. In addition, post-decrements the I0 register by two bites (i.e. 16-bit word) in order to ensure that the next value from the codec overwrites the oldest value, not the previously most recently acquired. (exploits parallelism)

//Write left out
R0=A0; [REG_SPORT0_TXPRI_A]=R0;
wait_right:

// Wait for right data then read
R0=[REG_SPORT0_CTL_B]; 
CC=BITTST(R0, 31); 
if !CC jump wait_right;
R0=[REG_SPORT0_RXPRI_B];
//Write right out
[REG_SPORT0_TXPRI_A]=R0;
jump get_audio;
rts;
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
