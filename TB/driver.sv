// =============================================================================
// axi4_driver.sv - drives the DUT pins for one transaction at a time
// Included inside axi4_pkg (see axi4_top.sv)
// =============================================================================

class axi4_driver;

    virtual axi4_if             vif;
    mailbox #(axi4_transaction) gen2drv;
    event                       drv_done;

    function new(virtual axi4_if vif, mailbox #(axi4_transaction) gen2drv, event drv_done);
        this.vif = vif;
        this.gen2drv = gen2drv;
        this.drv_done = drv_done;
    endfunction

    task run();
        axi4_transaction tr;
        forever begin
            gen2drv.get(tr);
            if (tr.is_write) drive_write(tr);
            else              drive_read(tr);
            -> drv_done;
        end
    endtask

    task drive_write(axi4_transaction tr);
        int beats = tr.beats();

        @(posedge vif.ACLK);
        vif.AWID    <= tr.id;
        vif.AWADDR  <= tr.addr;
        vif.AWLEN   <= tr.len;
        vif.AWSIZE  <= tr.size;
        vif.AWBURST <= tr.burst;
        vif.AWVALID <= 1'b1;

        do @(posedge vif.ACLK); while (!vif.AWREADY);
        vif.AWVALID <= 1'b0;

        for (int i = 0; i < beats; i++) begin
            vif.WDATA  <= tr.wdata[i];
            vif.WSTRB  <= tr.wstrb[i];
            vif.WLAST  <= (i == beats - 1);
            vif.WVALID <= 1'b1;
            do @(posedge vif.ACLK); while (!vif.WREADY);
        end
        vif.WVALID <= 1'b0;
        vif.WLAST  <= 1'b0;

        vif.BREADY <= 1'b1;
        do @(posedge vif.ACLK); while (!vif.BVALID);
        tr.bresp = vif.BRESP;
        @(posedge vif.ACLK);
        vif.BREADY <= 1'b0;
    endtask

    task drive_read(axi4_transaction tr);
        int beats = tr.beats();

        @(posedge vif.ACLK);
        vif.ARID    <= tr.id;
        vif.ARADDR  <= tr.addr;
        vif.ARLEN   <= tr.len;
        vif.ARSIZE  <= tr.size;
        vif.ARBURST <= tr.burst;
        vif.ARVALID <= 1'b1;

        do @(posedge vif.ACLK); while (!vif.ARREADY);
        vif.ARVALID <= 1'b0;

        vif.RREADY <= 1'b1;
        for (int i = 0; i < beats; i++) begin
            do @(posedge vif.ACLK); while (!vif.RVALID);
            tr.rdata[i] = vif.RDATA;
            tr.rresp[i] = vif.RRESP;
        end
        vif.RREADY <= 1'b0;
    endtask

endclass