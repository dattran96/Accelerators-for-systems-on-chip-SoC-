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
import StmtFSM :: *;



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
    //$display("Read address  %d",r.addr);
    if(r.addr[5:0] == 0) begin // Check address 0
        //$display("Response data  %d ", 64'd10);
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h1020304050607080, resp: OKAY});
    end
    else if(r.addr[5:0] == 8) begin // Check address 4
        //$display("Response data %d ", 64'd20);
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h0102030405060708, resp: OKAY});
    end 
    else if(r.addr[5:0] == 16) begin // Check address 8
        //$display("Response data %d ", 64'd30);
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h0a0a0a0a0a0a0a0a, resp: OKAY});
    end
    else if(r.addr[5:0] == 24) begin // Check address 16
        //$display("Response data %d ", 64'd40);
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h0a0a0a0a0a0a0a0a, resp: OKAY});
    end
    else if(r.addr[5:0] == 32) begin 
        //$display("Response data %d ", 64'd50);
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h0a0a0a0a0a0a0a0a, resp: OKAY});
    end
    if(r.addr[5:0] == 40) begin // Check address 0
        //$display("Response data %d ", 64'd60);
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h0a0a0a0a0a0a0a0a, resp: OKAY});
    end
    else if(r.addr[5:0] == 48) begin // Check address 4
        //$display("Response data %d ", 64'd70);
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h0a0a0a0a0a0a0a0a, resp: OKAY});
    end 
    else if(r.addr[5:0] == 56) begin // Check address 8
        //$display("Response data %d ", 64'd80);
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h0a0a0a0a0a0a0a0a, resp: OKAY});
    end
endrule

rule handleWriteRequest;
    let r <- s_wd.request.get();
    $display("Write address %d",r.addr);
    $display("Write Data %x \n", r.data);
endrule

// Configuration FSM
Stmt fsm = {seq
	$display("First convert request");
	//Write image address 1
	action 
		axi4_lite_write(m_wr,0,0);
	endaction
	action
		let r <- axi4_lite_write_response(m_wr);
    		if( r == OKAY) begin
        		axi4_lite_read(m_rd,0);
    		end
	endaction
	action
		let r <- axi4_lite_read_response(m_rd);
		$display("%d",r);
	endaction

	//Write image addess 2
	action
		axi4_lite_write(m_wr,8,0);
	endaction
	action 
		let r <- axi4_lite_write_response(m_wr);
    		if( r == OKAY) begin
        		axi4_lite_read(m_rd,8);
    		end
	endaction
	action
		let r <- axi4_lite_read_response(m_rd);
		$display("%d",r);
	endaction

	//Write image size 
	action
		axi4_lite_write(m_wr,32,262144);
	endaction
	action 
		let r <- axi4_lite_write_response(m_wr);

    		if( r == OKAY) begin
        		axi4_lite_read(m_rd,32);
    		end
	endaction
	action
		let r <- axi4_lite_read_response(m_rd);
   		$display("%d",r);
	endaction

	//Write start signal
	action
		axi4_lite_write(m_wr,16,1);
	endaction

	action
		let r <- axi4_lite_write_response(m_wr);
    		if( r == OKAY) begin
        		axi4_lite_read(m_rd,16);
    		end
	endaction

	action
		let r <- axi4_lite_read_response(m_rd);
    		$display("%d",r);
	endaction
	delay(1000000);	
	endseq
};
mkAutoFSM(fsm);

endmodule
endpackage
