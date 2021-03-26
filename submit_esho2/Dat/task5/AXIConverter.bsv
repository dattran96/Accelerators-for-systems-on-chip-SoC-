package AXIConverter;

import BlueAXI::*;
import GetPut::*;
import BUtils :: *;
import FIFOF :: *;
import Vector::*;

interface AXIConverter;
	// Add custom interface definitions
	(* prefix = "S00_AXI" *)
	interface AXI4_Lite_Slave_Rd_Fab#(64, 64) slave_read_fab;
	(* prefix = "S00_AXI" *)
	interface AXI4_Lite_Slave_Wr_Fab#(64, 64) slave_write_fab;

	(* prefix = "M00_AXI" *)
	interface AXI4_Master_Rd_Fab#(64, 128, 16, 0) master_read_fab;
	(* prefix = "M00_AXI" *)
	interface AXI4_Master_Wr_Fab#(64, 128, 16, 0) master_write_fab;
endinterface

(*clock_prefix = "aclk", reset_prefix = "aresetn"*)
module mkAXIConverter(AXIConverter);

     	// Create interface
	AXI4_Lite_Slave_Rd#(64, 64) slave_read <- mkAXI4_Lite_Slave_Rd(2);
	AXI4_Lite_Slave_Wr#(64, 64) slave_write <- mkAXI4_Lite_Slave_Wr(2);

	AXI4_Master_Rd#(64, 128, 16, 0) master_read <- mkAXI4_Master_Rd(16,16,True);
	AXI4_Master_Wr#(64, 128, 16, 0) master_write <- mkAXI4_Master_Wr(16,16,16, True);

	//Configuration registers	
	Reg#(Bit#(64)) address_image_1 <- mkReg(0);	
	Reg#(Bit#(64)) address_image_2 <- mkReg(0);
	Reg#(Bit#(64)) start <- mkReg(0);
	Reg#(Bit#(64)) conversion_finished <- mkReg(0);
	Reg#(Bit#(64)) image_length_read <- mkReg(512);
	Reg#(Bit#(64)) image_width_read <- mkReg(512);
	Reg#(Bit#(64)) kernel_size_read <- mkReg(7);
	
	//Write channel registers
    	Reg#(Bool) start_write_request <- mkReg(False);
    	Reg#(Bit#(64)) ddr_write_count <- mkReg(0);
    	
    	//Read request registers
    	Reg#(Bool) converting_flag <- mkReg(False);
    	Reg#(Bit#(64)) ddr_read_count <- mkReg(0);
    	
    	//Reg#(FixedPoint#(8,10)) gray_data <- mkReg(0)
    	Reg#(Int#(9)) gray_data <- mkReg(0);
    	//FIFO input data 
   	FIFOF#(Bit#(128)) buffer <- mkSizedFIFOF(2560);
	FIFOF#(Bit#(8)) buffer_8bit <- mkSizedFIFOF(1600);
	
	//Read Slave channel 
    	rule handleReadRequest;
        	let r <- slave_read.request.get();
        	if(r.addr[5:0] == 0) begin // Check address 0
            		slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(address_image_1)), resp: OKAY});
        	end
        	else if(r.addr[5:0] == 8) begin // Check address 4
            		slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(address_image_2)), resp: OKAY});
        	end 
        	else if(r.addr[5:0] == 16) begin // Check address 8
            		slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(start)), resp: OKAY});
        	end
        	else if(r.addr[5:0] == 24) begin // Check address 16
            		slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(conversion_finished)), resp: OKAY});
        	end
        	else if(r.addr[5:0] == 32) begin 
            		//slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(address_image_1 + address_image_2)), resp: OKAY});
            		slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(image_length_read)), resp: OKAY});
        	end
        	else if(r.addr[5:0] == 40) begin 
            		//slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(address_image_1 + address_image_2)), resp: OKAY});
            		slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(image_width_read)), resp: OKAY});
        	end
        	else if(r.addr[5:0] == 48) begin 
            		//slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(address_image_1 + address_image_2)), resp: OKAY});
            		slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(kernel_size_read)), resp: OKAY});
        	end   
    	endrule
    	
    	rule handleWriteRequest if(!start_write_request);
        	let r <- slave_write.request.get();
        	if(r.addr[5:0] == 0) begin // Check address 0
            		address_image_1 <= r.data;
            		slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
        	end
        	else if(r.addr[5:0] == 8) begin // Check address 4
            		address_image_2 <= r.data;
            		slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
        	end 
        	else if(r.addr[5:0] == 16) begin // Check address 8
            		start <= r.data;
            		conversion_finished <= 0;
            		start_write_request <= True;
            		
            		slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
        	end
        	else if(r.addr[5:0] == 32) begin
            		image_length_read <= r.data;
            		slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
        	end
        	else if(r.addr[5:0] == 40) begin
            		image_width_read <= r.data;
            		slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
        	end
        	else if(r.addr[5:0] == 48) begin
            		kernel_size_read <= r.data;
            		slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
        	end
    	endrule
    	
    	function UInt#(8) burstLengthBarrierCrossing (Bit#(64) curr_addr,UInt#(8) init_burst_length);
		UInt#(64) allowed_byte = 4080 - unpack(zExtend(curr_addr[11:0]));
		allowed_byte = ((allowed_byte + 16) >> 4) - 1;
		return truncate(allowed_byte);
	endfunction
    	
    	Reg#(Bit#(64)) state_64 <- mkReg(0);
    	Reg#(UInt#(8)) burst_length <- mkReg(255);
   	rule readRequest if( start != 0 && conversion_finished == 0);
   		if(ddr_read_count <= image_width_read*image_length_read) begin 
							
			Bit#(64) curr_addr = address_image_1 + ddr_read_count;
                 	UInt#(8) curr_burst = burstLengthBarrierCrossing(curr_addr, burst_length);
                 		
        	        axi4_read_data(master_read, curr_addr, curr_burst);
                	ddr_read_count <= ddr_read_count + 16*zExtend(pack(curr_burst))+16;                		
        	end else begin
        		ddr_read_count <= 0;
            		start <= 0;
        	end
    	endrule 
    	
    	/*Store data locally with 128 bit each*/
   	rule localDataBuffer;
		let r <- master_read.response.get();
		//$display("%d raw", r.data);
		buffer.enq(r.data);
  	endrule
  	
  	 /* Store data locally with 8 bits each */
   	Reg#(Bit#(4)) enq_order <- mkReg(0);
   	rule localDataBuffer_8bit; //enqueue only when buffer_8bit is empty, so that avoid mismatch length
		Bit#(128) temp = buffer.first(); 
		case(enq_order)		
			0: buffer_8bit.enq(temp[7:0]);  //didn't work for sequential
			1: buffer_8bit.enq(temp[15:8]);
			2: buffer_8bit.enq(temp[23:16]); 
			3: buffer_8bit.enq(temp[31:24]);
			4: buffer_8bit.enq(temp[39:32]);
			5: buffer_8bit.enq(temp[47:40]);
			6: buffer_8bit.enq(temp[55:48]);
			7: buffer_8bit.enq(temp[63:56]);
			8: buffer_8bit.enq(temp[71:64]);  //didn't work for sequential
			9: buffer_8bit.enq(temp[79:72]);
			10: buffer_8bit.enq(temp[87:80]); 
			11: buffer_8bit.enq(temp[95:88]);
			12: buffer_8bit.enq(temp[103:96]);
			13: buffer_8bit.enq(temp[111:104]);
			14: buffer_8bit.enq(temp[119:112]);
			15: begin buffer_8bit.enq(temp[127:120]); buffer.deq; end
		endcase
		enq_order <= enq_order + 1;
   	endrule
  	
   	
   	Reg#(Int#(32)) gx_reg[7][7];
   	Reg#(Int#(32)) gy_reg[7][7];
   	for (Integer i=0; i<7; i=i+1)
		for (Integer j=0; j<7; j=j+1)
			gx_reg[i][j] <- mkReg(0);
	for (Integer i=0; i<7; i=i+1)
		for (Integer j=0; j<7; j=j+1)
			gy_reg[i][j] <- mkReg(0);
   		
   	Reg#(Int#(32)) threshold <- mkReg(70);

   	FIFOF#(Bit#(8)) rowBuffer_array[6];
   	
   	for (Integer i=0; i<6; i=i+1)
		rowBuffer_array[i] <- mkSizedFIFOF(3000); //PAY ATTENTION, SUBJECT to CHANGE
  	
  	Reg#(Bool) windowReady <- mkReg(False); //issue to other rules that data of 9 pixel are ready
   	Reg#(Bool) windowSlide <- mkReg(False); // other rules set this bit to issue they need new window data
   	Reg#(Bool) window_Initial <- mkReg(False);
   	Reg#(Bool) rowBuffer_inital <- mkReg(True);
  	Reg#(Bit#(32)) bufferRowCount <- mkReg(0);
	Reg#(Bool) pre_sobelConvert <- mkReg(False); //to avoid long critical path, sobel operator can not be written in one single rule, but distributed into 2 rules, this flag will activate the fist rule and the sobelConvert flag will activate the second rule
	Reg#(Bool) sobelConvert <- mkReg(False); // activate the first rule
	
	Reg#(Bit#(32)) kernel_size <- mkReg(7); //PAY ATTENTION, SUBJECT to CHANGE
   	Reg#(Bit#(32)) image_width <- mkReg(512); //PAY ATTENTION, SUBJECT to CHANGE
   	Reg#(Bit#(32)) image_length <- mkReg(512); //PAY ATTENTION, SUBJECT to CHANGE
   	Reg#(Bool) init_image_parameter_finish <- mkReg(False); //PAY ATTENTION, SUBJECT to CHANGE
      /* Initialize row buffer at the first time, since slide window operate correctly only if row buffer 1 and row buffer 2 are already filled */
   	rule image_parameter_inital if(start != 0 && init_image_parameter_finish==False);
		kernel_size <= 7;
		image_width <= image_width_read[31:0];
		image_length <= image_length_read[31:0];
		if(kernel_size_read==7) begin
			gy_reg[0][0] <= -1;gy_reg[0][1] <=  -6;gy_reg[0][2] <= -15;gy_reg[0][3] <=  -20;gy_reg[0][4] <= -15;gy_reg[0][5] <=  -6;gy_reg[0][6] <= -1;
			gy_reg[1][0] <= -4;gy_reg[1][1] <= -24;gy_reg[1][2] <= -60;gy_reg[1][3] <=  -80;gy_reg[1][4] <= -60;gy_reg[1][5] <= -24;gy_reg[1][6] <= -4;
			gy_reg[2][0] <= -5;gy_reg[2][1] <= -30;gy_reg[2][2] <= -75;gy_reg[2][3] <= -100;gy_reg[2][4] <= -75;gy_reg[2][5] <= -30;gy_reg[2][6] <= -5;
			gy_reg[3][0] <=  0;gy_reg[3][1] <=   0;gy_reg[3][2] <=   0;gy_reg[3][3] <=    0;gy_reg[3][4] <=   0;gy_reg[3][5] <=   0;gy_reg[3][6] <= 0;
			gy_reg[4][0] <=  5;gy_reg[4][1] <=  30;gy_reg[4][2] <=  75;gy_reg[4][3] <=  100;gy_reg[4][4] <=  75;gy_reg[4][5] <=  30;gy_reg[4][6] <= 5;
			gy_reg[5][0] <=  4;gy_reg[5][1] <=  24;gy_reg[5][2] <=  60;gy_reg[5][3] <=   80;gy_reg[5][4] <=  60;gy_reg[5][5] <=  24;gy_reg[5][6] <= 4;
			gy_reg[6][0] <=  1;gy_reg[6][1] <=   6;gy_reg[6][2] <=  15;gy_reg[6][3] <=   20;gy_reg[6][4] <=  15;gy_reg[6][5] <=   6;gy_reg[6][6] <= 1;
		
			gx_reg[0][0] <=  -1;gx_reg[0][1] <=  -4;gx_reg[0][2] <=  -5;gx_reg[0][3] <= 0;gx_reg[0][4] <=  5;gx_reg[0][5] <=  4;gx_reg[0][6] <= 1;
			gx_reg[1][0] <=  -6;gx_reg[1][1] <= -24;gx_reg[1][2] <= -30;gx_reg[1][3] <= 0;gx_reg[1][4] <= 30;gx_reg[1][5] <= 24;gx_reg[1][6] <= 6;
			gx_reg[2][0] <= -15;gx_reg[2][1] <= -60;gx_reg[2][2] <= -75;gx_reg[2][3] <= 0;gx_reg[2][4] <= 75;gx_reg[2][5] <= 60;gx_reg[2][6] <= 15;
			gx_reg[3][0] <= -20;gx_reg[3][1] <= -80;gx_reg[3][2] <= -100;gx_reg[3][3] <= 0;gx_reg[3][4] <= 100;gx_reg[3][5] <= 80;gx_reg[3][6] <= 20;
			gx_reg[4][0] <= -15;gx_reg[4][1] <= -60;gx_reg[4][2] <= -75;gx_reg[4][3] <= 0;gx_reg[4][4] <= 75;gx_reg[4][5] <= 60;gx_reg[4][6] <= 15;
			gx_reg[5][0] <= -6;gx_reg[5][1] <= -24;gx_reg[5][2] <= -30;gx_reg[5][3] <= 0;gx_reg[5][4] <= 30;gx_reg[5][5] <= 24;gx_reg[5][6] <= 6;
			gx_reg[6][0] <= -1;gx_reg[6][1] <= -4;gx_reg[6][2] <= -5;gx_reg[6][3] <= 0;gx_reg[6][4] <= 5;gx_reg[6][5] <= 4;gx_reg[6][6] <= 1;
			threshold <= 70;				
		end
		else if(kernel_size_read==5) begin
			gy_reg[0][0] <= 0;gy_reg[0][1] <= 0;gy_reg[0][2] <= 0;gy_reg[0][3] <= 0;gy_reg[0][4] <= 0;gy_reg[0][5] <= 0;gy_reg[0][6] <= 0;
			gy_reg[1][0] <= 0;gy_reg[1][1] <= -1;gy_reg[1][2] <= -4;gy_reg[1][3] <= -6;gy_reg[1][4] <= -4;gy_reg[1][5] <= -1;gy_reg[1][6] <= 0;
			gy_reg[2][0] <= 0;gy_reg[2][1] <= -2;gy_reg[2][2] <= -8;gy_reg[2][3] <= -12;gy_reg[2][4] <= -8;gy_reg[2][5] <= -2;gy_reg[2][6] <= 0;
			gy_reg[3][0] <= 0;gy_reg[3][1] <= 0;gy_reg[3][2] <= 0;gy_reg[3][3] <= 0;gy_reg[3][4] <= 0;gy_reg[3][5] <= 0;gy_reg[3][6] <= 0;
			gy_reg[4][0] <= 0;gy_reg[4][1] <= 2;gy_reg[4][2] <= 8;gy_reg[4][3] <= 12;gy_reg[4][4] <= 8;gy_reg[4][5] <= 2;gy_reg[4][6] <= 0;
			gy_reg[5][0] <= 0;gy_reg[5][1] <= 1;gy_reg[5][2] <= 4;gy_reg[5][3] <= 6;gy_reg[5][4] <= 4;gy_reg[5][5] <= 1;gy_reg[5][6] <= 0;
			gy_reg[6][0] <= 0;gy_reg[6][1] <= 0;gy_reg[6][2] <= 0;gy_reg[6][3] <= 0;gy_reg[6][4] <= 0;gy_reg[6][5] <= 0;gy_reg[6][6] <= 0;
			
			gx_reg[0][0] <= 0;gx_reg[0][1] <= 0;gx_reg[0][2] <= 0;gx_reg[0][3] <= 0;gx_reg[0][4] <= 0;gx_reg[0][5] <= 0;gx_reg[0][6] <= 0;
			gx_reg[1][0] <= 0;gx_reg[1][1] <= -1;gx_reg[1][2] <= -2;gx_reg[1][3] <= 0;gx_reg[1][4] <= 2;gx_reg[1][5] <= 1;gx_reg[1][6] <= 0;
			gx_reg[2][0] <= 0;gx_reg[2][1] <= -4;gx_reg[2][2] <= -8;gx_reg[2][3] <= 0;gx_reg[2][4] <= 8;gx_reg[2][5] <= 4;gx_reg[2][6] <= 0;
			gx_reg[3][0] <= 0;gx_reg[3][1] <= -6;gx_reg[3][2] <= -12;gx_reg[3][3] <= 0;gx_reg[3][4] <= 12;gx_reg[3][5] <= 6;gx_reg[3][6] <= 0;
			gx_reg[4][0] <= 0;gx_reg[4][1] <= -4;gx_reg[4][2] <= -8;gx_reg[4][3] <= 0;gx_reg[4][4] <= 8;gx_reg[4][5] <= 4;gx_reg[4][6] <= 0;
			gx_reg[5][0] <= 0;gx_reg[5][1] <= -1;gx_reg[5][2] <= -2;gx_reg[5][3] <= 0;gx_reg[5][4] <= 2;gx_reg[5][5] <= 1;gx_reg[5][6] <= 0;
			gx_reg[6][0] <= 0;gx_reg[6][1] <= 0;gx_reg[6][2] <= 0;gx_reg[6][3] <= 0;gx_reg[6][4] <= 0;gx_reg[6][5] <= 0;gx_reg[6][6] <= 0;
			threshold <= 50;
		end
		else if(kernel_size_read==3)begin
			gy_reg[0][0] <= 0;gy_reg[0][1] <= 0;gy_reg[0][2] <= 0;gy_reg[0][3] <= 0;gy_reg[0][4] <= 0;gy_reg[0][5] <= 0;gy_reg[0][6] <= 0;
			gy_reg[1][0] <= 0;gy_reg[1][1] <= 0;gy_reg[1][2] <= 0;gy_reg[1][3] <= 0;gy_reg[1][4] <= 0;gy_reg[1][5] <= 0;gy_reg[1][6] <= 0;
			gy_reg[2][0] <= 0;gy_reg[2][1] <= 0;gy_reg[2][2] <= -1;gy_reg[2][3] <= -2;gy_reg[2][4] <= -1;gy_reg[2][5] <= 0;gy_reg[2][6] <= 0;
			gy_reg[3][0] <= 0;gy_reg[3][1] <= 0;gy_reg[3][2] <= 0;gy_reg[3][3] <= 0;gy_reg[3][4] <= 0;gy_reg[3][5] <= 0;gy_reg[3][6] <= 0;
			gy_reg[4][0] <= 0;gy_reg[4][1] <= 0;gy_reg[4][2] <= 1;gy_reg[4][3] <= 2;gy_reg[4][4] <= 1;gy_reg[4][5] <= 0;gy_reg[4][6] <= 0;
			gy_reg[5][0] <= 0;gy_reg[5][1] <= 0;gy_reg[5][2] <= 0;gy_reg[5][3] <= 0;gy_reg[5][4] <= 0;gy_reg[5][5] <= 0;gy_reg[5][6] <= 0;
			gy_reg[6][0] <= 0;gy_reg[6][1] <= 0;gy_reg[6][2] <= 0;gy_reg[6][3] <= 0;gy_reg[6][4] <= 0;gy_reg[6][5] <= 0;gy_reg[6][6] <= 0;
			
			gx_reg[0][0] <= 0;gx_reg[0][1] <= 0;gx_reg[0][2] <= 0;gx_reg[0][3] <= 0;gx_reg[0][4] <= 0;gx_reg[0][5] <= 0;gx_reg[0][6] <= 0;
			gx_reg[1][0] <= 0;gx_reg[1][1] <= 0;gx_reg[1][2] <= 0;gx_reg[1][3] <= 0;gx_reg[1][4] <= 0;gx_reg[1][5] <= 0;gx_reg[1][6] <= 0;
			gx_reg[2][0] <= 0;gx_reg[2][1] <= 0;gx_reg[2][2] <= -1;gx_reg[2][3] <= 0;gx_reg[2][4] <= 1;gx_reg[2][5] <= 0;gx_reg[2][6] <= 0;
			gx_reg[3][0] <= 0;gx_reg[3][1] <= 0;gx_reg[3][2] <= -2;gx_reg[3][3] <= 0;gx_reg[3][4] <= 2;gx_reg[3][5] <= 0;gx_reg[3][6] <= 0;
			gx_reg[4][0] <= 0;gx_reg[4][1] <= 0;gx_reg[4][2] <= -1;gx_reg[4][3] <= 0;gx_reg[4][4] <= 1;gx_reg[4][5] <= 0;gx_reg[4][6] <= 0;
			gx_reg[5][0] <= 0;gx_reg[5][1] <= 0;gx_reg[5][2] <= 0;gx_reg[5][3] <= 0;gx_reg[5][4] <= 0;gx_reg[5][5] <= 0;gx_reg[5][6] <= 0;
			gx_reg[6][0] <= 0;gx_reg[6][1] <= 0;gx_reg[6][2] <= 0;gx_reg[6][3] <= 0;gx_reg[6][4] <= 0;gx_reg[6][5] <= 0;gx_reg[6][6] <= 0;
			threshold <= 30;
		end
		init_image_parameter_finish <= True;
  	endrule
  	
  	/* Initialize row buffer at the first time, since slide window operate correctly only if row buffer 1 and row buffer 2 are already filled */
   	Reg#(Bit#(32)) count_FIFOchop <- mkReg(0); //Use only a part of FIFO depending on image length
   	rule rowBufferInital if(rowBuffer_inital == True && rowBuffer_array[0].notFull() == True && 
   				rowBuffer_array[1].notFull() == True && init_image_parameter_finish == True &&
   				count_FIFOchop <= image_length-kernel_size -1 );  				
	   	rowBuffer_array[0].enq(0); //Fill waste values until full
		rowBuffer_array[1].enq(0); //Fill waste values until full
	   	rowBuffer_array[2].enq(0); //Fill waste values until full
		rowBuffer_array[3].enq(0); //Fill waste values until full
	   	rowBuffer_array[4].enq(0); //Fill waste values until full
		rowBuffer_array[5].enq(0); //Fill waste values until full
		count_FIFOchop <= count_FIFOchop +1;
		//$display("Test Here 1");	
   	endrule
   	
   	//rule rowBufferInital_finish if(rowBuffer_1.notFull() == False && rowBuffer_inital == True);
   	rule rowBufferInital_finish if(count_FIFOchop == image_length-kernel_size  && rowBuffer_inital == True);
   		rowBuffer_inital <= False;
		window_Initial <= True;
		//$display("Test Here 2");
   	endrule
   	
   	/* Initialize window buffer, Fill up all pixels of 3x3 kernel and row 1 and row2, ready for next processing step */

	Vector#(49, Bit#(8)) vec1 = newVector;
	Reg#(Bit#(8)) slideWindow_reg[7][7];
	for (Integer i=0; i<7; i=i+1)
		for (Integer j=0; j<7; j=j+1)
			slideWindow_reg[i][j] <- mkReg(0);
				
	
	Reg#(Bool) slide <- mkReg(False);    //command register
	Reg#(Bool) slide_finish <- mkReg(False);    //status register	
	Reg#(Bit#(32)) slide_position <- mkReg(0); //Count from 0
	Reg#(Bit#(8)) state_temp <- mkReg(0);
	
	Reg#(Bool) windowBuffer_once_inital <- mkReg(False);    //status register
	rule windowBuffer_inital if(window_Initial == True && rowBuffer_inital == False );
	  	//$display("Test Here 5");
	  	for (Integer i=0; i<7; i=i+1)
			for (Integer j=0; j<6; j=j+1)
				slideWindow_reg[i][j] <= slideWindow_reg[i][j+1];
		
		for (Integer i=0; i<6; i=i+1)
		 	rowBuffer_array[i].enq(slideWindow_reg[i+1][0]);
		 		
		for (Integer i=0; i<7; i=i+1) begin
			if (i == 6) begin
				slideWindow_reg[i][6] <= buffer_8bit.first(); buffer_8bit.deq; //PAY ATTENTION, REPLACE "testslideWindow" WITH "buffer_8bit" to get data via AXI
			end
			else begin
		 		slideWindow_reg[i][6] <= rowBuffer_array[i].first; rowBuffer_array[i].deq; 
		 	end
		end
		 	
		//$display("%d Reg77", slideWindow_reg[6][6]);
		bufferRowCount <= bufferRowCount + 1;
		slide_finish <= True;
		if( slide_position < image_length)
			slide_position <= slide_position + 1;
		else
			slide_position <= 1;
			
		if(bufferRowCount >= image_length*(kernel_size-1) + kernel_size -1 && windowBuffer_once_inital == False) begin //512+ 512+ 9 //PAY ATTENTION  change
			//window_Initial <= False;
			windowBuffer_once_inital <= True;
			pre_sobelConvert <= True; //command
			//slide_finish <= False; //Reset slide status
		end
		
		else if(bufferRowCount >= image_length*image_width-1) begin
			$display("Test Here 99");
			window_Initial <= False;
			pre_sobelConvert <= False;
			slide <= False;
		end
		//$display("slide position %d pixel read %d",slide_position,bufferRowCount);
	endrule
	
 	Reg#(Int#(32)) sum_1 <- mkReg(0);
 	rule pre_sobelOperator1 if (pre_sobelConvert == True && slide_position != 1 &&  slide_position != 2 && 
 			slide_position != 3 &&  slide_position != 4 &&  slide_position != 5 &&  slide_position != 6 ); //calculate first sum of the sober operator
 		Int#(32) sum_1_tmp =0;
 		for (Integer i=0; i<7; i=i+1)
			for (Integer j=0; j<7; j=j+1)
				sum_1_tmp = sum_1_tmp + gx_reg[i][j]*unpack(zExtend(slideWindow_reg[i][j]));
		sum_1 <= signExtend(sum_1_tmp);			
	endrule
 	
 	Reg#(Int#(32)) sum_2 <- mkReg(0);
 	rule pre_sobelOperator2 if (pre_sobelConvert == True && slide_position != 1 &&  slide_position != 2 &&  
			slide_position != 3 &&  slide_position != 4 &&  slide_position != 5 &&  slide_position != 6 ); //calculate first sum of the sober operator
		Int#(32) sum_2_tmp =0;
 		for (Integer i=0; i<7; i=i+1)
			for (Integer j=0; j<7; j=j+1)
				sum_2_tmp = sum_2_tmp + gy_reg[i][j]*unpack(zExtend(slideWindow_reg[i][j]));
		sum_2 <= signExtend(sum_2_tmp);	
					
		if(sobelConvert==False  && bufferRowCount < image_length*image_width) begin
			sobelConvert <= True;
		end
		else if(sobelConvert==True && bufferRowCount == image_length*image_width) begin
			sobelConvert <= False;
		end	
	endrule


	FIFOF#(Bit#(128)) buffer_out <- mkSizedFIFOF(100);
   	Reg#(Bit#(128)) out_hold <- mkReg(0);
   	Reg#(Bit#(8)) out_count <- mkReg(0);
	Reg#(Bit#(8)) sobelState <- mkReg(0);
   	rule sobelOperator(sobelConvert == True && slide_position != 1 &&  slide_position != 2 &&  
			slide_position != 3 &&  slide_position != 4 &&  slide_position != 5 &&  slide_position != 6);
   		slide_finish <= False; //Reset slide status
		
		Int#(32) sum_1_absolute =0;
		Int#(32) sum_2_absolute =0;
		Int#(32) sum_12;
		Bit#(8) outPixel;		

		if( sum_1 < 0) begin
   			sum_1_absolute = sum_1*-1;
   		end
   		if( sum_2 < 0) begin
   			sum_2_absolute = sum_2*-1;
   		end
   		
   		sum_12 = sum_1_absolute + sum_2_absolute;
		
		if(kernel_size_read == 7) begin
	   		//sum_12 <= sum_12*255 / 175550;
	   		sum_12 = sum_12*255 >> 17;
	   	end
	   	else if (kernel_size_read == 5) begin
	   		//sum_12 <= sum_12*255 / 13074;
	   		sum_12 = sum_12*255 >> 13 ;
	   	end
	   	else if (kernel_size_read == 3) begin
	   		//sum_12 <= sum_12*255 / 1064;
	   		sum_12 = sum_12*255 >> 10;
	   	end
		
		
		if (sum_12 <= threshold) begin
   			outPixel =  0; 
   		end
   		else begin
   			outPixel = pack(sum_12)[7:0];
   		end
		
   		case(out_count)		
			0: begin out_hold[7:0] <= outPixel;out_count <= out_count + 1;sobelState <= 6;  end
			1: begin out_hold[15:8] <= outPixel;out_count <= out_count + 1;sobelState <= 6;   end
			2: begin out_hold[23:16] <= outPixel; out_count <= out_count + 1;sobelState <= 6;   end
			3: begin out_hold[31:24] <= outPixel;out_count <= out_count + 1;sobelState <= 6;   end
			4: begin out_hold[39:32] <= outPixel;out_count <= out_count + 1;sobelState <= 6;   end
			5: begin out_hold[47:40] <= outPixel;out_count <= out_count + 1;sobelState <= 6;   end
			6: begin out_hold[55:48] <= outPixel;out_count <= out_count + 1;sobelState <= 6;   end
			7: begin out_hold[63:56] <= outPixel;out_count <= out_count + 1;sobelState <= 6;  end
			8: begin out_hold[71:64] <= outPixel;out_count <= out_count + 1;sobelState <= 6;  end
			9: begin out_hold[79:72] <= outPixel;out_count <= out_count + 1;sobelState <= 6;   end
			10: begin out_hold[87:80] <= outPixel; out_count <= out_count + 1;sobelState <= 6;   end
			11: begin out_hold[95:88] <= outPixel;out_count <= out_count + 1;sobelState <= 6;   end
			12: begin out_hold[103:96] <= outPixel;out_count <= out_count + 1;sobelState <= 6;   end
			13: begin out_hold[111:104] <= outPixel;out_count <= out_count + 1;sobelState <= 6;   end
			14: begin out_hold[119:112] <= outPixel;out_count <= out_count + 1;sobelState <= 6;   end
			//15: begin out_hold[127:120] <= outPixel;out_count <= out_count + 1;sobelState <= 6;  end
		endcase

		
		if(out_count == 15)  begin 
	   		buffer_out.enq(out_hold);
	   		out_count <= 0;
	   	end
	   	
	   	else if (bufferRowCount == image_length*image_width-1) begin
			Bit#(128) tmp = {out_hold[31:0],96'd0};
	   		buffer_out.enq(tmp);
	   		//conversion_finished <= 1;
		end
		$display("Finish Filter read input pixel %d, output pixel value is %d, slide position",bufferRowCount,outPixel,slide_position); 
   	endrule

   	Reg#(Bool) wnext <- mkReg(True);
	Reg#(UInt#(8)) curr_burst_write <- mkReg(0);	
	rule writeRequest if(wnext == True && conversion_finished == 0 && start_write_request == True);
		//$display("Conversion finish %d",conversion_finished); 
		if(ddr_write_count +4096 >= zExtend((image_length-kernel_size+1)*(image_width-kernel_size+1)))begin  
           		conversion_finished <= 1;
           		$display("Conversion finish %d",conversion_finished); 
            		ddr_write_count <= 0;
            		start_write_request <= False;
        	end
       		else begin
       			Bit#(64) curr_addr = address_image_2 + ddr_write_count;
                	UInt#(8) curr_burst = burstLengthBarrierCrossing(curr_addr, burst_length);
			axi4_write_addr(master_write, curr_addr, curr_burst);
            		ddr_write_count <= ddr_write_count + 16*zExtend(pack(curr_burst))+16;
            		//$display("write count %d",ddr_write_count); 
            		curr_burst_write <= curr_burst;
			wnext <= False;
        	end
	endrule 
	
	Reg#(UInt#(8)) beat_count <- mkReg(0);
	rule rgb2gray if(wnext == False);
		if(beat_count == curr_burst_write) begin
			axi4_write_data(master_write, buffer_out.first(), 16'hffff, True);
			wnext <= True;
			beat_count <= 0;
		end else begin 
        		axi4_write_data(master_write, buffer_out.first(), 16'hffff, False);
			beat_count <= beat_count + 1;
		end
        	buffer_out.deq();
    	endrule
	

	rule requestResponse;
		let r <- master_write.response.get();
	endrule
    
  	interface AXI4_Master_Rd_Fab master_read_fab = master_read.fab;
	interface AXI4_Master_Wr_Fab master_write_fab = master_write.fab;	
	interface AXI4_Lite_Slave_Rd_Fab slave_read_fab = slave_read.fab;
	interface AXI4_Lite_Slave_Wr_Fab slave_write_fab = slave_write.fab; 
endmodule

endpackage
