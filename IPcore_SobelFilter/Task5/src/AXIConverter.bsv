package AXIConverter;

import BlueAXI::*;
import GetPut::*;
import BUtils :: *;
import FIFOF :: *;

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
  	
  	Reg#(Int#(32)) gx_reg11 <- mkReg(-1);
	Reg#(Int#(32)) gx_reg12 <- mkReg(-4);
	Reg#(Int#(32)) gx_reg13 <- mkReg(-5);
	Reg#(Int#(32)) gx_reg14 <- mkReg(0);
	Reg#(Int#(32)) gx_reg15 <- mkReg(5);
	Reg#(Int#(32)) gx_reg16 <- mkReg(4);	
	Reg#(Int#(32)) gx_reg17 <- mkReg(1);

	Reg#(Int#(32)) gx_reg21 <- mkReg(-6);
	Reg#(Int#(32)) gx_reg22 <- mkReg(-24);
	Reg#(Int#(32)) gx_reg23 <- mkReg(-30);
	Reg#(Int#(32)) gx_reg24 <- mkReg(0);
	Reg#(Int#(32)) gx_reg25 <- mkReg(30);
	Reg#(Int#(32)) gx_reg26 <- mkReg(24);	
	Reg#(Int#(32)) gx_reg27 <- mkReg(6);

	Reg#(Int#(32)) gx_reg31 <- mkReg(-15);
	Reg#(Int#(32)) gx_reg32 <- mkReg(-60);
	Reg#(Int#(32)) gx_reg33 <- mkReg(-75);
	Reg#(Int#(32)) gx_reg34 <- mkReg(0);
	Reg#(Int#(32)) gx_reg35 <- mkReg(75);
	Reg#(Int#(32)) gx_reg36 <- mkReg(60);	
	Reg#(Int#(32)) gx_reg37 <- mkReg(15);

	Reg#(Int#(32)) gx_reg41 <- mkReg(-20);
	Reg#(Int#(32)) gx_reg42 <- mkReg(-80);
	Reg#(Int#(32)) gx_reg43 <- mkReg(-100);
	Reg#(Int#(32)) gx_reg44 <- mkReg(0);
	Reg#(Int#(32)) gx_reg45 <- mkReg(100);
	Reg#(Int#(32)) gx_reg46 <- mkReg(80);	
	Reg#(Int#(32)) gx_reg47 <- mkReg(20);

	Reg#(Int#(32)) gx_reg51 <- mkReg(-15);
	Reg#(Int#(32)) gx_reg52 <- mkReg(-60);
	Reg#(Int#(32)) gx_reg53 <- mkReg(-75);
	Reg#(Int#(32)) gx_reg54 <- mkReg(0);
	Reg#(Int#(32)) gx_reg55 <- mkReg(75);
	Reg#(Int#(32)) gx_reg56 <- mkReg(60);	
	Reg#(Int#(32)) gx_reg57 <- mkReg(15);

	Reg#(Int#(32)) gx_reg61 <- mkReg(-6);
	Reg#(Int#(32)) gx_reg62 <- mkReg(-24);
	Reg#(Int#(32)) gx_reg63 <- mkReg(-30);
	Reg#(Int#(32)) gx_reg64 <- mkReg(0);
	Reg#(Int#(32)) gx_reg65 <- mkReg(30);
	Reg#(Int#(32)) gx_reg66 <- mkReg(24);	
	Reg#(Int#(32)) gx_reg67 <- mkReg(6);

	Reg#(Int#(32)) gx_reg71 <- mkReg(-1);
	Reg#(Int#(32)) gx_reg72 <- mkReg(-4);
	Reg#(Int#(32)) gx_reg73 <- mkReg(-5);
	Reg#(Int#(32)) gx_reg74 <- mkReg(0);
	Reg#(Int#(32)) gx_reg75 <- mkReg(5);
	Reg#(Int#(32)) gx_reg76 <- mkReg(4);	
	Reg#(Int#(32)) gx_reg77 <- mkReg(1);

	Reg#(Int#(32)) gy_reg11 <- mkReg(-1);
	Reg#(Int#(32)) gy_reg12 <- mkReg(-6);
	Reg#(Int#(32)) gy_reg13 <- mkReg(-15);
	Reg#(Int#(32)) gy_reg14 <- mkReg(-20);
	Reg#(Int#(32)) gy_reg15 <- mkReg(-15);
	Reg#(Int#(32)) gy_reg16 <- mkReg(-6);	
	Reg#(Int#(32)) gy_reg17 <- mkReg(-1);

	Reg#(Int#(32)) gy_reg21 <- mkReg(-4);
	Reg#(Int#(32)) gy_reg22 <- mkReg(-24);
	Reg#(Int#(32)) gy_reg23 <- mkReg(-60);
	Reg#(Int#(32)) gy_reg24 <- mkReg(-80);
	Reg#(Int#(32)) gy_reg25 <- mkReg(-60);
	Reg#(Int#(32)) gy_reg26 <- mkReg(-24);	
	Reg#(Int#(32)) gy_reg27 <- mkReg(-4);

	Reg#(Int#(32)) gy_reg31 <- mkReg(-5);
	Reg#(Int#(32)) gy_reg32 <- mkReg(-30);
	Reg#(Int#(32)) gy_reg33 <- mkReg(-75);
	Reg#(Int#(32)) gy_reg34 <- mkReg(-100);
	Reg#(Int#(32)) gy_reg35 <- mkReg(-75);
	Reg#(Int#(32)) gy_reg36 <- mkReg(-30);	
	Reg#(Int#(32)) gy_reg37 <- mkReg(-5);

	Reg#(Int#(32)) gy_reg41 <- mkReg(0);
	Reg#(Int#(32)) gy_reg42 <- mkReg(0);
	Reg#(Int#(32)) gy_reg43 <- mkReg(0);
	Reg#(Int#(32)) gy_reg44 <- mkReg(0);
	Reg#(Int#(32)) gy_reg45 <- mkReg(0);
	Reg#(Int#(32)) gy_reg46 <- mkReg(0);	
	Reg#(Int#(32)) gy_reg47 <- mkReg(0);

	Reg#(Int#(32)) gy_reg51 <- mkReg(5);
	Reg#(Int#(32)) gy_reg52 <- mkReg(30);
	Reg#(Int#(32)) gy_reg53 <- mkReg(75);
	Reg#(Int#(32)) gy_reg54 <- mkReg(100);
	Reg#(Int#(32)) gy_reg55 <- mkReg(75);
	Reg#(Int#(32)) gy_reg56 <- mkReg(30);	
	Reg#(Int#(32)) gy_reg57 <- mkReg(5);

	Reg#(Int#(32)) gy_reg61 <- mkReg(4);
	Reg#(Int#(32)) gy_reg62 <- mkReg(24);
	Reg#(Int#(32)) gy_reg63 <- mkReg(60);
	Reg#(Int#(32)) gy_reg64 <- mkReg(80);
	Reg#(Int#(32)) gy_reg65 <- mkReg(60);
	Reg#(Int#(32)) gy_reg66 <- mkReg(24);	
	Reg#(Int#(32)) gy_reg67 <- mkReg(4);

	Reg#(Int#(32)) gy_reg71 <- mkReg(1);
	Reg#(Int#(32)) gy_reg72 <- mkReg(6);
	Reg#(Int#(32)) gy_reg73 <- mkReg(15);
	Reg#(Int#(32)) gy_reg74 <- mkReg(20);
	Reg#(Int#(32)) gy_reg75 <- mkReg(15);
	Reg#(Int#(32)) gy_reg76 <- mkReg(6);	
   	Reg#(Int#(32)) gy_reg77 <- mkReg(1);	
   	Reg#(Int#(32)) threshold <- mkReg(70);
  	
  	FIFOF#(Bit#(8)) rowBuffer_1 <- mkSizedFIFOF(3000);  //PAY ATTENTION, SUBJECT to CHANGE
   	FIFOF#(Bit#(8)) rowBuffer_2 <- mkSizedFIFOF(3000);  //PAY ATTENTION, SUBJECT to CHANGE
   	FIFOF#(Bit#(8)) rowBuffer_3 <- mkSizedFIFOF(3000);  //PAY ATTENTION, SUBJECT to CHANGE
  	FIFOF#(Bit#(8)) rowBuffer_4 <- mkSizedFIFOF(3000);  //PAY ATTENTION, SUBJECT to CHANGE
   	FIFOF#(Bit#(8)) rowBuffer_5 <- mkSizedFIFOF(3000);  //PAY ATTENTION, SUBJECT to CHANGE
   	FIFOF#(Bit#(8)) rowBuffer_6 <- mkSizedFIFOF(3000);  //PAY ATTENTION, SUBJECT to CHANGE
  	
  	Reg#(Bool) windowReady <- mkReg(False); //issue to other rules that data of 9 pixel are ready
   	Reg#(Bool) windowSlide <- mkReg(False); // other rules set this bit to issue they need new window data
   	Reg#(Bool) window_Initial <- mkReg(False);
   	Reg#(Bool) rowBuffer_inital <- mkReg(True);
  	Reg#(Bit#(32)) bufferRowCount <- mkReg(0);
	Reg#(Bool) sobelConvert <- mkReg(False);
	
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
			gy_reg11 <= -1;gy_reg12 <= -6;gy_reg13 <= -15;gy_reg14 <= -20;gy_reg15 <= -15;gy_reg16 <= -6;gy_reg17 <= -1;
			gy_reg21 <= -4;gy_reg22 <= -24;gy_reg23 <= -60;gy_reg24 <= -80;gy_reg25 <= -60;gy_reg26 <= -24;gy_reg27 <= -4;
			gy_reg31 <= -5;gy_reg32 <= -30;gy_reg33 <= -75;gy_reg34 <= -100;gy_reg35 <= -75;gy_reg36 <= -30;gy_reg37 <= -5;
			gy_reg41 <= 0;gy_reg42 <= 0;gy_reg43 <= 0;gy_reg44 <= 0;gy_reg45 <= 0;gy_reg46 <= 0;gy_reg47 <= 0;
			gy_reg51 <= 5;gy_reg52 <= 30;gy_reg53 <= 75;gy_reg54 <= 100;gy_reg55 <= 75;gy_reg56 <= 30;gy_reg57 <= 5;
			gy_reg61 <= 4;gy_reg62 <= 24;gy_reg63 <= 60;gy_reg64 <= 80;gy_reg65 <= 60;gy_reg66 <= 24;gy_reg67 <= 4;
			gy_reg71 <= 1;gy_reg72 <= 6;gy_reg73 <= 15;gy_reg74 <= 20;gy_reg75 <= 15;gy_reg76 <= 6;gy_reg77 <= 1;
		
			gx_reg11 <= -1;gx_reg12 <= -4;gx_reg13 <= -5;gx_reg14 <= 0;gx_reg15 <= 5;gx_reg16 <= 4;gx_reg17 <= 1;
			gx_reg21 <= -6;gx_reg22 <= -24;gx_reg23 <= -30;gx_reg24 <= 0;gx_reg25 <= 30;gx_reg26 <= 24;gx_reg27 <= 6;
			gx_reg31 <= -15;gx_reg32 <= -60;gx_reg33 <= -75;gx_reg34 <= 0;gx_reg35 <= 75;gx_reg36 <= 60;gx_reg37 <= 15;
			gx_reg41 <= -20;gx_reg42 <= -80;gx_reg43 <= -100;gx_reg44 <= 0;gx_reg45 <= 100;gx_reg46 <= 80;gx_reg47 <= 20;
			gx_reg51 <= -15;gx_reg52 <= -60;gx_reg53 <= -75;gx_reg54 <= 0;gx_reg55 <= 75;gx_reg56 <= 60;gx_reg57 <= 15;
			gx_reg61 <= -6;gx_reg62 <= -24;gx_reg63 <= -30;gx_reg64 <= 0;gx_reg65 <= 30;gx_reg66 <= 24;gx_reg67 <= 6;
			gx_reg71 <= -1;gx_reg72 <= -4;gx_reg73 <= -5;gx_reg74 <= 0;gx_reg75 <= 5;gx_reg76 <= 4;gx_reg77 <= 1;
			threshold <= 70;
		end
		else if(kernel_size_read==5) begin
			gy_reg11 <= 0;gy_reg12 <= 0;gy_reg13 <= 0;gy_reg14 <= 0;gy_reg15 <= 0;gy_reg16 <= 0;gy_reg17 <= 0;
			gy_reg21 <= 0;gy_reg22 <= -1;gy_reg23 <= -4;gy_reg24 <= -6;gy_reg25 <= -4;gy_reg26 <= -1;gy_reg27 <= 0;
			gy_reg31 <= 0;gy_reg32 <= -2;gy_reg33 <= -8;gy_reg34 <= -12;gy_reg35 <= -8;gy_reg36 <= -2;gy_reg37 <= 0;
			gy_reg41 <= 0;gy_reg42 <= 0;gy_reg43 <= 0;gy_reg44 <= 0;gy_reg45 <= 0;gy_reg46 <= 0;gy_reg47 <= 0;
			gy_reg51 <= 0;gy_reg52 <= 2;gy_reg53 <= 8;gy_reg54 <= 12;gy_reg55 <= 8;gy_reg56 <= 2;gy_reg57 <= 0;
			gy_reg61 <= 0;gy_reg62 <= 1;gy_reg63 <= 4;gy_reg64 <= 6;gy_reg65 <= 4;gy_reg66 <= 1;gy_reg67 <= 0;
			gy_reg71 <= 0;gy_reg72 <= 0;gy_reg73 <= 0;gy_reg74 <= 0;gy_reg75 <= 0;gy_reg76 <= 0;gy_reg77 <= 0;
			
			gx_reg11 <= 0;gx_reg12 <= 0;gx_reg13 <= 0;gx_reg14 <= 0;gx_reg15 <= 0;gx_reg16 <= 0;gx_reg17 <= 0;
			gx_reg21 <= 0;gx_reg22 <= -1;gx_reg23 <= -2;gx_reg24 <= 0;gx_reg25 <= 2;gx_reg26 <= 1;gx_reg27 <= 0;
			gx_reg31 <= 0;gx_reg32 <= -4;gx_reg33 <= -8;gx_reg34 <= 0;gx_reg35 <= 8;gx_reg36 <= 4;gx_reg37 <= 0;
			gx_reg41 <= 0;gx_reg42 <= -6;gx_reg43 <= -12;gx_reg44 <= 0;gx_reg45 <= 12;gx_reg46 <= 6;gx_reg47 <= 0;
			gx_reg51 <= 0;gx_reg52 <= -4;gx_reg53 <= -8;gx_reg54 <= 0;gx_reg55 <= 8;gx_reg56 <= 4;gx_reg57 <= 0;
			gx_reg61 <= 0;gx_reg62 <= -1;gx_reg63 <= -2;gx_reg64 <= 0;gx_reg65 <= 2;gx_reg66 <= 1;gx_reg67 <= 0;
			gx_reg71 <= 0;gx_reg72 <= 0;gx_reg73 <= 0;gx_reg74 <= 0;gx_reg75 <= 0;gx_reg76 <= 0;gx_reg77 <= 0;
			threshold <= 50;
		end
		else if(kernel_size_read==3)begin
			gy_reg11 <= 0;gy_reg12 <= 0;gy_reg13 <= 0;gy_reg14 <= 0;gy_reg15 <= 0;gy_reg16 <= 0;gy_reg17 <= 0;
			gy_reg21 <= 0;gy_reg22 <= 0;gy_reg23 <= 0;gy_reg24 <= 0;gy_reg25 <= 0;gy_reg26 <= 0;gy_reg27 <= 0;
			gy_reg31 <= 0;gy_reg32 <= 0;gy_reg33 <= -1;gy_reg34 <= -2;gy_reg35 <= -1;gy_reg36 <= 0;gy_reg37 <= 0;
			gy_reg41 <= 0;gy_reg42 <= 0;gy_reg43 <= 0;gy_reg44 <= 0;gy_reg45 <= 0;gy_reg46 <= 0;gy_reg47 <= 0;
			gy_reg51 <= 0;gy_reg52 <= 0;gy_reg53 <= 1;gy_reg54 <= 2;gy_reg55 <= 1;gy_reg56 <= 0;gy_reg57 <= 0;
			gy_reg61 <= 0;gy_reg62 <= 0;gy_reg63 <= 0;gy_reg64 <= 0;gy_reg65 <= 0;gy_reg66 <= 0;gy_reg67 <= 0;
			gy_reg71 <= 0;gy_reg72 <= 0;gy_reg73 <= 0;gy_reg74 <= 0;gy_reg75 <= 0;gy_reg76 <= 0;gy_reg77 <= 0;
			
			gx_reg11 <= 0;gx_reg12 <= 0;gx_reg13 <= 0;gx_reg14 <= 0;gx_reg15 <= 0;gx_reg16 <= 0;gx_reg17 <= 0;
			gx_reg21 <= 0;gx_reg22 <= 0;gx_reg23 <= 0;gx_reg24 <= 0;gx_reg25 <= 0;gx_reg26 <= 0;gx_reg27 <= 0;
			gx_reg31 <= 0;gx_reg32 <= 0;gx_reg33 <= -1;gx_reg34 <= 0;gx_reg35 <= 1;gx_reg36 <= 0;gx_reg37 <= 0;
			gx_reg41 <= 0;gx_reg42 <= 0;gx_reg43 <= -2;gx_reg44 <= 0;gx_reg45 <= 2;gx_reg46 <= 0;gx_reg47 <= 0;
			gx_reg51 <= 0;gx_reg52 <= 0;gx_reg53 <= -1;gx_reg54 <= 0;gx_reg55 <= 1;gx_reg56 <= 0;gx_reg57 <= 0;
			gx_reg61 <= 0;gx_reg62 <= 0;gx_reg63 <= 0;gx_reg64 <= 0;gx_reg65 <= 0;gx_reg66 <= 0;gx_reg67 <= 0;
			gx_reg71 <= 0;gx_reg72 <= 0;gx_reg73 <= 0;gx_reg74 <= 0;gx_reg75 <= 0;gx_reg76 <= 0;gx_reg77 <= 0;
			threshold <= 30;
		end
		init_image_parameter_finish <= True;
  	endrule
  	
  	/* Initialize row buffer at the first time, since slide window operate correctly only if row buffer 1 and row buffer 2 are already filled */
   	Reg#(Bit#(32)) count_FIFOchop <- mkReg(0); //Use only a part of FIFO depending on image length
   	rule rowBufferInital if(rowBuffer_inital == True && rowBuffer_1.notFull() == True && 
   				rowBuffer_2.notFull() == True && init_image_parameter_finish == True &&
   				count_FIFOchop <= image_length-kernel_size -1 );
   				
	   	rowBuffer_1.enq(0); //Fill waste values until full
		rowBuffer_2.enq(0); //Fill waste values until full
	   	rowBuffer_3.enq(0); //Fill waste values until full
		rowBuffer_4.enq(0); //Fill waste values until full
	   	rowBuffer_5.enq(0); //Fill waste values until full
		rowBuffer_6.enq(0); //Fill waste values until full
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
	Reg#(Bit#(8)) reg11 <- mkReg(0);
	Reg#(Bit#(8)) reg12 <- mkReg(0);
	Reg#(Bit#(8)) reg13 <- mkReg(0);
	Reg#(Bit#(8)) reg14 <- mkReg(0);
	Reg#(Bit#(8)) reg15 <- mkReg(0);
	Reg#(Bit#(8)) reg16 <- mkReg(0);   
	Reg#(Bit#(8)) reg17 <- mkReg(0);

	Reg#(Bit#(8)) reg21 <- mkReg(0);
	Reg#(Bit#(8)) reg22 <- mkReg(0);
	Reg#(Bit#(8)) reg23 <- mkReg(0);
	Reg#(Bit#(8)) reg24 <- mkReg(0);
	Reg#(Bit#(8)) reg25 <- mkReg(0);
	Reg#(Bit#(8)) reg26 <- mkReg(0);   
	Reg#(Bit#(8)) reg27 <- mkReg(0);

	Reg#(Bit#(8)) reg31 <- mkReg(0);
	Reg#(Bit#(8)) reg32 <- mkReg(0);
	Reg#(Bit#(8)) reg33 <- mkReg(0);
	Reg#(Bit#(8)) reg34 <- mkReg(0);
	Reg#(Bit#(8)) reg35 <- mkReg(0);
	Reg#(Bit#(8)) reg36 <- mkReg(0);   
	Reg#(Bit#(8)) reg37 <- mkReg(0);

	Reg#(Bit#(8)) reg41 <- mkReg(0);
	Reg#(Bit#(8)) reg42 <- mkReg(0);
	Reg#(Bit#(8)) reg43 <- mkReg(0);
	Reg#(Bit#(8)) reg44 <- mkReg(0);
	Reg#(Bit#(8)) reg45 <- mkReg(0);
	Reg#(Bit#(8)) reg46 <- mkReg(0);   
	Reg#(Bit#(8)) reg47 <- mkReg(0);

	Reg#(Bit#(8)) reg51 <- mkReg(0);
	Reg#(Bit#(8)) reg52 <- mkReg(0);
	Reg#(Bit#(8)) reg53 <- mkReg(0);
	Reg#(Bit#(8)) reg54 <- mkReg(0);
	Reg#(Bit#(8)) reg55 <- mkReg(0);
	Reg#(Bit#(8)) reg56 <- mkReg(0);   
	Reg#(Bit#(8)) reg57 <- mkReg(0);

	Reg#(Bit#(8)) reg61 <- mkReg(0);
	Reg#(Bit#(8)) reg62 <- mkReg(0);
	Reg#(Bit#(8)) reg63 <- mkReg(0);
	Reg#(Bit#(8)) reg64 <- mkReg(0);
	Reg#(Bit#(8)) reg65 <- mkReg(0);
	Reg#(Bit#(8)) reg66 <- mkReg(0);   
	Reg#(Bit#(8)) reg67 <- mkReg(0);

	Reg#(Bit#(8)) reg71 <- mkReg(0);
	Reg#(Bit#(8)) reg72 <- mkReg(0);
	Reg#(Bit#(8)) reg73 <- mkReg(0);
	Reg#(Bit#(8)) reg74 <- mkReg(0);
	Reg#(Bit#(8)) reg75 <- mkReg(0);
	Reg#(Bit#(8)) reg76 <- mkReg(0);   
	Reg#(Bit#(8)) reg77 <- mkReg(0); 
	
	Reg#(Bool) slide <- mkReg(False);    //command register
	Reg#(Bool) slide_finish <- mkReg(False);    //status register	
	Reg#(Bit#(32)) slide_position <- mkReg(0); //Count from 0
	Reg#(Bit#(8)) state_temp <- mkReg(0);
	
	Reg#(Bool) windowBuffer_once_inital <- mkReg(False);    //status register	
	rule windowBuffer_inital if(window_Initial == True && rowBuffer_inital == False );
	  	//$display("Test Here 5");
	   	reg11 <= reg12; 
		reg12 <= reg13;
		reg13 <= reg14;
		reg14 <= reg15;
		reg15 <= reg16;
		reg16 <= reg17;
		reg17 <= rowBuffer_1.first; rowBuffer_1.deq; 
		rowBuffer_1.enq(reg21);		
	   	//rowBuffer_1.enq(reg21); //$display("Test Here 6");
		reg21 <= reg22;
		reg22 <= reg23;
		reg23 <= reg24;
		reg24 <= reg25;
		reg25 <= reg26;
		reg26 <= reg27;
		reg27 <= rowBuffer_2.first(); rowBuffer_2.deq;
		rowBuffer_2.enq(reg31); //$display("Test Here 7");
		reg31 <= reg32;
		reg32 <= reg33;
		reg33 <= reg34;
		reg34 <= reg35;
		reg35 <= reg36;
		reg36 <= reg37;
		reg37 <= rowBuffer_3.first(); rowBuffer_3.deq;
		rowBuffer_3.enq(reg41); //$display("Test Here 8");
		reg41 <= reg42;
		reg42 <= reg43;
		reg43 <= reg44;
		reg44 <= reg45;
		reg45 <= reg46;
		reg46 <= reg47;
		reg47 <= rowBuffer_4.first(); rowBuffer_4.deq;
		rowBuffer_4.enq(reg51); //$display("Test Here 9");
		reg51 <= reg52;
		reg52 <= reg53;
		reg53 <= reg54;
		reg54 <= reg55;
		reg55 <= reg56;
		reg56 <= reg57;
		reg57 <= rowBuffer_5.first(); rowBuffer_5.deq;
		rowBuffer_5.enq(reg61); //$display("Test Here 10");
		reg61 <= reg62;
		reg62 <= reg63;
		reg63 <= reg64;
		reg64 <= reg65;
		reg65 <= reg66;
		reg66 <= reg67;
		reg67 <= rowBuffer_6.first(); rowBuffer_6.deq;
		rowBuffer_6.enq(reg71);
		reg71 <= reg72;
		reg72 <= reg73;
		reg73 <= reg74;
		reg74 <= reg75;
		reg75 <= reg76;
		reg76 <= reg77;
		reg77 <= buffer_8bit.first(); buffer_8bit.deq; //PAY ATTENTION, REPLACE "testslideWindow" WITH "buffer_8bit" to get data via AXI
		//$display("%d Reg77", reg77);
		bufferRowCount <= bufferRowCount + 1;
		slide_finish <= True;
		if( slide_position < image_length)
			slide_position <= slide_position + 1;
		else
			slide_position <= 1;
			
		if(bufferRowCount >= image_length*(kernel_size-1) + kernel_size -1 && windowBuffer_once_inital == False) begin //512+ 512+ 9 //PAY ATTENTION  change
			//window_Initial <= False;
			windowBuffer_once_inital <= True;
			sobelConvert <= True; //command
			//slide_finish <= False; //Reset slide status
		end
		
		else if(bufferRowCount >= image_length*image_width-1) begin
			$display("Test Here 99");
			window_Initial <= False;
			sobelConvert <= False;
			slide <= False;
		end
		//$display("slide position %d pixel read %d",slide_position,bufferRowCount);
	endrule
	
	  
 	
 	
	FIFOF#(Bit#(128)) buffer_out <- mkSizedFIFOF(100);
   	Reg#(Bit#(128)) out_hold <- mkReg(0);
   	Reg#(Bit#(8)) out_count <- mkReg(0);
	Reg#(Bit#(8)) sobelState <- mkReg(0);
   	rule sobelOperator(sobelConvert == True && slide_position != 1 &&  slide_position != 2 &&  
			slide_position != 3 &&  slide_position != 4 &&  slide_position != 5 &&  slide_position != 6);
   		slide_finish <= False; //Reset slide status
		
		Int#(32) sum_1 ;
		Int#(32) sum_2 ;
		Int#(32) sum_12;
		Bit#(8) outPixel;		

		sum_1 = signExtend(gx_reg11*unpack(zExtend(reg11)) + gx_reg12*unpack(zExtend(reg12)) + gx_reg13*unpack(zExtend(reg13))+ gx_reg14*unpack(zExtend(reg14)) + 			gx_reg15*unpack(zExtend(reg15)) + gx_reg16*unpack(zExtend(reg16))+ gx_reg17*unpack(zExtend(reg17)) +
		
		gx_reg21*unpack(zExtend(reg21)) + gx_reg22*unpack(zExtend(reg22)) + gx_reg23*unpack(zExtend(reg23))+ gx_reg24*unpack(zExtend(reg24)) + 
		gx_reg25*unpack(zExtend(reg25)) + gx_reg26*unpack(zExtend(reg26))+ gx_reg27*unpack(zExtend(reg27)) +
		
		gx_reg31*unpack(zExtend(reg31)) + gx_reg32*unpack(zExtend(reg32)) + gx_reg33*unpack(zExtend(reg33))+ gx_reg34*unpack(zExtend(reg34)) + 
		gx_reg35*unpack(zExtend(reg35)) + gx_reg36*unpack(zExtend(reg36))+ gx_reg37*unpack(zExtend(reg37)) +
		
		gx_reg41*unpack(zExtend(reg41)) + gx_reg42*unpack(zExtend(reg42)) + gx_reg43*unpack(zExtend(reg43))+ gx_reg44*unpack(zExtend(reg44)) + 
		gx_reg45*unpack(zExtend(reg45)) + gx_reg46*unpack(zExtend(reg46))+ gx_reg47*unpack(zExtend(reg47)) +
		
		gx_reg51*unpack(zExtend(reg51)) + gx_reg52*unpack(zExtend(reg52)) + gx_reg53*unpack(zExtend(reg53))+ gx_reg54*unpack(zExtend(reg54)) + 
		gx_reg55*unpack(zExtend(reg55)) + gx_reg56*unpack(zExtend(reg56))+ gx_reg57*unpack(zExtend(reg57)) +
		
		gx_reg61*unpack(zExtend(reg61)) + gx_reg62*unpack(zExtend(reg62)) + gx_reg63*unpack(zExtend(reg63))+ gx_reg64*unpack(zExtend(reg64)) + 
		gx_reg65*unpack(zExtend(reg65)) + gx_reg66*unpack(zExtend(reg66))+ gx_reg67*unpack(zExtend(reg67)) +
		
		gx_reg71*unpack(zExtend(reg71)) + gx_reg72*unpack(zExtend(reg72)) + gx_reg73*unpack(zExtend(reg73))+ gx_reg74*unpack(zExtend(reg74)) + 
		gx_reg75*unpack(zExtend(reg75)) + gx_reg76*unpack(zExtend(reg76))+ gx_reg77*unpack(zExtend(reg77)));
		
		
		sum_2 = signExtend(gy_reg11*unpack(zExtend(reg11)) + gy_reg12*unpack(zExtend(reg12)) + gy_reg13*unpack(zExtend(reg13))+ gy_reg14*unpack(zExtend(reg14)) + 			gy_reg15*unpack(zExtend(reg15)) + gy_reg16*unpack(zExtend(reg16))+ gy_reg17*unpack(zExtend(reg17)) +
		
		gy_reg21*unpack(zExtend(reg21)) + gy_reg22*unpack(zExtend(reg22)) + gy_reg23*unpack(zExtend(reg23))+ gy_reg24*unpack(zExtend(reg24)) + 
		gy_reg25*unpack(zExtend(reg25)) + gy_reg26*unpack(zExtend(reg26))+ gy_reg27*unpack(zExtend(reg27)) +
		
		gy_reg31*unpack(zExtend(reg31)) + gy_reg32*unpack(zExtend(reg32)) + gy_reg33*unpack(zExtend(reg33))+ gy_reg34*unpack(zExtend(reg34)) + 
		gy_reg35*unpack(zExtend(reg35)) + gy_reg36*unpack(zExtend(reg36))+ gy_reg37*unpack(zExtend(reg37)) +
		
		gy_reg41*unpack(zExtend(reg41)) + gy_reg42*unpack(zExtend(reg42)) + gy_reg43*unpack(zExtend(reg43))+ gy_reg44*unpack(zExtend(reg44)) + 
		gy_reg45*unpack(zExtend(reg45)) + gy_reg46*unpack(zExtend(reg46))+ gy_reg47*unpack(zExtend(reg47)) +
		
		gy_reg51*unpack(zExtend(reg51)) + gy_reg52*unpack(zExtend(reg52)) + gy_reg53*unpack(zExtend(reg53))+ gy_reg54*unpack(zExtend(reg54)) + 
		gy_reg55*unpack(zExtend(reg55)) + gy_reg56*unpack(zExtend(reg56))+ gy_reg57*unpack(zExtend(reg57)) +
		
		gy_reg61*unpack(zExtend(reg61)) + gy_reg62*unpack(zExtend(reg62)) + gy_reg63*unpack(zExtend(reg63))+ gy_reg64*unpack(zExtend(reg64)) + 
		gy_reg65*unpack(zExtend(reg65)) + gy_reg66*unpack(zExtend(reg66))+ gy_reg67*unpack(zExtend(reg67)) +
		
		gy_reg71*unpack(zExtend(reg71)) + gy_reg72*unpack(zExtend(reg72)) + gy_reg73*unpack(zExtend(reg73))+ gy_reg74*unpack(zExtend(reg74)) + 
		gy_reg75*unpack(zExtend(reg75)) + gy_reg76*unpack(zExtend(reg76))+ gy_reg77*unpack(zExtend(reg77)));
		
		if( sum_1 < 0) begin
   			sum_1 = sum_1*-1;
   		end
   		if( sum_2 < 0) begin
   			sum_2 = sum_2*-1;
   		end
   		
   		sum_12 = sum_1 + sum_2;
		
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
		//$display("Finish Filter read input pixel %d, output pixel value is %d, slide position",bufferRowCount,outPixel,slide_position); 
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
