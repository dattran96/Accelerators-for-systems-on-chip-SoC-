package AXIConverter;

import BlueLib::*;
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
   
    //Write channel registers
    Reg#(Bool) start_write_request <- mkReg(False);
    //Read request registers
    Reg#(Bool) converting_flag <- mkReg(False);
    Reg#(Bit#(64)) ddr_read_count <- mkReg(0);
    //Convert constant 
    FixedPoint#(9,10) red_coff = 0.33;
    FixedPoint#(9,10) green_coff = 0.33;
    FixedPoint#(9,10) blue_coff = 0.33;
    //Convert registers 
    //Reg#(FixedPoint#(8,10)) gray_data <- mkReg(0)
    Reg#(Int#(9)) gray_data <- mkReg(0);
    //FIFO 64 Bitweise 
    FIFOF#(Bit#(64)) buffer <- mkSizedFIFOF(10);
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

    rule readRequest if( start != 0 && !converting_flag);
        axi4_lite_read(master_read, address_image_1 + ddr_read_count);
        if( ddr_read_count == 98304) begin // Check if all pixels are finished -> write to converting_finished register  
            ddr_read_count <= 0;
	    start <= 0;
        end
        else begin
            ddr_read_count <= ddr_read_count + 8;
        end 
        converting_flag <= True;
    endrule 

    rule convertRGB2Gray if( converting_flag);
        // See fixed point
        let r <- axi4_lite_read_response(master_read);
        axi4_lite_write(master_write, address_image_2 + ddr_read_count -8, zExtend(pack(r)));
	 // buffer.enq(r);
        //This code line is checked 
        //gray_data <= fxptGetInt(fromUInt(unpack(r[7:0]))*red_coff);
       // start_write_request <= True;
	converting_flag <= False;
    endrule

    // Here could use CReg
   // rule writeRequest if(start_write_request && buffer.notEmpty());
        
        
       // axi4_lite_write(master_write, address_image_2 + ddr_write_count, zExtend(pack(buffer.first())));
       // axi4_lite_write(master_write, address_image_2 + ddr_write_count, 64'd11);
       // buffer.deq();
       // if( ddr_write_count == 98304) begin // Check if all pixels are finished -> write to converting_finished register  
           // conversion_finished <= 1;
           // start <= 0;
           // ddr_write_count <= 0;
       // end
       // else begin
           // ddr_write_count <= ddr_write_count + 8;
       // end 
       // converting_flag <= False;
       // start_write_request <= False;
    //endrule

    interface AXI4_Lite_Master_Rd_Fab master_read_fab = master_read.fab;
    interface AXI4_Lite_Master_Wr_Fab master_write_fab = master_write.fab;
    interface AXI4_Lite_Slave_Rd_Fab slave_read_fab = slave_read.fab;
    interface AXI4_Lite_Slave_Wr_Fab slave_write_fab = slave_write.fab;
endmodule 

endpackage 

/*

1. Ask about the situation when you have read before write?
2. How to write the good testbench -> do we need to consider the response
3. What is the effect of address size ?
4. In the last -> where the number of need to write bytes is not a multiples of 64 -> what should I do?
5. Ask about the strob signal.
6. Interrupt
*/
