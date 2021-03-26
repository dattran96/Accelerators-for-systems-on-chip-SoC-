package AXIFConverter;

import BlueAXI::*;
import GetPut::*;
import BUtils :: *;
import FixedPoint :: * ;
import FIFOF :: *;


interface AXIFConverter;
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
module mkAXIFConverter(AXIFConverter);
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
	Reg#(Bit#(64)) image_size <- mkReg(0);
    
	//Convert constant
    	//FixedPoint#(9,10) red_coff = 0.33;
    	//FixedPoint#(9,10) green_coff = 0.59;
    	//FixedPoint#(9,10) blue_coff = 0.11;
	FixedPoint#(9,10) red_coff = 0.299;
    	FixedPoint#(9,10) green_coff = 0.587;
    	FixedPoint#(9,10) blue_coff = 0.114;

    	//FIFO 64 Bitweise
    	FIFOF#(Bit#(128)) red_buff <- mkSizedFIFOF(512);
    	FIFOF#(Bit#(128)) blue_buff <- mkSizedFIFOF(512);
    	FIFOF#(Bit#(128)) green_buff <- mkSizedFIFOF(512);

    	//Counter registers
    	Reg#(Bit#(64)) ddr_write_count <- mkReg(0);
	Reg#(Bit#(64)) red_count <- mkReg(0);
	Reg#(Bit#(64)) green_count <- mkReg(0);
	Reg#(Bit#(64)) blue_count <- mkReg(0);
	Reg#(Bit#(64)) red_buff_queue <- mkReg(0);
	Reg#(Bit#(64)) green_buff_queue <- mkReg(0);
	Reg#(Bit#(64)) blue_buff_queue <- mkReg(0);	
	
	//Control registers
	Reg#(Bit#(64)) color_state <- mkReg(0);
    	Reg#(Bit#(64)) enq_state <- mkReg(0);
    	Reg#(Bool) start_write_request <- mkReg(False);
    	Reg#(Bool) converting_flag <- mkReg(False);
	Reg#(UInt#(8)) burst_length <- mkReg(15);
	Reg#(Bit#(64)) transfer_threshold <- mkReg(1);	


	//Read Slave channel 
	rule handleReadRequest;
        	let r <- slave_read.request.get();
        	if(r.addr[5:0] == 0) begin
            		slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(address_image_1)), resp: OKAY});
        	end
        	else if(r.addr[5:0] == 8) begin
            		slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(address_image_2)), resp: OKAY});
        	end 
        	else if(r.addr[5:0] == 16) begin
            		slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(start)), resp: OKAY});
        	end
       		else if(r.addr[5:0] == 24) begin
            		slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(conversion_finished)), resp: OKAY});
        	end
        	else if(r.addr[5:0] == 32) begin 
           		slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(image_size)), resp: OKAY});
        	end 
    	endrule

	rule handleWriteRequest;
		let r <- slave_write.request.get();
		if(r.addr[5:0] == 0) begin 
			address_image_1 <= r.data;
			slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
		end
		else if(r.addr[5:0] == 8) begin
			address_image_2 <= r.data;
			slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
		end 
		else if(r.addr[5:0] == 16) begin
			start <= r.data;
			$display("image size receive %d", image_size);
			conversion_finished <= 0;
			start_write_request <= True;
			red_buff.clear();
			green_buff.clear();
			blue_buff.clear();
			red_count <= 0;
			green_count <= 0;
			blue_count <= 0;
			red_buff_queue <= 0;
			green_buff_queue <= 0;
			blue_buff_queue <= 0;
			ddr_write_count <= 0;	
			slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
		end
		else if(r.addr[5:0] == 32) begin
			image_size <= r.data;
			transfer_threshold <= r.data - 16*zExtend(pack(burst_length)) - 16;
			slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
		end
	endrule

	function UInt#(8) burstLengthBarrierCrossing (Bit#(64) curr_addr,UInt#(8) init_burst_length);
		UInt#(64) allowed_byte = 4080 - unpack(zExtend(curr_addr[11:0]));
		allowed_byte = ((allowed_byte + 16) >> 4) - 1;
		if(truncate(allowed_byte) > init_burst_length) begin
			return init_burst_length;
		end
		else begin
			return truncate(allowed_byte);
		end
	endfunction  


	Reg#(Bit#(64)) red_count_test <- mkReg(0);
	Reg#(Bit#(64)) green_count_test <- mkReg(0);
	Reg#(Bit#(64)) blue_count_test <- mkReg(0);
	rule readRequest if( start != 0 && conversion_finished == 0);       
		if(color_state == 0) begin						
			if(red_count <= image_size) begin 
				//$display("Master_IP: Read red request %d, burst", red_count);
				//$display("");
				
				Bit#(64) curr_addr = address_image_1 + red_count;
                 		UInt#(8) curr_burst = burstLengthBarrierCrossing(curr_addr, burst_length);
                 		
                 		Bit#(64) image_range = red_count + 16*zExtend(pack(curr_burst))+16;
				if(image_range > image_size) begin 
					Bit#(64) temp = (image_size - red_count) >> 4;
					curr_burst = truncate(unpack(temp));
					
				end
        	        	
        	        	axi4_read_data(master_read, curr_addr, curr_burst);
                		red_count <= red_count + 16*zExtend(pack(curr_burst))+16;
                		red_buff_queue <= red_buff_queue + 1;
                		
                		//red_count_test <= red_count_test + 1;
                		
                		//$display("Master_IP: Red -> current burst %d, red_buff_queue %d", curr_burst, red_count_test);
				//$display("");
                		
                		if(green_count <= image_size) 
                			color_state <= 1;
                		else if(blue_count <= image_size)
                			color_state <= 2;
                	end
        	end
        	else if(color_state == 1) begin
        		if(green_count <= image_size) begin
				//--$display("Master_IP: Read green request %d", green_count);
				//--$display("");
				Bit#(64) curr_addr = address_image_1 + image_size + green_count;
                 		UInt#(8) curr_burst = burstLengthBarrierCrossing(curr_addr, burst_length);
                 		//---$display("Master_IP: Current burst green %d, address: %d", curr_burst, curr_addr);
				//---$display("");
				
				Bit#(64) image_range = green_count + 16*zExtend(pack(curr_burst))+16;
				if(image_range > image_size) begin 
					Bit#(64) temp = (image_size - green_count) >> 4;
					curr_burst = truncate(unpack(temp));
					
				end
				
        	        	axi4_read_data(master_read, curr_addr, curr_burst);
                		green_count <= green_count + 16*zExtend(pack(curr_burst))+16;
              	 		green_buff_queue <= green_buff_queue + 1;
              	 		
              	 		
              	 		//$display("Master_IP: Green -> current burst %d, green_buff_queue %d", curr_burst, green_buff_queue);
				//$display("");
              	 		if(blue_count <= image_size)
              	 			color_state <= 2;
              	 		else if(red_count <= image_size)
              	 			color_state <= 0;
              	 	end
       		end else begin
       			if(blue_count <= image_size) begin
				//--$display("Master_IP: read blue request %d", blue_count);
				//--$display("");
				Bit#(64) curr_addr = address_image_1 + 2*image_size + blue_count;
                 		UInt#(8) curr_burst = burstLengthBarrierCrossing(curr_addr, burst_length);
                 		//--$display("Master_IP: Current burst blue %d", curr_burst);
				//--$display("");
				
				Bit#(64) image_range = blue_count + 16*zExtend(pack(curr_burst))+16;
				if(image_range > image_size) begin 
					Bit#(64) temp = (image_size - blue_count) >> 4;
					curr_burst = truncate(unpack(temp));
				end
				
        	        	axi4_read_data(master_read, curr_addr, curr_burst);
                		blue_count <= blue_count + 16*zExtend(pack(curr_burst))+16;
                		blue_buff_queue <= blue_buff_queue + 1;
                		
                		//$display("Master_IP: Blue -> current burst %d, blue_buff_queue %d", curr_burst, blue_buff_queue);
				//$display("");
                		if(red_count <= image_size)
                			color_state <= 0;
                		else if(green_count <= image_size)
                			color_state <= 1;
                	end
        	end

		if(red_count > image_size && green_count > image_size && blue_count > image_size) begin
			start <= 0;
			red_count <= 0; 
			green_count <= 0;
			blue_count <= 0;
		end
    	endrule

	rule rgbDataGet;
        	let r <- master_read.response.get();

        	if(enq_state == 0 && red_buff_queue > 0) begin
        		//blue_count_test <= 0;
        		//red_count_test <= red_count_test + 1;
                	red_buff.enq(r.data);
			if(r.last== True) begin
			
                		if(green_buff_queue > 0) 
                			enq_state <= 1;
                		else if(blue_buff_queue > 0)
                			enq_state <= 2;
                			
                		red_buff_queue <= red_buff_queue - 1;
                		
                		//$display("Master_IP: Red -> enq_buff %d",red_count_test);
				//$display("");
				
				//$display("Master_IP: Put red_buff finished, queue %d", red_buff_queue);
				//$display("");
			end
       	 	end
        	else if(enq_state == 1 && green_buff_queue > 0) begin
        		//red_count_test <= 0;
                	green_buff.enq(r.data);
                	//green_count_test <= green_count_test + 1;
			if(r.last==True) begin
				if(blue_buff_queue > 0)
                			enq_state <= 2;
                		else if(red_buff_queue > 0)
                			enq_state <= 0;
                			
                		green_buff_queue <= green_buff_queue - 1;
                		
                		//$display("Master_IP: Green -> enq_buff %d",green_count_test);
				//$display("");
				
				//$display("Master_IP: Put green_buff finished, queue: %d", green_buff_queue);
				//$display("");
			end
        	end else if(blue_buff_queue > 0) begin
                	blue_buff.enq(r.data);
                	//blue_count_test <= blue_count_test + 1;
                	//green_count_test <= 0;
			if(r.last==True) begin
				if(red_buff_queue > 0)
                			enq_state <= 0;
                		else if(green_buff_queue > 0)
                			enq_state <= 1;
                		
                		//$display("Master_IP: Blue -> enq_buff %d",blue_count_test);
				//$display("");
				
                		blue_buff_queue <= blue_buff_queue - 1;
                		
                		//$display("Master_IP: Put blue_buff finished, queue: %d", blue_buff_queue);
				//$display("");
			end
        	end
    	endrule

	Reg#(Bool) wnext <- mkReg(True);
	Reg#(UInt#(8)) curr_burst_write <- mkReg(0);	
	rule writeRequest if(wnext == True && conversion_finished == 0 && start_write_request == True);
		
		
		//---$display("Master_IP: Write request %d", ddr_write_count);
		//---$display("");
		//---$display("Master_IP: transfer_threshold %d", transfer_threshold);
		//---$display("");
		if(ddr_write_count >= image_size)begin  
           		conversion_finished <= 1;
            		ddr_write_count <= 0;
            		start_write_request <= False;
            		//---$display("Master_IP: red_count last %d", red_count);
			//---$display("");
			//---$display("Master_IP: green_count last %d", green_count);
			//---$display("");
			//---$display("Master_IP: blue_count last %d", blue_count);
			//---$display("");
        	end
       		else begin
       			Bit#(64) curr_addr = address_image_2 + ddr_write_count;
                	UInt#(8) curr_burst = burstLengthBarrierCrossing(curr_addr, burst_length);
                	
                	Bit#(64) image_range = ddr_write_count + 16*zExtend(pack(curr_burst))+16;
			if(image_range > image_size) begin 
				Bit#(64) temp = (image_size - ddr_write_count) >> 4;
					curr_burst = truncate(unpack(temp));
			end
				
			axi4_write_addr(master_write, curr_addr, curr_burst);
            		ddr_write_count <= ddr_write_count + 16*zExtend(pack(curr_burst))+16;
            		curr_burst_write <= curr_burst;
			wnext <= False;
        	end
	endrule 

	function Bit#(8) pixelConvert(Bit#(8) red, Bit#(8) green, Bit#(8) blue);
                Int#(9) converted_pixel = fxptGetInt(fromUInt(unpack(red))*red_coff)
                                        + fxptGetInt(fromUInt(unpack(green))*green_coff)
                                        +fxptGetInt(fromUInt(unpack(blue))*blue_coff);
                return truncate(pack(converted_pixel));
        endfunction
	

	Reg#(UInt#(8)) beat_count <- mkReg(0);
	rule rgb2gray if(wnext == False);
		//$display("I am in RGB convert");
        	Bit#(128) red = red_buff.first();
       		Bit#(128) green = green_buff.first();
        	Bit#(128) blue = blue_buff.first();

		Bit#(128) gray_pixel;
		//$display("Master_IP: red: %d, green: %d, blue: %d", red, green, blue);
		//$display("");
		
		gray_pixel[127:120] = pixelConvert(red[127:120], green[127:120], blue[127:120]);
                gray_pixel[119:112] = pixelConvert(red[119:112], green[119:112], blue[119:112]);
                gray_pixel[111:104] = pixelConvert(red[111:104], green[111:104], blue[111:104]);
                gray_pixel[103:96] = pixelConvert(red[103:96], green[103:96], blue[103:96]);
                gray_pixel[95:88] = pixelConvert(red[95:88], green[95:88], blue[95:88]);
                gray_pixel[87:80] = pixelConvert(red[87:80], green[87:80], blue[87:80]);
                gray_pixel[79:72]  = pixelConvert(red[79:72], green[79:72], blue[79:72]);
                gray_pixel[71:64]   = pixelConvert(red[71:64], green[71:64], blue[71:64]);

        	gray_pixel[63:56] = pixelConvert(red[63:56], green[63:56], blue[63:56]);
        	gray_pixel[55:48] = pixelConvert(red[55:48], green[55:48], blue[55:48]);
       		gray_pixel[47:40] = pixelConvert(red[47:40], green[47:40], blue[47:40]);
        	gray_pixel[39:32] = pixelConvert(red[39:32], green[39:32], blue[39:32]);
        	gray_pixel[31:24] = pixelConvert(red[31:24], green[31:24], blue[31:24]);
        	gray_pixel[23:16] = pixelConvert(red[23:16], green[23:16], blue[23:16]);
        	gray_pixel[15:8]  = pixelConvert(red[15:8], green[15:8], blue[15:8]);
        	gray_pixel[7:0]   = pixelConvert(red[7:0], green[7:0], blue[7:0]);
			
		if(beat_count == curr_burst_write) begin
			axi4_write_data(master_write, gray_pixel, 16'hffff, True);
			wnext <= True;
			beat_count <= 0;
		end else begin 
        		axi4_write_data(master_write, gray_pixel, 16'hffff, False);
			beat_count <= beat_count + 1;
		end
        	red_buff.deq();
        	green_buff.deq();
        	blue_buff.deq();
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
