package AXIConverter;

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
    FIFOF#(Bit#(8)) buffer_8bit <- mkSizedFIFOF(32);
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


/*
    Reg#(Bool) finish_windowCalculation <- mkReg(False);
    Reg#(Bit#(64)) row_index <- mkReg(0);
    Reg#(Bit#(64)) column_index <- mkReg(0);
    rule index_column_row if(finish_windowCalculation);
	column_index <= column_index + 1;
	if(column_index > 509) begin //column in range of 0..imageSize-2	    
		column_index <= 0;
		row_index <= row_index +1 ;   	
	end
	if (column_index > 509 &&  row_index >= 509) begin
		column_index <= 0;
		row_index <= 0;
	end 
   endrule
*/


   Reg#(Bit#(64)) state_64 <- mkReg(0);
   rule readRequest if( start != 0 && conversion_finished == 0);
        axi4_lite_read(master_read, address_image_1 + ddr_read_count);
        if( ddr_read_count == 262136) begin // Check if all pixels are finished -> write to converting_finished register  
            ddr_read_count <= 0;
        end
        else begin
            ddr_read_count <= ddr_read_count + 8;
        end 
    endrule 
 
  /*Store data locally with 64 bit each*/
   rule localDataBuffer;
	let r <- axi4_lite_read_response(master_read);
	buffer.enq(r);
   endrule
   
   /* Store data locally with 8 bits each */
   Reg#(Bit#(3)) enq_order <- mkReg(0);
   rule localDataBuffer_8bit if(buffer_8bit.notEmpty()== False && enq_order == 0); //enqueue only when buffer_8bit is empty, so that avoid mismatch length
	Bit#(64) temp = buffer.first();
	case(enq_order)		
		0: buffer_8bit.enq(temp[7:0]);  //didn't work for sequential
		1: buffer_8bit.enq(temp[15:8]);
		2: buffer_8bit.enq(temp[23:16]); 
		3: buffer_8bit.enq(temp[31:24]);
		4: buffer_8bit.enq(temp[39:32]);
		5: buffer_8bit.enq(temp[47:40]);
		6: buffer_8bit.enq(temp[55:48]);
		7: buffer_8bit.enq(temp[63:56]);
	endcase
	enq_order <= enq_order + 1;
   endrule

   Reg#(Bit#(8)) reg11 <- mkReg(0);
   Reg#(Bit#(8)) reg12 <- mkReg(0);
   Reg#(Bit#(8)) reg13 <- mkReg(0);
   Reg#(Bit#(8)) reg21 <- mkReg(0);
   Reg#(Bit#(8)) reg22 <- mkReg(0);
   Reg#(Bit#(8)) reg23 <- mkReg(0);
   Reg#(Bit#(8)) reg31 <- mkReg(0);
   Reg#(Bit#(8)) reg32 <- mkReg(0);
   Reg#(Bit#(8)) reg33 <- mkReg(0);
   FIFOF#(Bit#(8)) rowBuffer_1 <- mkSizedFIFOF(5);
   FIFOF#(Bit#(8)) rowBuffer_2 <- mkSizedFIFOF(5);
   Reg#(Bool) windowReady <- mkReg(False); //issue to other rules that data of 9 pixel are ready
   Reg#(Bool) windowSlide <- mkReg(False); // other rules set this bit to issue they need new window data
   Reg#(Bool) window_Initial <- mkReg(False);
   Reg#(Bool) rowBuffer_inital <- mkReg(True);
   Reg#(Bit#(32)) bufferRowCount <- mkReg(0);
   Reg#(Bool) sobelConvert <- mkReg(False);

   /* Initialize row buffer at the first time, since slide window operate correctly only if row buffer 1 and row buffer 2 are already filled */
   rule rowBufferInital if(rowBuffer_inital == True && rowBuffer_1.notFull() == True && rowBuffer_2.notFull() == True );
   	rowBuffer_1.enq(0); //Fill waste values until full
	rowBuffer_2.enq(0); //Fill waste values until full	
	if(rowBuffer_1.notFull() == False) begin
		rowBuffer_inital <= False;
		window_Initial <= True;
		$display("Test Here");
	end
   endrule
   
   rule rowBufferInital_finish if(rowBuffer_1.notFull() == False);
   	rowBuffer_inital <= False;
	window_Initial <= True;
   endrule
   
   
   
   
    FIFOF#(Bit#(8)) testslideWindow <- mkSizedFIFOF(262144);
    Reg#(Bit#(8)) testslideWindow_count <- mkReg(0);    
    rule initial_testslideWindow if( testslideWindow_count < 255);
    	testslideWindow.enq(testslideWindow_count);
    	testslideWindow_count <= testslideWindow_count + 1;   
    endrule

   Reg#(Bit#(8)) slide <- mkReg(0);    
   /* Initialize window buffer, Fill up all pixels of 3x3 kernel and row 1 and row2, ready for next processing step */
   rule windowBuffer_inital if(window_Initial == True && rowBuffer_inital == False);
   	$display("Test Here 3");
   	case(slide):		
   	0:reg11 <= reg12;
	1:reg12 <= reg13;
	2:reg13 <= rowBuffer_1.first();
	3:rowBuffer_1.enq(reg21);
	4:reg21 <= reg22;
	5:reg22 <= reg23;
	6:reg23 <= rowBuffer_2.first();
	7:rowBuffer_2.enq(reg31);
	8:reg31 <= reg32;
	9:reg32 <= reg33;
	10:reg33 <= buffer_8bit.first();
   	11:bufferRowCount <= bufferRowCount + 1;
   	endcase
	if(bufferRowCount >= 1033) begin //512+ 512+ 9
		window_Initial <= False;
		sobelConvert <= True;
	end
    endrule

     /* slide window to make room to get new data in, this will create new window data for sobel operator */
     
   rule windowBuffer_slide if(sobelConvert == False && window_Initial == False && rowBuffer_inital == False ); //Sobel needs new data, this sobelConvert is a status to tell window buffer to slide
   	reg11 <= reg12;
	reg12 <= reg13;
	reg13 <= rowBuffer_1.first();
	rowBuffer_1.enq(reg21);
	reg21 <= reg22;
	reg22 <= reg23;
	reg23 <= rowBuffer_2.first();
	rowBuffer_2.enq(reg31);
	reg31 <= reg32;
	reg32 <= reg33;
	reg33 <= testslideWindow.first();  //Attention, replay buffer_8bit with testslideWindow	
	/* TODO, Special case, get not only 1 pixel but 3 pixel if it's poiting at the begin of each row, so we need to slide not only one but three times*/
    endrule
   

   Reg#(Bit#(8)) reg_test <- mkReg(10);        
   rule sobelOperator(sobelConvert == True);
	/*TODO, Convert here*/
	$display("%d Hello World!", reg11);
	$display("%d Hello World!", reg12);
	$display("%d Hello World!", reg13);
	$display("%d Hello World!", reg21);
	$display("%d Hello World!", reg22);
	$display("%d Hello World!", reg23);
	$display("%d Hello World!", reg31);
	$display("%d Hello World!", reg32);
	$display("%d Hello World!", reg33);
	/*Need another window*/
	sobelConvert <= False;
   endrule


    // Here could use CReg
    rule writeRequest if( buffer.notEmpty() && state_64 == 2);
        axi4_lite_write(master_write, address_image_2 + ddr_write_count, zExtend(pack(buffer.first())));
        //axi4_lite_write(master_write, address_image_2 + ddr_write_count, 64'd11);
        buffer.deq();
        if( ddr_write_count == 786424 ) begin // Check if all pixels are finished -> write to converting_finished register  
            conversion_finished <= 1;
            start <= 0;
            ddr_write_count <= 0;
        end
        else begin
            ddr_write_count <= ddr_write_count + 8;
        end 
        converting_flag <= False;
	state_64 <= 0 ;
    endrule

    rule requestResponse;
	let r <- master_write.response.get();
    endrule

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
