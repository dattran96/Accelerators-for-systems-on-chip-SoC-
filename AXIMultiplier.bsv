package AXIMultiplier;

import BlueAXI::*;
import GetPut::*;
import BUtils :: *;

interface AXIMultiplier;
    (* prefix = "S00_AXI" *)
    interface AXI4_Lite_Slave_Rd_Fab#(32, 64) slave_read_fab;
    (* prefix = "S00_AXI" *)
    interface AXI4_Lite_Slave_Wr_Fab#(32, 64) slave_write_fab;
endinterface

(*clock_prefix = "aclk", reset_prefix = "aresetn"*)
module mkAXIMultiplier(AXIMultiplier);
    AXI4_Lite_Slave_Rd#(32, 64) slave_read <- mkAXI4_Lite_Slave_Rd(2);
    AXI4_Lite_Slave_Wr#(32, 64) slave_write <- mkAXI4_Lite_Slave_Wr(2);
    
    Reg#(Bit#(64)) operand_1 <- mkReg(0);
    Reg#(Bit#(64)) operand_2 <- mkReg(0);
    Reg#(Bit#(64)) product <- mkReg(0);

    rule handleReadRequest;
        let r <- slave_read.request.get();
		if(r.addr[5:0] == 0) begin
            slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(operand_1)), resp: OKAY});
        end
        else if(r.addr[5:0] == 8) begin 
            slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(operand_2)), resp: OKAY});
        end
        else if(r.addr[5:0] == 16) begin
            slave_read.response.put(AXI4_Lite_Read_Rs_Pkg{ data: zExtend(pack(product)), resp: OKAY});
        end
    endrule

    rule handleWriteRequest;
        let r <- slave_write.request.get();
        if(r.addr[5:0] == 0) begin
            operand_1 <= r.data; 
            slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
        end
        else if(r.addr[5:0] == 8) begin 
            operand_2 <= r.data;
            slave_write.response.put(AXI4_Lite_Write_Rs_Pkg{resp: OKAY});
        end
    endrule 

    rule product_operation;
        product <= operand_1 *  operand_2;
    endrule 

    interface AXI4_Lite_Slave_Rd_Fab slave_read_fab = slave_read.fab;
    interface AXI4_Lite_Slave_Wr_Fab slave_write_fab = slave_write.fab;
endmodule 

endpackage 