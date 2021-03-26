package AXIFConverter;

import BlueAXI::*;
import GetPut::*;
import BUtils :: *;
import FixedPoint :: * ;
import FIFOF :: *;


interface AXIFConverter;
    (* prefix = "S00_AXI" *)
    interface AXI4_Lite_Slave_Rd_Fab#(6, 64) s_read_fab;
    (* prefix = "S00_AXI" *)
    interface AXI4_Lite_Slave_Wr_Fab#(6, 64) s_write_fab;
    
	(* prefix = "M00_AXI" *)
	interface AXI4_Master_Rd_Fab#(64, 128, 16, 0) m_read_fab;
	(* prefix = "M00_AXI" *)
	interface AXI4_Master_Wr_Fab#(64, 128, 16, 0) m_write_fab;
endinterface

typedef enum {RED, GREEN, BLUE} ColorIndentifier deriving (Eq, Bits);

(*clock_prefix = "aclk", reset_prefix = "aresetn"*)
module mkAXIFConverter(AXIFConverter);
 	// Create interface

    AXI4_Lite_Slave_Rd#(6, 64) s_read <- mkAXI4_Lite_Slave_Rd(2);
    AXI4_Lite_Slave_Wr#(6, 64) s_write <- mkAXI4_Lite_Slave_Wr(2);

	AXI4_Master_Rd#(64, 128, 16, 0) m_read <- mkAXI4_Master_Rd(16,16,True);
	AXI4_Master_Wr#(64, 128, 16, 0) m_write <- mkAXI4_Master_Wr(16,16,16, True);

	//Configuration registers
	Reg#(Bit#(64)) rgb_address <- mkReg(0);
	Reg#(Bit#(64)) gray_address <- mkReg(0);
	Reg#(Bit#(64)) start <- mkReg(0);
	Reg#(Bit#(64)) finish_flag <- mkReg(0);
	Reg#(Bit#(64)) gray_size <- mkReg(0);
   
	//Control registers
    
    Reg#(Bool) start_write_request <- mkReg(False);
	Reg#(UInt#(8)) axi_burst_length <- mkReg(3);
	Reg#(Bit#(64)) gray_threshold <- mkReg(1);	
	Reg#(Bit#(64)) rgb_threshold <- mkReg(0);


	

	Reg#(Bit#(2)) read_state <- mkReg(pack(RED));
	rule readRGB if( start != 0 && finish_flag == 0); 
		case(read_state)
			pack(RED): begin
				    	axi4_read_data(m_read, rgb_address, axi_burst_length);
                		read_state <= pack(GREEN);
			end
			pack(GREEN): begin
        	        	axi4_read_data(m_read, rgb_address + gray_size, axi_burst_length);
              	 		read_state <= pack(BLUE);
			end
			pack(BLUE): begin
        	        	axi4_read_data(m_read, rgb_address + 2*gray_size, axi_burst_length);
                		read_state <= pack(RED);
			end
		endcase
				
		if(rgb_address >= rgb_threshold) begin   
			if(read_state == pack(BLUE)) begin
				rgb_address <= 0;
				start <= 0;
			end
        end
        else begin
			if(read_state == pack(BLUE)) begin 
				rgb_address <= rgb_address + 16*(zExtend(pack(axi_burst_length)) + 1);
			end 
        end 
    endrule
    	
    FIFOF#(Bit#(128)) red_pixel <- mkSizedFIFOF(512);
    FIFOF#(Bit#(128)) blue_pixel <- mkSizedFIFOF(512);
    FIFOF#(Bit#(128)) green_pixel <- mkSizedFIFOF(512);
	Reg#(Bit#(2)) add_buff_state <- mkReg(pack(RED));
	rule bufferPixel;
        	let r <- m_read.response.get();
        	if(add_buff_state == pack(RED)) begin
                	red_pixel.enq(r.data);
					if(r.last== True) begin 
                			add_buff_state <= pack(GREEN);
					end
       	 	end
        	else if(add_buff_state == pack(GREEN)) begin
                	green_pixel.enq(r.data);
					if(r.last==True) begin
                			add_buff_state <= pack(BLUE);
					end
        	end else if(add_buff_state == pack(BLUE)) begin
                	blue_pixel.enq(r.data);
					if(r.last==True) begin
                			add_buff_state <= pack(RED);
					end
        	end
    	endrule

	Reg#(Bool) write_control <- mkReg(True);
	Reg#(Bool) last_transfer <- mkReg(False);	
	rule grayWriteRequest if(write_control == True && finish_flag == 0 && start_write_request == True);
		if(gray_address >= gray_threshold)begin  
					finish_flag <= 1;
					gray_address <= 0;
            		start_write_request <= False;
        	end
       		else begin
					axi4_write_addr(m_write, gray_address, axi_burst_length);
            		Bit#(64) new_address = gray_address + 16*(zExtend(pack(axi_burst_length)) + 1);
					if(new_address >= gray_threshold) begin
						last_transfer <= True;
					end
					gray_address <= new_address;
					write_control <= False;
        	end
	endrule 

	FixedPoint#(9,10) red_weigh = 0.299;
    FixedPoint#(9,10) green_weigh = 0.587;
    FixedPoint#(9,10) blue_weigh = 0.114;
    
	Reg#(UInt#(8)) burst_counter <- mkReg(0);
	rule grayWrite if(write_control == False);
		Bit#(128) red_temp = red_pixel.first();
		Bit#(128) green_temp = green_pixel.first();
		Bit#(128) blue_temp = blue_pixel.first();
		
		Bit#(128) result_pixel = 0;
		FixedPoint#(9,10) fxpt_red = 0;  
		FixedPoint#(9,10) fxpt_green = 0;
		FixedPoint#(9,10) fxpt_blue = 0; 
		
		for(Integer i = 0; i <= 120; i = i + 8) begin
			Bit#(8) red = red_temp[i+7:i];
			Bit#(8) green = green_temp[i+7:i];
			Bit#(8) blue = blue_temp[i+7:i];
			
			fxpt_red = fromUInt(unpack(red));
			fxpt_green = fromUInt(unpack(green));
			fxpt_blue = fromUInt(unpack(blue));
			
			Int#(18) gray_value = fxptGetInt(fxptMult(fxpt_red,red_weigh))
                                 + fxptGetInt(fxptMult(fxpt_green,green_weigh))
                                 + fxptGetInt(fxptMult(fxpt_blue,blue_weigh));
                                 
            Bit#(8) gray_8bits = truncate(pack(gray_value));                    
			result_pixel[i+7:i] = gray_8bits;
		end
			
		if(burst_counter == axi_burst_length) begin
			axi4_write_data(m_write, result_pixel, 16'hffff, True);
			write_control <= True;
			burst_counter <= 0;
			if(last_transfer == True) begin
				red_pixel.clear();
				green_pixel.clear();
				blue_pixel.clear();
			end
			else begin
				red_pixel.deq();
				green_pixel.deq();
				blue_pixel.deq();
			end
		end else begin 
        	axi4_write_data(m_write, result_pixel, 16'hffff, False);
			burst_counter <= burst_counter + 1;
			red_pixel.deq();
        	green_pixel.deq();
        	blue_pixel.deq();
		end
    endrule

	rule writeResponse;
        	let r <- m_write.response.get();
    endrule
 
	rule readGet;
        	let r <- s_read.request.get();
        	case(r.addr)
				0: s_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(rgb_address)), resp: OKAY});
				8: s_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(gray_address)), resp: OKAY});
				16: s_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(start)), resp: OKAY});
				24: s_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(finish_flag)), resp: OKAY});
				32: s_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(gray_size)), resp: OKAY});
			endcase 
    endrule

	rule writeGet;
		let r <- s_write.request.get();
		case(r.addr)
			0: begin
				rgb_address <= r.data;
				s_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
			end
			8: begin
				gray_address <= r.data;
				s_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
			end		
			16: begin 
				start <= r.data;
				finish_flag <= 0;
				start_write_request <= True;
				s_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
			end
			32: begin
				gray_size <= r.data;
				rgb_threshold <= rgb_address + r.data - 16*(zExtend(pack(axi_burst_length)) + 1);
				gray_threshold <= gray_address + r.data - 16*(zExtend(pack(axi_burst_length)) + 1);
				s_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
			end
		endcase
	endrule

    interface AXI4_Master_Rd_Fab m_read_fab = m_read.fab;
	interface AXI4_Master_Wr_Fab m_write_fab = m_write.fab;	
	interface AXI4_Lite_Slave_Rd_Fab s_read_fab = s_read.fab;
	interface AXI4_Lite_Slave_Wr_Fab s_write_fab = s_write.fab;
endmodule
endpackage
