package tb_AXIMultiplier;
import StmtFSM :: *;
import AXIMultiplier::*;
import AXI4_Lite_Master::*;
import Connectable :: *;



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
axi4_lite_write(m_wr,1,11);
testState <= testState+1;
endrule


rule read_register3(testState == 2);
//read
axi4_lite_read(m_rd,2);
testState <= testState+1;
endrule


rule read_register4(testState == 3);
//read
axi4_lite_read(m_rd,2);
testState <= testState+1;
endrule


rule read_register8(testState == 4);
//read
axi4_lite_read(m_rd,2);
testState <= testState+1;
endrule

rule read_register5(testState == 5);
//read
let r <- axi4_lite_read_response(m_rd);
$display("%d",r);
testState <= testState+1;
endrule

rule read_register6(testState == 6);
//read
let r <- axi4_lite_read_response(m_rd);
$display("%d",r);
testState <= testState+1;
endrule


rule read_register7(testState == 7);
//read
let r <- axi4_lite_read_response(m_rd);
$display("%d",r);
testState <= testState+1;
endrule



endmodule

endpackage
