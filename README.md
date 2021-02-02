# Accelerators for SoC with Xilinx ZynqMP-SoC ultra96 FPGA
# From AXI-Lite to AXI-Full

Authors: Minh Quang Tran  and Nguyen Tien Dat Tran  <br />

Topic: Use Xilinx Ultra96 FPGA to accelerate operators in image processing area  <br />



Task 1 has two files: 
    
    1_bitsteam file:  Bitstream of MysteryReg IP core
    
    2_mmap file: Test the MysteryReg IP core by reading and writing 4 registers of MysteryReg


Task 2 has 4 folder:

    1_MUL_AXI: AXI Multiplier implemented in Bluespec language
    
    2_Bitstream: Bitstream of the the IP core which has AXI Multiplier IP core and also ILA debug IP core inside.
    
    3_mmap: Test the AXI Multiplier by writing 2 sample values to first and second register and getting back value from the third register
    
    4_debug: debug server to transfer data from board to PC in ESA LAB

Task 3: Grayscale image converter  <br />

Task4: Upgrade frome AXI Lite to AXI Full for faster image conversion   <br />
    
Task 5: Accelerator for a Sobel Filter in image processing area. <br />
