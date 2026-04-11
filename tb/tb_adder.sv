// ----------------------------------------------------------------------
// tb_adder.sv
// Reference testbench
// ----------------------------------------------------------------------

`timescale 1ns/1ps

module tb_adder ();
    logic [31:0] result;    // result = a + b
    logic [7:0] status;     // Status bits for the result
    logic [31:0] a, b;
    logic [2:0] round;      // Rounding mode
    bit clk, resetn;        // Clock and reset signals

    // -------------------  Testbench variables -------------------
    int random_success = 0;
    int random_total = 0;
    int corner_success = 0;
    int corner_total = 0;
    int current_test_type = 0; // 0=random, 1=corner

    logic [31:0] expected_queue[$];
    logic [31:0] a_queue[$];
    logic [31:0] b_queue[$];
    logic [2:0] round_queue[$];

    // Pipeline outputs to match SVA 3-delay cycles (from negedge input to posedge check)
    logic [31:0] result_comb;
    logic [7:0] status_comb;
    logic [31:0] result_d1, result_d2;
    logic [7:0] status_d1, status_d2;

    // -------------------  Instantiate the DUT -------------------
    fp_adder dut (
        .a(a),
        .b(b),
        .round(round),
        .result(result_comb),
        .status(status_comb)
    );

    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            result_d1 <= 0; result_d2 <= 0; result <= 0;
            status_d1 <= 0; status_d2 <= 0; status <= 0;
        end else begin
            result_d1 <= result_comb; result_d2 <= result_d1; result <= result_d2;
            status_d1 <= status_comb; status_d2 <= status_d1; status <= status_d2;
        end
    end

    // -------------------	Instantiate the hardfloat reference model -------------------
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

    // -------------------	Update the reference model inputs -------------------
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

    // -------------------  Verification Checker -------------------
    always_ff @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            expected_queue.delete();
            a_queue.delete();
            b_queue.delete();
            round_queue.delete();
        end else begin
            expected_queue.push_back(results_ref);
            a_queue.push_back(a);
            b_queue.push_back(b);
            round_queue.push_back(round);

            if (expected_queue.size() > 3) begin
                automatic logic [31:0] exp_val;
                automatic logic [31:0] pop_a;
                automatic logic [31:0] pop_b;
                automatic logic [2:0] pop_r;
                
                exp_val = expected_queue.pop_front();
                pop_a = a_queue.pop_front();
                pop_b = b_queue.pop_front();
                pop_r = round_queue.pop_front();
                
                if (current_test_type == 0) random_total++;
                else corner_total++;

                if (result === exp_val || ((result[30:23] == 8'hFF && result[22:0] != 0) && (exp_val[30:23] == 8'hFF && exp_val[22:0] != 0))) begin
                    if (current_test_type == 0) random_success++;
                    else corner_success++;
                end else begin
                    $display("ERROR [%0s]: a=%h b=%h rnd=%b | Expected=%h Actual=%h", 
                        (current_test_type == 0) ? "RANDOM" : "CORNER", pop_a, pop_b, pop_r, exp_val, result);
                end
            end
        end
    end

    // -------------------  Stimulus -------------------
    always #5 clk = ~clk;

    typedef enum int {
        NEG_NAN=0, POS_NAN=1, NEG_INF=2, POS_INF=3, NEG_NORM=4, POS_NORM=5,
        NEG_DENORM=6, POS_DENORM=7, NEG_ZERO=8, POS_ZERO=9
    } corner_type_t;

    function automatic logic [31:0] get_corner(corner_type_t ct);
        logic [22:0] rnd_mnt;
        logic [7:0] rnd_exp;
        
        rnd_mnt = $urandom();
        rnd_exp = $urandom_range(1, 253);
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

    // Bind SVA modules
    bind tb_adder test_status_bits tb_status_bits (.status(status));
    bind tb_adder test_status_z_combinations tb_status_z (
        .clk(clk),
        .a(a),
        .b(b),
        .z(result),
        .status(status)
    );

endmodule