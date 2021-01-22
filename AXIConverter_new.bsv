package AXIConverter;

import BlueAXI::*;
import GetPut::*;
import BUtils :: *;
import FixedPoint :: * ;
import FIFOF :: *;

interface AXIConverter;
    (* prefix = "S00_AXI" *)
    interface AXI4_Lite_Slave_Rd_Fab#(64, 64) slave_read_fab;
    (* prefix = "S00_AXI" *)
    interface AXI4_Lite_Slave_Wr_Fab#(64, 64) slave_write_fab;
    
    (* prefix = "M00_AXI" *)
    interface AXI4_Lite_Master_Rd_Fab#(64, 64) master_read_fab;
    (* prefix = "M00_AXI" *)
    interface AXI4_Lite_Master_Wr_Fab#(64, 64) master_write_fab;

endinterface

(*clock_prefix = "aclk", reset_prefix = "aresetn"*)
module mkAXIConverter(AXIConverter);
    // Create interface
    AXI4_Lite_Slave_Rd#(64, 64) slave_read <- mkAXI4_Lite_Slave_Rd(2);
    AXI4_Lite_Slave_Wr#(64, 64) slave_write <- mkAXI4_Lite_Slave_Wr(2);

    AXI4_Lite_Master_Rd#(64, 64) master_read <- mkAXI4_Lite_Master_Rd(2);
    AXI4_Lite_Master_Wr#(64, 64) master_write <- mkAXI4_Lite_Master_Wr(2);
    
    //Configuration registers
    Reg#(Bit#(64)) address_image_1 <- mkReg(0);
    Reg#(Bit#(64)) address_image_2 <- mkReg(0);
    Reg#(Bit#(64)) start <- mkReg(0);
    Reg#(Bit#(64)) conversion_finished <- mkReg(0);
    Reg#(Bit#(64)) image_size <- mkReg(0);
    Reg#(Bit#(64)) color_state <- mkReg(0);
    Reg#(Bit#(64)) enq_state <- mkReg(0);
	 
  
    //Write channel registers
    Reg#(Bool) start_write_request <- mkReg(False);
    
    //Read request registers
    Reg#(Bool) converting_flag <- mkReg(False);
    Reg#(Bit#(64)) ddr_read_count <- mkReg(0);
    
    //Convert constant 
    FixedPoint#(9,10) red_coff = 0.33;
    FixedPoint#(9,10) green_coff = 0.59;
    FixedPoint#(9,10) blue_coff = 0.11;
    
    //Convert registers 
    //Reg#(FixedPoint#(8,10)) gray_data <- mkReg(0)
    Reg#(Int#(9)) gray_data <- mkReg(0);
    
    //FIFO 64 Bitweise 
    FIFOF#(Bit#(64)) red_buff <- mkSizedFIFOF(10);
    FIFOF#(Bit#(64)) blue_buff <- mkSizedFIFOF(10);
    FIFOF#(Bit#(64)) green_buff <- mkSizedFIFOF(10);
    FIFOF#(Bit#(64)) gray_buff <- mkSizedFIFOF(10);
    
    //Write request registers
    Reg#(Bit#(64)) ddr_write_count <- mkReg(0);



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
            slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(image_size)), resp: OKAY});
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
            slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
        end
        else if(r.addr[5:0] == 32) begin
            image_size <= r.data;
            slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
        end
    endrule


    rule readRequest if( start != 0 && conversion_finished == 0);
	if(color_state == 0) begin
		axi4_lite_read(master_read, address_image_1 + ddr_read_count);
		color_state <= 1;
	end 
	else if(color_state == 1) begin
		axi4_lite_read(master_read, address_image_1 + 262144 + ddr_read_count);
		color_state <= 2;
	end else begin
		axi4_lite_read(master_read, address_image_1 + 524288 + ddr_read_count);
		color_state <= 0;
	end
      
        if(ddr_read_count == 262136) begin   
            ddr_read_count <= 0;
	    if(color_state == 2) begin
		start <= 0;
	    end
        end
        else begin
	    if(color_state == 2) begin 
		ddr_read_count <= ddr_read_count + 8;
	    end 
        end 
    endrule 

    rule rgbDataGet;
        let r <- axi4_lite_read_response(master_read);
	
	if(enq_state == 0) begin
		red_buff.enq(r);
		enq_state <= 1;
	end
	else if(enq_state == 1) begin
		green_buff.enq(r);
		enq_state <= 2; 
	end else begin 
		blue_buff.enq(r);
		enq_state <= 0;
	end
    endrule
    	
    
    rule rgb2gray;
	Bit#(64) red = red_buff.first();
	Bit#(64) green = green_buff.first();
	Bit#(64) blue = blue_buff.first();

	
	Int#(9) gray_1 = fxptGetInt(fromUInt(unpack(red[7:0]))*red_coff) + fxptGetInt(fromUInt(unpack(green[7:0]))*green_coff) +		fxptGetInt(fromUInt(unpack(blue[7:0]))*blue_coff);

	Int#(9) gray_2 = fxptGetInt(fromUInt(unpack(red[15:8]))*red_coff) + fxptGetInt(fromUInt(unpack(green[15:8]))*green_coff) 		+ fxptGetInt(fromUInt(unpack(blue[15:8]))*blue_coff);
	
	Int#(9) gray_3 = fxptGetInt(fromUInt(unpack(red[23:16]))*red_coff) + fxptGetInt(fromUInt(unpack(green[23:16]))*green_coff) + 		fxptGetInt(fromUInt(unpack(blue[23:16]))*blue_coff);
		
	Int#(9) gray_4 = fxptGetInt(fromUInt(unpack(red[31:24]))*red_coff) + fxptGetInt(fromUInt(unpack(green[31:24]))*green_coff) +		fxptGetInt(fromUInt(unpack(blue[31:24]))*blue_coff);

	Int#(9) gray_5 = fxptGetInt(fromUInt(unpack(red[39:32]))*red_coff) + fxptGetInt(fromUInt(unpack(green[39:32]))*green_coff) +     	fxptGetInt(fromUInt(unpack(blue[39:32]))*blue_coff);

	Int#(9) gray_6 = fxptGetInt(fromUInt(unpack(red[47:40]))*red_coff) + fxptGetInt(fromUInt(unpack(green[47:40]))*green_coff) +     	fxptGetInt(fromUInt(unpack(blue[47:40]))*blue_coff);

	Int#(9) gray_7 = fxptGetInt(fromUInt(unpack(red[55:48]))*red_coff) + fxptGetInt(fromUInt(unpack(green[55:48]))*green_coff) +		fxptGetInt(fromUInt(unpack(blue[55:48]))*blue_coff);

	Int#(9) gray_8 = fxptGetInt(fromUInt(unpack(red[63:56]))*red_coff) + fxptGetInt(fromUInt(unpack(green[63:56]))*green_coff) +     fxptGetInt(fromUInt(unpack(blue[63:56]))*blue_coff);
	
	 
	
	Bit#(64) gray_pixel;
	gray_pixel[63:56] = truncate(pack(gray_8));
	gray_pixel[55:48] = truncate(pack(gray_7));
	gray_pixel[47:40] = truncate(pack(gray_6));
	gray_pixel[39:32] = truncate(pack(gray_5));
	gray_pixel[31:24] = truncate(pack(gray_4));
	gray_pixel[23:16] = truncate(pack(gray_3));
	gray_pixel[15:8]  = truncate(pack(gray_2));
	gray_pixel[7:0]   = truncate(pack(gray_1));	
  
        axi4_lite_write(master_write, address_image_2 + ddr_write_count, zExtend(pack(gray_pixel)));
        red_buff.deq();
	green_buff.deq();
	blue_buff.deq();
        if( ddr_write_count == 262136 ) begin   
            conversion_finished <= 1;
            ddr_write_count <= 0;
        end
        else begin
            ddr_write_count <= ddr_write_count + 8;
        end 
    endrule

    rule requestResponse;
	let r <- master_write.response.get();
    endrule

    interface AXI4_Lite_Master_Rd_Fab master_read_fab = master_read.fab;
    interface AXI4_Lite_Master_Wr_Fab master_write_fab = master_write.fab;
    interface AXI4_Lite_Slave_Rd_Fab slave_read_fab = slave_read.fab;
    interface AXI4_Lite_Slave_Wr_Fab slave_write_fab = slave_write.fab;
endmodule 

endpackage 


