package tb_AXIConverter;
import StmtFSM :: *;
import AXIConverter::*;
import AXI4_Lite_Master::*;
import Connectable :: *;
import AXI4_Lite_Slave::*;
import AXI4_Lite_Types :: *;



module mkAXIConverter_tb(Empty);
 Reg#(UInt#(8)) testState <- mkReg(0);
 AXI4_Lite_Master_Rd#(64, 64) m_rd <- mkAXI4_Lite_Master_Rd(0);
 AXI4_Lite_Master_Wr#(64, 64) m_wr <- mkAXI4_Lite_Master_Wr(0);

 AXI4_Lite_Slave_Rd#(64, 64) s_rd <- mkAXI4_Lite_Slave_Rd(0);
 AXI4_Lite_Slave_Wr#(64, 64) s_wd <- mkAXI4_Lite_Slave_Wr(0);

 AXIConverter axi_convert <- mkAXIConverter();
//Reg file 
 mkConnection(m_rd.fab,axi_convert.slave_read_fab);
 mkConnection(m_wr.fab,axi_convert.slave_write_fab);
 mkConnection(axi_convert.master_read_fab, s_rd.fab);
 mkConnection(axi_convert.master_write_fab, s_wd.fab);

rule write_register1(testState == 0);
//write
axi4_lite_write(m_wr,0,5550);

testState <= testState+1;
endrule

rule read_register12(testState == 1);
//read
    let r <- axi4_lite_write_response(m_wr);
    if( r == OKAY) begin
        axi4_lite_read(m_rd,0);
        testState <= testState+1;
    end
endrule

rule read_register13(testState == 2);
    //read
    let r <- axi4_lite_read_response(m_rd);
    $display("%d",r);
    testState <= testState+1;
endrule


rule write_register2(testState == 3);
//write
axi4_lite_write(m_wr,8,18);

testState <= testState+1;
endrule

rule read_register21(testState == 4);
//read
    let r <- axi4_lite_write_response(m_wr);
    if( r == OKAY) begin
        axi4_lite_read(m_rd,8);
        testState <= testState+1;
    end
endrule

rule read_register23(testState == 5);
    //read
    let r <- axi4_lite_read_response(m_rd);
    $display("%d",r);
    testState <= testState+1;
endrule

rule write_register3(testState == 6);
//write
axi4_lite_write(m_wr,16,99);

testState <= testState+1;
endrule

rule read_register31(testState == 7);
//read
    let r <- axi4_lite_write_response(m_wr);
    if( r == OKAY) begin
        axi4_lite_read(m_rd,16);
        testState <= testState+1;
    end
endrule

rule read_register33(testState == 8);
    //read
    let r <- axi4_lite_read_response(m_rd);
    $display("%d",r);
    testState <= testState+1;
endrule

rule write_register4(testState == 9);
//write
axi4_lite_write(m_wr,32,120);

testState <= testState+1;
endrule

rule read_register41(testState == 10);
//read
    let r <- axi4_lite_write_response(m_wr);
    if( r == OKAY) begin
        axi4_lite_read(m_rd,32);
        testState <= testState+1;
    end
endrule

rule read_register43(testState == 11);
    //read
    let r <- axi4_lite_read_response(m_rd);
    $display("%d",r);
    testState <= testState+1;
endrule
endmodule

endpackage