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
        if( ddr_read_count == 56) begin // Check if all pixels are finished -> write to converting_finished register  
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
   rule localDataBuffer_8bit if(buffer_8bit.notEmpty()== False); //enqueue only when buffer_8bit is empty, so that avoid mismatch length
	Bit#(64) temp = buffer.first(); 
	case(enq_order)		
		0: buffer_8bit.enq(temp[7:0]);  //didn't work for sequential
		1: buffer_8bit.enq(temp[15:8]);
		2: buffer_8bit.enq(temp[23:16]); 
		3: buffer_8bit.enq(temp[31:24]);
		4: buffer_8bit.enq(temp[39:32]);
		5: buffer_8bit.enq(temp[47:40]);
		6: buffer_8bit.enq(temp[55:48]);
		7: begin buffer_8bit.enq(temp[63:56]); buffer.deq; end
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
   FIFOF#(Bit#(8)) rowBuffer_1 <- mkSizedFIFOF(2);  //PAY ATTENTION, SUBJECT to CHANGE
   FIFOF#(Bit#(8)) rowBuffer_2 <- mkSizedFIFOF(2);  //PAY ATTENTION, SUBJECT to CHANGE	
   Reg#(Bool) windowReady <- mkReg(False); //issue to other rules that data of 9 pixel are ready
   Reg#(Bool) windowSlide <- mkReg(False); // other rules set this bit to issue they need new window data
   Reg#(Bool) window_Initial <- mkReg(False);
   Reg#(Bool) rowBuffer_inital <- mkReg(True);
   Reg#(Bit#(32)) bufferRowCount <- mkReg(0);
   Reg#(Bool) sobelConvert <- mkReg(False);
   
   Reg#(Bit#(32)) kernel_size <- mkReg(3); //PAY ATTENTION, SUBJECT to CHANGE
   Reg#(Bit#(32)) image_length <- mkReg(5); //PAY ATTENTION, SUBJECT to CHANGE
   /* Initialize row buffer at the first time, since slide window operate correctly only if row buffer 1 and row buffer 2 are already filled */
   rule rowBufferInital if(rowBuffer_inital == True && rowBuffer_1.notFull() == True && rowBuffer_2.notFull() == True );
   	rowBuffer_1.enq(0); //Fill waste values until full
	rowBuffer_2.enq(0); //Fill waste values until full
	$display("Test Here 1");	
   endrule
   

   	
   
   rule rowBufferInital_finish if(rowBuffer_1.notFull() == False && rowBuffer_inital == True);
   	rowBuffer_inital <= False;
	window_Initial <= True;
	$display("Test Here 2");
   endrule
   
   
   
    /* Simulate an Image*/
    FIFOF#(Bit#(8)) testslideWindow <- mkSizedFIFOF(25); //PAY ATTENTION, SUBJECT to CHANGE
    Reg#(Bit#(8)) testslideWindow_count <- mkReg(0); 
    Reg#(Bool) testslideWindow_control <- mkReg(True);    
    rule initial_testslideWindow if(testslideWindow_control == True); //test image 5 x 5 first
    	testslideWindow.enq(testslideWindow_count);
    	testslideWindow_count <= testslideWindow_count + 1;  
    	$display("Test Here 3"); 
    endrule
    
    rule initial_testslideWindow_finish if( testslideWindow.notFull() == False && testslideWindow_control == True) ; //test image 5 x 5 first
 	testslideWindow_control <= False;
    	$display("Test Here 4"); 
    endrule
