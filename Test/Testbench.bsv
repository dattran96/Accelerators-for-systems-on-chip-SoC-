package Testbench;
import StmtFSM :: *;
import AXIConverter::*;
import AXISobelFilter::*;
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

 //AXI4_Lite_Slave_Rd#(64, 64) s_rd <- mkAXI4_Lite_Slave_Rd(0);
 //AXI4_Lite_Slave_Wr#(64, 64) s_wd <- mkAXI4_Lite_Slave_Wr(0);

AXI4_Slave_Rd#(64,128,16, 0) s_rd <- mkAXI4_Slave_Rd(16,16);
AXI4_Slave_Wr#(64,128,16, 0) s_wr <- mkAXI4_Slave_Wr(16,16,16);

AXIConverter axi_convert <- mkAXIConverter();
//Reg file 
mkConnection(m_rd.fab,axi_convert.slave_read_fab);
mkConnection(m_wr.fab,axi_convert.slave_write_fab);
mkConnection(axi_convert.master_read_fab, s_rd.fab);
mkConnection(axi_convert.master_write_fab, s_wr.fab);



Reg#(Bit#(64)) addr_counter_write <- mkReg(0);
Reg#(UInt#(9)) transfers_left_write <- mkReg(0);
Reg#(Bit#(16)) cur_id_write <- mkRegU(); // mkRegU()? -> read again

rule handleWriteRequest if(transfers_left_write == 0);
	$display("Slave_TB: Receive write request");
	$display("");
        let r <- s_wr.request_addr.get();
        transfers_left_write <= extend(r.burst_length) + 1;
        addr_counter_write <= r.addr;
        cur_id_write <= r.id;
endrule 

rule handleWriteData if(transfers_left_write != 0);
        let r <- s_wr.request_data.get();
	$display("Slave_TB: Write data is %d", r.data);
	$display("");
        transfers_left_write <= transfers_left_write - 1;
        if(transfers_left_write == 1) begin
	    $display("Slave_TB: Finish burst write data");
	    $display("");
            s_wr.response.put(AXI4_Write_Rs {id: cur_id_write, resp: OKAY, user: 0});
        end
endrule

Reg#(Bit#(64)) addr_counter <- mkReg(0);
Reg#(UInt#(9)) transfers_left_send <- mkReg(0);
Reg#(Bit#(16)) cur_id <- mkRegU();

rule handleReadRequest if(transfers_left_send == 0);
	$display("Slave_TB: Receive read request");
	$display("");
	let r <- s_rd.request.get();
        let transfers_left = extend(r.burst_length) + 1;
        transfers_left_send <= transfers_left;
        cur_id <= r.id;
endrule

rule returnReadValue if(transfers_left_send != 0);
	//$display("I am in return value");
        transfers_left_send <= transfers_left_send - 1;
        //Bit#(128) data_send = zExtend(pack(transfers_left_send));
        Bit#(128) data_send = 128'h00007B00000000007B7B7B7B7B7B7B7B;
        s_rd.response.put(AXI4_Read_Rs {data: data_send, id: cur_id, resp: OKAY, last: transfers_left_send == 1, user: 0});
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
axi4_lite_write(m_wr,32,512); ///

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
