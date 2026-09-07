// =============================================================================
// axi4_monitor.sv - passively watches the bus, reconstructs completed
// transactions, and forwards them to the scoreboard and coverage collector
// Included inside axi4_pkg (see axi4_top.sv)
// =============================================================================

class axi4_monitor;

    virtual axi4_if             vif;
    mailbox #(axi4_transaction) mon2scb;
    mailbox #(axi4_transaction) mon2cov;

    function new(virtual axi4_if vif,
                 mailbox #(axi4_transaction) mon2scb,
                 mailbox #(axi4_transaction) mon2cov);
        this.vif = vif;
        this.mon2scb = mon2scb;
        this.mon2cov = mon2cov;
    endfunction

    task run();
        fork
            watch_write();
            watch_read();
        join_none
    endtask

    task watch_write();
        forever begin
            @(posedge vif.ACLK);
            if (vif.ARESETn && vif.AWVALID && vif.AWREADY) begin
                axi4_transaction tr = new();
                int beats;
                tr.is_write = 1;
                tr.id       = vif.AWID;
                tr.addr     = vif.AWADDR;
                tr.len      = vif.AWLEN;
                tr.size     = vif.AWSIZE;
                tr.burst    = vif.AWBURST;
                beats       = tr.beats();

                for (int i = 0; i < beats; i++) begin
                    @(posedge vif.ACLK);
                    while (!(vif.WVALID && vif.WREADY)) @(posedge vif.ACLK);
                    tr.wdata[i] = vif.WDATA;
                    tr.wstrb[i] = vif.WSTRB;
                end

                @(posedge vif.ACLK);
                while (!(vif.BVALID && vif.BREADY)) @(posedge vif.ACLK);
                tr.bresp = vif.BRESP;

                mon2scb.put(tr);
                mon2cov.put(tr);
            end
        end
    endtask

    task watch_read();
        forever begin
            @(posedge vif.ACLK);
            if (vif.ARESETn && vif.ARVALID && vif.ARREADY) begin
                axi4_transaction tr = new();
                int beats;
                tr.is_write = 0;
                tr.id       = vif.ARID;
                tr.addr     = vif.ARADDR;
                tr.len      = vif.ARLEN;
                tr.size     = vif.ARSIZE;
                tr.burst    = vif.ARBURST;
                beats       = tr.beats();

                for (int i = 0; i < beats; i++) begin
                    @(posedge vif.ACLK);
                    while (!(vif.RVALID && vif.RREADY)) @(posedge vif.ACLK);
                    tr.rdata[i] = vif.RDATA;
                    tr.rresp[i] = vif.RRESP;
                end

                mon2scb.put(tr);
                mon2cov.put(tr);
            end
        end
    endtask

endclass