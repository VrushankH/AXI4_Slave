// =============================================================================
// axi4_environment.sv - instantiates and connects all TB components
// Included inside axi4_pkg (see axi4_top.sv)
// =============================================================================

class axi4_environment;

    virtual axi4_if vif;

    mailbox #(axi4_transaction) gen2drv;
    mailbox #(axi4_transaction) mon2scb;
    mailbox #(axi4_transaction) mon2cov;
    event                       drv_done;

    axi4_generator  gen;
    axi4_driver     drv;
    axi4_monitor    mon;
    axi4_scoreboard scb;
    axi4_coverage   cov;

    function new(virtual axi4_if vif);
        this.vif = vif;
        gen2drv = new();
        mon2scb = new();
        mon2cov = new();

        gen = new(gen2drv, drv_done);
        drv = new(vif, gen2drv, drv_done);
        mon = new(vif, mon2scb, mon2cov);
        scb = new(mon2scb);
        cov = new(mon2cov);
    endfunction

    // drives ARESETn: called once at the very start of the test, and again
    // explicitly by the reset-verification test case
    task apply_reset(int cycles = 5);
        vif.ARESETn = 0;
        vif.AWVALID = 0; vif.WVALID = 0; vif.BREADY = 0;
        vif.ARVALID = 0; vif.RREADY = 0;
        repeat (cycles) @(posedge vif.ACLK);
        vif.ARESETn = 1;
        @(posedge vif.ACLK);
        scb.reset_model();
    endtask

    task run();
        apply_reset();
        fork
            drv.run();
            mon.run();
            scb.run();
            cov.run();
        join_none
    endtask

    // ---------------- directed helper sequences used by tests --------------

    task do_write(bit [31:0] addr, bit [7:0] len, bit [1:0] burst,
                   bit [31:0] data [8], bit [3:0] strb [8], bit [3:0] id = 4'h1);
        axi4_transaction tr = new();
        tr.addr = addr; tr.len = len; tr.burst = burst; tr.is_write = 1;
        tr.id = id; tr.size = 3'b010;
        foreach (data[i]) tr.wdata[i] = data[i];
        foreach (strb[i]) tr.wstrb[i] = strb[i];
        tr.display(" (directed)");
        gen.send(tr);
    endtask

    task do_read(bit [31:0] addr, bit [7:0] len, bit [1:0] burst, bit [3:0] id = 4'h1);
        axi4_transaction tr = new();
        tr.addr = addr; tr.len = len; tr.burst = burst; tr.is_write = 0;
        tr.id = id; tr.size = 3'b010;
        tr.display(" (directed)");
        gen.send(tr);
    endtask

    task run_random(int n);
        gen.num_transactions = n;
        gen.run();
    endtask

endclass