/*	
   rule print_fifo(testslideWindow_control == False);
   	let r = testslideWindow.first;
   	testslideWindow.deq;
   	$display("FIFO element %d",r); 
   endrule	
*/	
    
    /* Questions: Seperate rule is the only way?*/ /* 3x3 Kernel and 5x5 7x7 Kernel */
    
   /* Initialize window buffer, Fill up all pixels of 3x3 kernel and row 1 and row2, ready for next processing step */
    Reg#(Bool) slide <- mkReg(False);    //command register
    Reg#(Bool) slide_finish <- mkReg(False);    //status register	
    Reg#(Bit#(32)) slide_position <- mkReg(0); //Count from 0
    Reg#(Bit#(8)) state_temp <- mkReg(0);
   rule windowBuffer_inital if(window_Initial == True && rowBuffer_inital == False && state_temp==0 && testslideWindow_control == False);
  	$display("Test Here 5");
   	reg11 <= reg12; 
	reg12 <= reg13;
	reg13 <= rowBuffer_1.first; rowBuffer_1.deq; 
	state_temp <= state_temp +1 ;
   endrule
   
   rule windowBuffer_inital_2(state_temp ==1);
   	rowBuffer_1.enq(reg21); $display("Test Here 6");
	reg21 <= reg22;
	reg22 <= reg23;
	reg23 <= rowBuffer_2.first(); rowBuffer_2.deq;
	state_temp <= state_temp +1 ;
   endrule

   rule windowBuffer_inital_3(state_temp ==2);
   	$display("Test Here 7");	
	rowBuffer_2.enq(reg31);
	reg31 <= reg32;
	reg32 <= reg33;
	reg33 <= testslideWindow.first(); testslideWindow.deq; //PAY ATTENTION, REPLACE "testslideWindow" WITH "buffer_8bit" to get data via AXI
	state_temp <=3;
	bufferRowCount <= bufferRowCount + 1;
	slide_finish <= True;
	if( slide_position < image_length)
		slide_position <= slide_position + 1;
	else
		slide_position <= 1;
   endrule
  
  /*Control state, this state checks if the sliding window should continue sliding*/ 
  Reg#(Bool) windowBuffer_once_inital <- mkReg(False);    //status register	
  rule windowBuffer_inital_end if(window_Initial == True && rowBuffer_inital == False && state_temp ==3 && windowBuffer_once_inital == False);	
	if(bufferRowCount >= image_length + image_length + kernel_size) begin //512+ 512+ 9 //PAY ATTENTION  change
		window_Initial <= False;
		windowBuffer_once_inital <= True;
		sobelConvert <= True; //command
		slide_finish <= False; //Reset slide status
		$display("Test Here 8");
	end
	else
		state_temp <= 0; 
  endrule
    
  
  /*Control state, this state checks if the sliding window should continue sliding and how many units it will slide*/ 
  rule windowBuffer_slide if (slide == True && state_temp ==3);	
	if(bufferRowCount >= image_length*image_length+1) begin
		$display("Test slide position 1  %d",slide_position );
		window_Initial <= False;
		sobelConvert <= False;
		slide <= False;
	end
	
	else if( slide_finish == False ||  slide_position == 1 ||  slide_position == 2) begin //If window is not slide, or if it's already slide but not enough( at positon 1 and 2), then do slide
		$display("Test slide position 2  %d",slide_position );
		state_temp <= 0;
		window_Initial <= True;
		sobelConvert <= False;
	end
	
	else begin // If windown is aldread slide, then come to Sobel Filter 
		$display("Test slide position 3 %d",slide_position );
		sobelConvert <= True;
		slide <= False;
		slide_finish <= False; //Reset slide status
	end

		
  endrule   

     /* slide window to make room to get new data in, this will create new window data for sobel operator */
   /* rule windowBuffer_slide if(sobelConvert == False && window_Initial == False && rowBuffer_inital == False ); //Sobel needs new data, this sobelConvert is a status to tell window buffer to slide
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
    
   

	Reg#(Int#(8)) gx_reg11 <- mkReg(-1);
	Reg#(Int#(8)) gx_reg12 <- mkReg(0);
	Reg#(Int#(8)) gx_reg13 <- mkReg(1);
	Reg#(Int#(8)) gx_reg21 <- mkReg(-2);
	Reg#(Int#(8)) gx_reg22 <- mkReg(0);
	Reg#(Int#(8)) gx_reg23 <- mkReg(2);
	Reg#(Int#(8)) gx_reg31 <- mkReg(-1);
	Reg#(Int#(8)) gx_reg32 <- mkReg(0);
	Reg#(Int#(8)) gx_reg33 <- mkReg(1);
	
	Reg#(Int#(8)) gy_reg11 <- mkReg(-1);
	Reg#(Int#(8)) gy_reg12 <- mkReg(-2);
	Reg#(Int#(8)) gy_reg13 <- mkReg(-1);
	Reg#(Int#(8)) gy_reg21 <- mkReg(0);
	Reg#(Int#(8)) gy_reg22 <- mkReg(0);
	Reg#(Int#(8)) gy_reg23 <- mkReg(0);
	Reg#(Int#(8)) gy_reg31 <- mkReg(1);
	Reg#(Int#(8)) gy_reg32 <- mkReg(2);
	Reg#(Int#(8)) gy_reg33 <- mkReg(1);	
	
	Reg#(Int#(16)) sum_1 <- mkReg(0);
	Reg#(Int#(16)) sum_2 <- mkReg(0);
	Reg#(Int#(16)) sum_12 <- mkReg(0);
	
	Reg#(Bit#(8)) sobelState <- mkReg(0);
   rule sobelOperator(sobelConvert == True && sobelState == 0);
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
	
	$display("Start Sobel Calculation");
	sum_1 <= signExtend(gx_reg11*unpack(reg11)) + signExtend(gx_reg12*unpack(reg12)) + signExtend(gx_reg13*unpack(reg13))+ signExtend(gx_reg21*unpack(reg21))+ signExtend(gx_reg22*unpack(reg22))+ signExtend(gx_reg23*unpack(reg23))+ signExtend(gx_reg31*unpack(reg31))+ signExtend(gx_reg32*unpack(reg32))+ signExtend(gx_reg33*unpack(reg33));
	sum_2 <= signExtend(gy_reg11*unpack(reg11)) + signExtend(gy_reg12*unpack(reg12)) + signExtend(gy_reg13*unpack(reg13))+ signExtend(gy_reg21*unpack(reg21))+ signExtend(gy_reg22*unpack(reg22))+ signExtend(gy_reg23*unpack(reg23))+ signExtend(gy_reg31*unpack(reg31))+ signExtend(gy_reg32*unpack(reg32))+ signExtend(gy_reg33*unpack(reg33));
	sobelState <= sobelState + 1;
   endrule
   
   
   /*Absolute value here*/
   FIFOF#(Bit#(8)) sum1Buffer <- mkSizedFIFOF(5);
   FIFOF#(Bit#(8)) sum2Buffer <- mkSizedFIFOF(5);  
   rule absSum1(sobelConvert == True && sobelState == 1);
   	if( sum_1 < 0) begin
   		sum_1 <= sum_1*-1;
   		//sum1Buffer.enq(-sum_1);
   	end
   	//else begin
   		//sum1Buffer.enq(sum_1);
   	//end
   	
   	if( sum_2 < 0) begin
   		sum_2 <= sum_2*-1;
   		//sum2Buffer.enq(-sum_2);
   	end
   	//else begin
   		//sum2Buffer.enq(sum_1);
   	//end
   	sobelState <= sobelState + 1;
   endrule
   
	
   
   rule sumUp(sobelConvert == True && sobelState == 2);
   	//r1 <- sum1Buffer.first(); sum1Buffer.deq;
   	//r2 <- sum2Buffer.first(); sum2Buffer.deq;
   	sum_12 <= sum_1 + sum_2;
   	sobelState <= sobelState + 1;
   endrule
   
   rule limitMagnitude(sobelConvert == True && sobelState == 3);
   	if (sum_12 > 255) begin
   		sum_12 <= 255;
   	end
   	sobelState <= sobelState + 1;
   endrule
   
   Reg#(Int#(16)) threshold <- mkReg(2);
   Reg#(Bit#(8)) outPixel <- mkReg(0);		
   rule thresholdPixel(sobelConvert == True && sobelState == 4);
   	if (sum_12 <= threshold) begin
   		outPixel <= 0;
   	end
   	else begin
   		outPixel <= pack(sum_12)[7:0];
   	end
   	sobelState <= sobelState + 1;
   	
   endrule
   
   Reg#(int) test1 <- mkReg(-1);	
   Reg#(int) test2 <- mkReg(2);	
   Reg#(Int#(8)) test3 <- mkReg(-2);
   Reg#(Bit#(8)) test4 <- mkReg(3);
   rule writePixel(sobelConvert == True && sobelState == 5);
   	/*Need another window*/
	sobelConvert <= False;
	sobelState <= 0;
	if(bufferRowCount < image_length*image_length)
		slide <= True;
	$display("Finish Filter, outPixel is %d",outPixel);
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
