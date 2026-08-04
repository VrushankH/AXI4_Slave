// =============================================================================
// axi4_generator.sv - produces transactions (random + directed) and hands
// them to the driver, waiting for each to complete before issuing the next.
// Included inside axi4_pkg (see axi4_top.sv)
// =============================================================================

class axi4_generator;

    mailbox #(axi4_transaction) gen2drv;
    event                       drv_done;
    int                         num_transactions = 20;

    function new(mailbox #(axi4_transaction) gen2drv, event drv_done);
        this.gen2drv = gen2drv;
        this.drv_done = drv_done;
    endfunction

    // fully random regression run
    task run();
        axi4_transaction tr;
        repeat (num_transactions) begin
            tr = new();
            if (!tr.randomize())
                $fatal(1, "[GEN] randomize() failed");
            tr.display(" (random)");
            gen2drv.put(tr);
            @(drv_done);
        end
    endtask

    // directed send used by test-case helper tasks in the environment
    task send(axi4_transaction tr);
        gen2drv.put(tr);
        @(drv_done);
    endtask

endclass