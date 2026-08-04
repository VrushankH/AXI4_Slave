// =============================================================================
// axi4_top.sv
//   1) axi4_pkg - pulls in every testbench class file via `include so they
//      all share one package/scope (classes reference each other freely:
//      transaction <- generator/driver/monitor/scoreboard/coverage <-
//      environment <- test).
//   2) axi4_top   - top-level module: clock generation, DUT + interface
//      hookup, test start.
//
// Compile/run all 10 files together, e.g.:
//   vlog axi4_if.sv axi4_top.sv <dut_file>.sv   (axi4_top.sv includes the rest)
//   (or list every file on the simulator's compile line; include order
//    inside the package below already respects class dependencies)
// =============================================================================

// The interface is included here too (rather than relying on it being passed
// separately on the compile line) so this single file is self-contained on
// toolchains that only compile a fixed set of files, e.g. EDA Playground's
// xrun invocation, which only ever compiles design.sv + testbench.sv.
`include "axi4_if.sv"

package axi4_pkg;
    `include "axi4_transaction.sv"
    `include "axi4_generator.sv"
    `include "axi4_driver.sv"
    `include "axi4_monitor.sv"
    `include "axi4_scoreboard.sv"
    `include "axi4_coverage.sv"
    `include "axi4_environment.sv"
    `include "axi4_test.sv"
endpackage

`timescale 1ns/1ps

module axi4_top;

    import axi4_pkg::*;

    axi4_if intf();

    // clock generation only - reset is owned by the environment/test
    initial intf.ACLK = 0;
    always #5 intf.ACLK = ~intf.ACLK;   // 100 MHz

    axi4_full_slave #(
        .DATA_WIDTH (32),
        .ADDR_WIDTH (32),
        .ID_WIDTH   (4),
        .MEM_WORDS  (256)
    ) dut (
        .ACLK    (intf.ACLK),
        .ARESETn (intf.ARESETn),

        .AWID    (intf.AWID),
        .AWADDR  (intf.AWADDR),
        .AWLEN   (intf.AWLEN),
        .AWSIZE  (intf.AWSIZE),
        .AWBURST (intf.AWBURST),
        .AWVALID (intf.AWVALID),
        .AWREADY (intf.AWREADY),

        .WDATA   (intf.WDATA),
        .WSTRB   (intf.WSTRB),
        .WLAST   (intf.WLAST),
        .WVALID  (intf.WVALID),
        .WREADY  (intf.WREADY),

        .BID     (intf.BID),
        .BRESP   (intf.BRESP),
        .BVALID  (intf.BVALID),
        .BREADY  (intf.BREADY),

        .ARID    (intf.ARID),
        .ARADDR  (intf.ARADDR),
        .ARLEN   (intf.ARLEN),
        .ARSIZE  (intf.ARSIZE),
        .ARBURST (intf.ARBURST),
        .ARVALID (intf.ARVALID),
        .ARREADY (intf.ARREADY),

        .RID     (intf.RID),
        .RDATA   (intf.RDATA),
        .RRESP   (intf.RRESP),
        .RLAST   (intf.RLAST),
        .RVALID  (intf.RVALID),
        .RREADY  (intf.RREADY)
    );

    axi4_test test;
    initial begin
        test = new(intf);
        test.run();
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, axi4_top);
    end

endmodule