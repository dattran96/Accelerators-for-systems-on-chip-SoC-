package Testbench;
import StmtFSM :: *;
import Grayscale::*;
import AXI4_Lite_Master::*;
import Connectable :: *;
import AXI4_Lite_Slave::*;
import AXI4_Lite_Types :: *;
import GetPut::*;
import BUtils :: *;
import BlueAXI::*;
import StmtFSM :: *;



module mkTestbench(Empty);

 AXI4_Lite_Master_Rd#(64, 64) m_rd <- mkAXI4_Lite_Master_Rd(0);
 AXI4_Lite_Master_Wr#(64, 64) m_wr <- mkAXI4_Lite_Master_Wr(0);

 AXI4_Lite_Slave_Rd#(64, 64) s_rd <- mkAXI4_Lite_Slave_Rd(0);
 AXI4_Lite_Slave_Wr#(64, 64) s_wd <- mkAXI4_Lite_Slave_Wr(0);

 Grayscale axi_grayscale <- mkGrayscale();

 mkConnection(m_rd.fab,axi_grayscale.slave_read_fab);
 mkConnection(m_wr.fab,axi_grayscale.slave_write_fab);
 mkConnection(axi_grayscale.master_read_fab, s_rd.fab);
 mkConnection(axi_grayscale.master_write_fab, s_wd.fab);

Stmt fsm = {seq
	$display("Convert request");
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
		$display(" Adress Image 1 %d",r);
	endaction
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
		$display("Adress Image 2 %d",r);
	endaction
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
   		$display(" Image size %d",r);
	endaction
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
    		$display("Start signal %d",r);
	endaction
	delay(1000000);	
	endseq
};
mkAutoFSM(fsm);

rule handleReadRequest;
    let r <- s_rd.request.get();
    if(r.addr[5:0] == 0) begin 
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h1020304050607080, resp: OKAY});
    end
    else if(r.addr[5:0] == 8) begin
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h0102030405060708, resp: OKAY});
    end 
    else if(r.addr[5:0] == 16) begin 
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h0a0a0a0a0a0a0a0a, resp: OKAY});
    end
    else if(r.addr[5:0] == 24) begin 
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h0a0a0a0a0a0a0a0a, resp: OKAY});
    end
    else if(r.addr[5:0] == 32) begin 
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h0a0a0a0a0a0a0a0a, resp: OKAY});
    end
    if(r.addr[5:0] == 40) begin
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h0a0a0a0a0a0a0a0a, resp: OKAY});
    end
    else if(r.addr[5:0] == 48) begin 
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h0a0a0a0a0a0a0a0a, resp: OKAY});
    end 
    else if(r.addr[5:0] == 56) begin
        s_rd.response.put(AXI4_Lite_Read_Rs_Pkg{ data: 64'h0a0a0a0a0a0a0a0a, resp: OKAY});
    end
endrule

rule handleWriteRequest;
    let r <- s_wd.request.get();
endrule

endmodule
endpackage
