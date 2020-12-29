package tb_AXIMultiplier;
import StmtFSM :: *;
import AXIMultiplier::*;
import AXI4_Lite_Master::*;
import Connectable :: *;
import AXI4_Lite_Types :: *;



module mkAXIMultiplier_tb(Empty);
 Reg#(UInt#(8)) testState <- mkReg(0);
 AXI4_Lite_Master_Rd#(32, 64) m_rd <- mkAXI4_Lite_Master_Rd(0);
 AXI4_Lite_Master_Wr#(32, 64) m_wr <- mkAXI4_Lite_Master_Wr(0);

 AXIMultiplier s_mul <- mkAXIMultiplier();
 mkConnection(m_rd.fab,s_mul.slave_read_fab);
 mkConnection(m_wr.fab,s_mul.slave_write_fab);

rule write_register1(testState == 0);
//write
axi4_lite_write(m_wr,0,17);
testState <= testState+1;
endrule


rule write_register2(testState == 1);
//write
    let r <- axi4_lite_write_response(m_wr);
    if( r == OKAY) begin
        axi4_lite_write(m_wr,8,11);
        testState <= testState+1;
    end
endrule


rule read_register3(testState == 2);
    let r <- axi4_lite_write_response(m_wr);
    if( r == OKAY) begin
        axi4_lite_read(m_rd,16);
        testState <= testState+1;
    end
endrule


rule read_register4(testState == 3);
    let r <- axi4_lite_read_response(m_rd);
    $display("Product is: %d",r);
endrule


endmodule

endpackage
