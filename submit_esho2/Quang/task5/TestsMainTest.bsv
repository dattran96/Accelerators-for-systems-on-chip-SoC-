package TestsMainTest;
    import StmtFSM :: *;
    import TestHelper :: *;
    import AXIConverter :: *;

    (* synthesize *)
    module [Module] mkTestsMainTest(TestHandler);

       //AXIConverter dut <- mkAXIConverter();

        Stmt s = {
            seq
                $display("Hello World from the testbench.");
            endseq
        };
       FSM testFSM <- mkFSM(s);

        method Action go();
            testFSM.start();
        endmethod

        method Bool done();
            return testFSM.done();
        endmethod
    endmodule

endpackage
