package Testbench;
import StmtFSM :: *;
import AXIConverter::*;
import AXI4_Lite_Master::*;
import Connectable :: *;
import AXI4_Lite_Slave::*;
import AXI4_Lite_Types :: *;
import GetPut::*;
import BUtils :: *;
import BlueAXI::*;



module mkTestbench(Empty);
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

 
// Add why can't put these rules behind
//Read Slave channel 
rule handleReadRequest;
    let r <- s_rd.request.get();
    $display("Read address  %d",r.addr);
    if(r.addr[5:0] == 0) begin // Check address 0
        $display("Response data  %x ", 64'h9C9428207C7464C8);
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h9C9428207C7464C8, resp: OKAY});
    end
    else if(r.addr[5:0] == 8) begin // Check address 4
        $display("Response data %x ", 64'h9D312921191109C9);
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h9D312921191109C9, resp: OKAY});
    end 
    else if(r.addr[5:0] == 16) begin // Check address 8
        $display("Response data %x ", 64'h9E328E221A120ACA); 
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h9E328E221A120ACA, resp: OKAY});
    end
    else if(r.addr[5:0] == 24) begin // Check address 16
        $display("Response data %x ", 64'h9F332B871BBF0BCB);
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h9F332B871BBF0BCB, resp: OKAY});
    end
    else if(r.addr[5:0] == 32) begin 
        $display("Response data %x ", 64'hA0982C241C140CCC);
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'hA0982C241C140CCC, resp: OKAY});
    end
    if(r.addr[5:0] == 40) begin // Check address 0
        $display("Response data %x ", 64'hA1352D251D150DCD);
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'hA1352D251D150DCD, resp: OKAY});
    end
    else if(r.addr[5:0] == 48) begin // Check address 4
        $display("Response data %x ", 64'hA2362E26827A0ECE);
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'hA2362E26827A0ECE, resp: OKAY});
    end 
    else if(r.addr[5:0] == 56) begin // Check address 8
        $display("Response data %x ", 64'hA3372F271F1773CF);
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'hA3372F271F1773CF, resp: OKAY});
    end
endrule

rule handleWriteRequest;
    let r <- s_wd.request.get();
    $display("Write address %d",r.addr);
    $display("Write Data %x \n", r.data);
endrule


rule write_register1(testState == 0);
//write
axi4_lite_write(m_wr,0,0);
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
    //$display("%d",r);
    testState <= testState+1;
endrule


rule write_register2(testState == 3);
//write
axi4_lite_write(m_wr,8,0);

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
    testState <= testState+1;
endrule

rule write_register3(testState == 6);
//write
axi4_lite_write(m_wr,32,512);

testState <= testState+1;
endrule

rule read_register31(testState == 7);
//read
    let r <- axi4_lite_write_response(m_wr);
    
    if( r == OKAY) begin
        axi4_lite_read(m_rd,32);
        testState <= testState+1;
    end
endrule

rule read_register33(testState == 8);
    //read
    let r <- axi4_lite_read_response(m_rd);
    //$display("%d",r);
    testState <= testState+1;
endrule

rule write_register4(testState == 9);
//write

axi4_lite_write(m_wr,16,1);

testState <= testState+1;
endrule

rule read_register41(testState == 10);
//read
    let r <- axi4_lite_write_response(m_wr);
    if( r == OKAY) begin
        axi4_lite_read(m_rd,16);
        testState <= testState+1;
    end
endrule

rule read_register43(testState == 11);
    //read
    let r <- axi4_lite_read_response(m_rd);
    //$display("%d",r);
    testState <= testState+1;
endrule
endmodule




endpackage
