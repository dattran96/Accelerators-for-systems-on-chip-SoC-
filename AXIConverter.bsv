package AXIMultiplier;

import BlueAXI::*;
import GetPut::*;
import BUtils :: *;

interface AXIConverter;
    (* prefix = "S00_AXI" *)
    interface AXI4_Lite_Slave_Rd_Fab#(32, 32) slave_read_fab;
    (* prefix = "S00_AXI" *)
    interface AXI4_Lite_Slave_Wr_Fab#(32, 32) slave_write_fab;
    
    (* prefix = "M00_AXI" *)
    interface AXI4_Lite_Master_Rd_Fab#(32, 32) master_read_fab;
    (* prefix = "M00_AXI" *)
    interface AXI4_Lite_Master_Wr_Fab#(32, 32) master_write_fab:

endinterface

(*clock_prefix = "aclk", reset_prefix = "aresetn"*)
module mkAXIConverter(AXIConverter);
    AXI4_Lite_Slave_Rd#(32, 64) slave_read <- mkAXI4_Lite_Slave_Rd(2);
    AXI4_Lite_Slave_Wr#(32, 64) slave_write <- mkAXI4_Lite_Slave_Wr(2);
    //Ask why here the buffer size is 2
    AXI_Lite_Master_Rd#(32, 32) master_read <- mkAXI4_Lite_Master_Rd(2);
    AXI_Lite_Master_Wr#(32, 32) master_write <- mkAXI4_Lite_Master_Wr(2);
    //What if I put here Bit or Int??
    Reg#(Bit#(32)) address_image_1 <- mkReg(0);
    Reg#(Bit#(32)) address_image_2 <- mkReg(0);
    //If want to use only 1 bit for these signal-> how to transfer over AXI efficiently?
    Reg#(Bit#(32)) start <- mkReg(0);
    Reg#(Bit#(32)) conversion_finished <- mkReg(0)

    Reg#(Bool) read_flag <- mkReg(False);
    Reg#(Bit#(5)) read_address <- mkReg(0);

    rule handleReadRequest if(!read_flag);
        let r <- slave_read.request.get();
        read_address <= r.addr[4:0];
        read_flag <= True;
    endrule

    rule handleReadData if(read_flag);
        if(!(read_address & 5'b11111)) begin // Check address 0
            slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(address_image_1)), resp: OKAY});
        end
        else if(!(read_address & 5'b11011) begin // Check address 4
            slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(address_image_2)), resp: OKAY});
        end 
        else if(!(read_address & 5'b10111) begin // Check address 8
            slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(start)), resp: OKAY});
        end
        else if(!(read_address & 5'b01111) begin // Check address 16
        slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(conversion_finished)), resp: OKAY});
        end
        read_flag <= False;
    endrule 

    Reg#(Bool) write_flag <- mkReg(False);
    Reg#(Bit#(5)) write_address <- mkReg(0);
    Reg#(Bit#(32)) write_data <- mkReg(0);

    rule handleWriteRequest if(!write_flag);
        let r <- slave_write.request.get();
        write_address <= r.addr[4:0];
        write_data <= r.data;
        write_flag <= True;
    endrule

    rule handleWriteData if(write_flag);
        if(!(read_address & 5'b11111)) begin // Check address 0
            address_image_1 <= write_data;
            slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
        end
        else if(!(read_address & 5'b11011) begin // Check address 4
            address_image_1 <= write_data;
            slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
        end 
        else if(!(read_address & 5'b10111) begin // Check address 8
            start <= write_data;
            conversion_finished <= 0;
            slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
        end
        // Don't provide the ability to write to conversion_finished (read-only)
        write_flag <= False;
    endrule

    Reg#(Bool) converting_flag <- mkReg(False);
    Reg#(Bit#(32)) ddr_read_count <- mkReg(0);

    rule readRequest if( start != 0 && conversion_finished == 0 && !converting_flag);
        axi_lite_read(master_read, address_image_1 + ddr_read_count);
        ddr_read_count <= ddr_read_count + 4;
        converting_flag <= True;
    endrule 

    Reg#(Bool) response_flag <- mkReg(False);

    Reg#(Bit#(8)) red <- mkReg(0);
    Reg#(Bit#(8)) green <- mkReg(0);
    Reg#(Bit#(8)) blue <- mkReg(0);

    rule handelReadResponse if(!response_flag);
        let r <- axi4_lite_read_response(master_read);
        //The way take value here are not clear, it depends on how data is written into memory
        reg <= r.data[7:0];
        reg <= r.data[15:8];
        reg <= r.data[23:16];
        response_flag <= True;
    endrule

    Reg#(Bit#(32)) gray_data <- mkReg(0);
    Reg#(Bool) start_write_request <- mkReg(0);

    rule convertRGB2Gray if(response_flag);
        gray_data <= red*0.33 + green*0.33 + blue*0.33;
        response_flag <= False;
        start_write_request <= True;
    endrule

    Reg#(Bit#(32)) ddr_write_count <- mkReg(0);

    rule writeRequest if(start_write_request);
        axi_lite_write(master_write, address_image_2 + ddr_write_count, gray_data);
        if( ddr_write_count == 512) begin // Check if all pixels are finished -> write to converting_finished register  
            conversion_finished <= 1;
        end
        start_write_request <= False;
        converting_flag <= True;
    endrule

    interface AXI4_Lite_Master_Rd_Fab master_read_fab = master_read.fab;
    interface AXI4_Lite_Master_Wr_Fab master_write_fab = master_write.fab;
    interface AXI4_Lite_Slave_Rd_Fab slave_read_fab = slave_read.fab;
    interface AXI4_Lite_Slave_Wr_Fab slave_write_fab = slave_write.fab;
endmodule 

endpackage 