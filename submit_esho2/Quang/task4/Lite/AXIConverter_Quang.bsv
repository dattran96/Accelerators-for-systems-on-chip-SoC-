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
    FixedPoint#(9,10) red_coff = 0.299;
    FixedPoint#(9,10) green_coff = 0.587;
    FixedPoint#(9,10) blue_coff = 0.114;
    
    //FIFO 64 Bitweise 
    FIFOF#(Bit#(64)) red_buff <- mkSizedFIFOF(10);
    FIFOF#(Bit#(64)) blue_buff <- mkSizedFIFOF(10);
    FIFOF#(Bit#(64)) green_buff <- mkSizedFIFOF(10);
    
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
		axi4_lite_read(master_read, address_image_1 + image_size + ddr_read_count);
		color_state <= 2;
	end else begin
		axi4_lite_read(master_read, address_image_1 + image_size*2 + ddr_read_count);
		color_state <= 0;
	end
        //$display("ddr_read_count %d", ddr_read_count);
        if(ddr_read_count >= image_size - 8) begin   
		if(color_state == 2) begin
			ddr_read_count <= 0;
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
    
    function Bit#(8) pixelConvert(Bit#(8) red, Bit#(8) green, Bit#(8) blue);
	
	FixedPoint#(9,10) fixed_red = fromUInt(unpack(red));
	FixedPoint#(9,10) fixed_green = fromUInt(unpack(green));
	FixedPoint#(9,10) fixed_blue = fromUInt(unpack(blue));

        Int#(18) converted_pixel = fxptGetInt(fxptMult(fixed_red,red_coff))
                                 + fxptGetInt(fxptMult(fixed_green,green_coff))
                                 + fxptGetInt(fxptMult(fixed_blue,blue_coff));
        return truncate(pack(converted_pixel));
    endfunction	
    
    rule rgb2gray;
	Bit#(64) red = red_buff.first();
	Bit#(64) green = green_buff.first();
	Bit#(64) blue = blue_buff.first();
	
	Bit#(64) gray_pixel;
	gray_pixel[63:56] = pixelConvert(red[63:56], green[63:56], blue[63:56]);
	gray_pixel[55:48] = pixelConvert(red[55:48], green[55:48], blue[55:48]);
	gray_pixel[47:40] = pixelConvert(red[47:40], green[47:40], blue[47:40]);
	gray_pixel[39:32] = pixelConvert(red[39:32], green[39:32], blue[39:32]);
	gray_pixel[31:24] = pixelConvert(red[31:24], green[31:24], blue[31:24]);
	gray_pixel[23:16] = pixelConvert(red[23:16], green[23:16], blue[23:16]);
	gray_pixel[15:8]  = pixelConvert(red[15:8], green[15:8], blue[15:8]);
	gray_pixel[7:0]   = pixelConvert(red[7:0], green[7:0], blue[7:0]);	
  
        axi4_lite_write(master_write, address_image_2 + ddr_write_count, zExtend(pack(gray_pixel)));
        red_buff.deq();
	green_buff.deq();
	blue_buff.deq();
        if( ddr_write_count >= image_size - 8) begin   
            //$display("Finish");
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


