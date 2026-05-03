`timescale 1ns/1ps

module tb_adder ();
    logic [31:0] a, b;
    logic [31:0] result;    // result = a + b
    logic [7:0] status;     // Status bits for the result
    logic [2:0] round;      // Rounding mode
    bit clk, resetn;        // Clock and reset signals

    // Testbench variables
    int random_success = 0;
    int random_total = 0;
    int corner_success = 0;
    int corner_total = 0;
    int current_test_type = 0; // 0: Random, 1: Corner

    logic [31:0] expected_queue[$];
    logic [31:0] a_queue[$];
    logic [31:0] b_queue[$];
    logic [2:0] round_queue[$];
    int type_queue[$];

    // Instantiate the DUT
    fp_adder_top dut (
        .clk(clk),
        .resetn(resetn),
        .a(a),
        .b(b),
        .round(round),
        .result(result),
        .status(status)
    );

    // Instantiate the hardfloat reference model
    logic [31:0] results_hf;	
    logic [31:0] results_ref;	
    logic [2:0] rnd_hf;
    logic [31:0] a_hf, b_hf;	

    logic [32:0] rec_a_hf, rec_b_hf, rec_out_hf;
    logic [4:0] flags_hf;

    assign rnd_hf = round;

    fNToRecFN #(8, 24) a_conv (.in(a_hf), .out(rec_a_hf));
    fNToRecFN #(8, 24) b_conv (.in(b_hf), .out(rec_b_hf));

    addRecFN #(8, 24) adder_hf (
        .control(1'b0),
        .subOp(1'b0),
        .a(rec_a_hf),
        .b(rec_b_hf),
        .roundingMode(rnd_hf),
        .out(rec_out_hf),
        .exceptionFlags(flags_hf)
    );

    recFNToFN #(8, 24) out_conv (.in(rec_out_hf), .out(results_hf));

    // Update the reference model inputs
    always_comb begin
        if(a[30:23] == '1) begin
            a_hf = {a[31], {8{1'b1}}, {23{1'b0}}};
        end
        else if(a[30:23] == '0 ) begin
            a_hf = {a[31], {31{1'b0}}};
        end
        else begin
            a_hf = a;
        end

        if(b[30:23] == '1) begin
            b_hf = {b[31], {8{1'b1}}, {23{1'b0}}};
        end
         else if(b[30:23] == '0 ) begin
            b_hf = {b[31], {31{1'b0}}};
        end
        else begin
            b_hf = b;
        end

        if(results_hf[30:23] == '0 && |results_hf[22:0]) begin
            if (round == 3'b001 || round == 3'b000 || (round == 3'b010 && !results_hf[31]) || (round == 3'b011 && results_hf[31]) || round == 3'b100)
                results_ref = {results_hf[31], {31{1'b0}}};
            else
                results_ref = {results_hf[31], {7{1'b0}}, 1'b1, {23{1'b0}}};
        end
        else if(results_hf[30:23] == '1 && |results_hf[22:0]) begin
            results_ref = {results_hf[31], {8{1'b1}}, {23{1'b0}}};
        end
        else
            results_ref = results_hf;
    end

    // Verification Checks
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            expected_queue.delete();
            a_queue.delete();
            b_queue.delete();
            round_queue.delete();
            type_queue.delete();
        end else begin
            expected_queue.push_back(results_ref);
            a_queue.push_back(a);
            b_queue.push_back(b);
            round_queue.push_back(round);
            type_queue.push_back(current_test_type);

            // Pop and check after 2 cycles
            if (expected_queue.size() > 2) begin
                automatic logic [31:0] exp  = expected_queue.pop_front();
                automatic logic [31:0] pa   = a_queue.pop_front();
                automatic logic [31:0] pb   = b_queue.pop_front();
                automatic logic [2:0]  prnd = round_queue.pop_front();
                automatic int          typ  = type_queue.pop_front();

                if (typ == 0) random_total++; else corner_total++;
            
                if (result === exp) begin
                    if (typ == 0) random_success++; else corner_success++;
                end else begin
                    $display("ERROR [%s] a=%h b=%h rnd=%0d | got=%h  exp=%h", typ == 0 ? "RANDOM" : "CORNER", pa, pb, prnd, result, exp);
                end
            end
        end
    end

    // Stimulus
    always #5 clk = ~clk;

    typedef enum int {
        NEG_NAN=0, POS_NAN=1, NEG_INF=2, POS_INF=3, NEG_NORM=4, POS_NORM=5,
        NEG_DENORM=6, POS_DENORM=7, NEG_ZERO=8, POS_ZERO=9
    } corner_type_t;

    function automatic logic [31:0] get_corner(corner_type_t ct);
        logic [22:0] rnd_mnt;
        logic [7:0] rnd_exp;
        
        rnd_mnt = $urandom();
        rnd_exp = $urandom_range(1, 254);
        case (ct)
            NEG_NAN:    return {1'b1, 8'hFF, 1'b1, rnd_mnt[21:0]};
            POS_NAN:    return {1'b0, 8'hFF, 1'b1, rnd_mnt[21:0]};
            NEG_INF:    return 32'hFF800000;
            POS_INF:    return 32'h7F800000;
            NEG_NORM:   return {1'b1, rnd_exp, rnd_mnt};
            POS_NORM:   return {1'b0, rnd_exp, rnd_mnt};
            NEG_DENORM: return {1'b1, 8'h00, 1'b1, rnd_mnt[21:0]};
            POS_DENORM: return {1'b0, 8'h00, 1'b1, rnd_mnt[21:0]};
            NEG_ZERO:   return 32'h80000000;
            POS_ZERO:   return 32'h00000000;
            default:    return 32'b0;
        endcase
    endfunction

    task run_random_tests();
        current_test_type = 0;
        for (int i = 0; i < 1000; i++) begin
            @(negedge clk);
            a = $urandom();
            b = $urandom();
            round = $urandom_range(0, 4);
        end
    endtask

    task run_corner_tests();
        current_test_type = 1;
        for (int i = 0; i < 10; i++) begin
            for (int j = 0; j < 10; j++) begin
                @(negedge clk);
                a = get_corner(corner_type_t'(i));
                b = get_corner(corner_type_t'(j));
                round = $urandom_range(0, 4);
            end
        end
    endtask

    initial begin
        clk = 0;
        resetn = 0;
        a = 0; b = 0; round = 0;
        #25 resetn = 1;

        run_random_tests();
        run_corner_tests();

        repeat(5) @(negedge clk);

        $display("-------------------------------------------");
        $display("Total Tests Executed: %0d", random_total + corner_total);
        $display("Random Tests: %0d / %0d SUCCESS", random_success, random_total);
        $display("Corner Tests: %0d / %0d SUCCESS", corner_success, corner_total);
        $display("-------------------------------------------");
        $stop;
    end

endmodule