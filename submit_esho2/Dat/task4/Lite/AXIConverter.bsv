package AXIConverter;

import BlueAXI::*;
import GetPut::*;
import BUtils :: *;
import FixedPoint :: * ;
import FIFOF :: *;

interface AXIConverter;
    (* prefix = "S00_AXI" *)
    interface AXI4_Lite_Slave_Rd_Fab#(6, 64) s_read_fab;
    (* prefix = "S00_AXI" *)
    interface AXI4_Lite_Slave_Wr_Fab#(6, 64) s_write_fab;
    
    (* prefix = "M00_AXI" *)
    interface AXI4_Lite_Master_Rd_Fab#(64, 64) m_read_fab;
    (* prefix = "M00_AXI" *)
    interface AXI4_Lite_Master_Wr_Fab#(64, 64) m_write_fab;
endinterface

typedef enum {RED, GREEN, BLUE} ColorIndentifier deriving (Eq, Bits);

(*clock_prefix = "aclk", reset_prefix = "aresetn"*)
module mkAXIConverter(AXIConverter);

    AXI4_Lite_Slave_Rd#(6, 64) s_read <- mkAXI4_Lite_Slave_Rd(2);
    AXI4_Lite_Slave_Wr#(6, 64) s_write <- mkAXI4_Lite_Slave_Wr(2);

    AXI4_Lite_Master_Rd#(64, 64) m_read <- mkAXI4_Lite_Master_Rd(2);
    AXI4_Lite_Master_Wr#(64, 64) m_write <- mkAXI4_Lite_Master_Wr(2);
    

    Reg#(Bit#(64)) rgb_address <- mkReg(0);
    Reg#(Bit#(64)) gray_address <- mkReg(0);
    Reg#(Bit#(64)) start <- mkReg(0);
    Reg#(Bit#(64)) finish_flag <- mkReg(0);
    Reg#(Bit#(64)) gray_size <- mkReg(0);
    
    
    Reg#(Bit#(64)) rgb_threshold <- mkReg(0);
    Reg#(Bit#(64)) gray_threshold <- mkReg(0);
   
    Reg#(Bit#(2)) read_state <- mkReg(pack(RED));
    
    rule readRGB if( start != 0 && finish_flag == 0);
		case(read_state)
			pack(RED): begin
				axi4_lite_read(m_read, rgb_address);
				read_state <= pack(GREEN);
			end
			pack(GREEN): begin
				axi4_lite_read(m_read, rgb_address + gray_size);
				read_state <= pack(BLUE);
			end
			pack(BLUE): begin
				axi4_lite_read(m_read, rgb_address + gray_size*2);
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
				rgb_address <= rgb_address + 8;
			end 
        end 
    endrule 

    FIFOF#(Bit#(64)) red_pixel <- mkSizedFIFOF(10);
    FIFOF#(Bit#(64)) blue_pixel <- mkSizedFIFOF(10);
    FIFOF#(Bit#(64)) green_pixel <- mkSizedFIFOF(10);
    
    Reg#(Bit#(2)) add_buff_state <- mkReg(pack(RED));
    rule bufferPixel;
        let r <- axi4_lite_read_response(m_read);
		case(add_buff_state)
			pack(RED): begin red_pixel.enq(r); add_buff_state <= pack(GREEN); end
			pack(GREEN): begin green_pixel.enq(r); add_buff_state <= pack(BLUE); end
			pack(BLUE): begin blue_pixel.enq(r); add_buff_state <= pack(RED); end
		endcase
    endrule
    
    FixedPoint#(9,10) red_weigh = 0.299;
    FixedPoint#(9,10) green_weigh = 0.587;
    FixedPoint#(9,10) blue_weigh = 0.114;
    
    rule grayWrite;
		Bit#(64) red_temp = red_pixel.first();
		Bit#(64) green_temp = green_pixel.first();
		Bit#(64) blue_temp = blue_pixel.first();
		
		Bit#(64) result_pixel = 0;
		FixedPoint#(9,10) fxpt_red = 0;  
		FixedPoint#(9,10) fxpt_green = 0;
		FixedPoint#(9,10) fxpt_blue = 0; 
		
		for(Integer i = 0; i <= 56; i = i + 8) begin
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
		
        axi4_lite_write(m_write, gray_address, zExtend(pack(result_pixel)));
        
        if( gray_address >= gray_threshold) begin   
            finish_flag <= 1;
            gray_address <= 0;
        end
        else begin
            gray_address <= gray_address + 8;
        end 
        
        red_pixel.deq();
		green_pixel.deq();
		blue_pixel.deq();
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
				s_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
			end
			32: begin
				gray_size <= r.data;
				rgb_threshold <= rgb_address + r.data - 8;
				gray_threshold <= gray_address + r.data - 8;
				s_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
			end
		endcase
    endrule

    interface AXI4_Lite_Master_Rd_Fab m_read_fab = m_read.fab;
    interface AXI4_Lite_Master_Wr_Fab m_write_fab = m_write.fab;
    interface AXI4_Lite_Slave_Rd_Fab s_read_fab = s_read.fab;
    interface AXI4_Lite_Slave_Wr_Fab s_write_fab = s_write.fab;
endmodule 
endpackage 

