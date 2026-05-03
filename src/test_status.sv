module test_status_bits(
    input logic resetn,
    input logic [7:0] status
);
    logic zero_f, inf_f, nan_f, tiny_f, huge_f, inexact_f;
    assign zero_f    = status[0];
    assign inf_f     = status[1];
    assign nan_f     = status[2];
    assign tiny_f    = status[3];
    assign huge_f    = status[4];
    assign inexact_f = status[5];

    always_comb begin
        if (resetn) begin
            if (zero_f) begin
                assert (!inf_f && !nan_f && !huge_f) else 
                    $error("FAIL: Zero can't be Inf, NaN, or Huge");
            end
            if (inf_f) begin
                assert (!zero_f && !nan_f && !tiny_f) else 
                    $error("FAIL: Inf can't be Zero, NaN, or Tiny");
            end
            if (nan_f) begin
                assert (!tiny_f) else 
                    $error("FAIL: Invalid and Tiny cannot be asserted together");

                assert (!huge_f) else 
                    $error("FAIL: Invalid and Huge cannot be asserted together");

                assert (!inexact_f) else 
                    $error("FAIL: Invalid and Inexact cannot be asserted together");
            end
            if (tiny_f) begin
                assert (!huge_f) else 
                    $error("FAIL: Tiny and Huge cannot be asserted together");
            end
        end
    end
endmodule

module test_status_z_combinations(
    input logic clk,
    input logic [31:0] a,
    input logic [31:0] b,
    input logic [31:0] z,
    input logic [7:0] status
);

    logic zero_f, inf_f, nan_f, huge_f;
    
    assign zero_f = status[0];
    assign inf_f  = status[1];
    assign nan_f  = status[2];
    assign huge_f = status[4];

    // If the 'zero' status bit asserts to 1 then at the same cycle all the bits of the exponent of 'z' must be equal to 0.
    property p_zero;
        @(posedge clk) zero_f |-> (z[30:23] == 8'h00);
    endproperty
    assert property (p_zero) 
        $display("PASS: Zero status OK");
    else 
        $error("FAIL: Zero status asserted but exponent is not 0");

    // If the 'inf' status bit asserts to 1 then at the same cycle all the bits of the exponent of 'z' must be equal to 1.
    property p_inf;
        @(posedge clk) inf_f |-> (z[30:23] == 8'hFF);
    endproperty
    assert property (p_inf) 
        $display("PASS: Inf status OK");
    else 
        $error("FAIL: Inf status asserted but exponent is not all 1s");

    // If the 'nan' status bit asserts to 1 then 2 cycles before all the bits of the exponent of 'a' and 'b' must be equal 
    // to 1 and the 'a' and 'b' signals have opposite signs
    property p_nan;
        @(posedge clk) nan_f |-> ($past(a[30:23], 2) == 8'hFF && $past(b[30:23], 2) == 8'hFF && ($past(a[31], 2) != $past(b[31], 2)));
    endproperty
    assert property (p_nan) 
        $display("PASS: NaN status OK");
    else
        $error("FAIL: NaN status asserted but inputs 2 cycles ago were not +Inf and -Inf");

    // If the 'huge' status bit asserts to 1 then at the same cycle all the bits of the exponent of 'z' must be equal to 1, 
    // or all the bits of the exponent of 'z' except the LSB must be equal to 1, the LSB must be 0 and all the bits of the 
    // mantissa of 'z' to be equal to 1 (maxNormal case).
    property p_huge;
        @(posedge clk) huge_f |-> ((z[30:23] == 8'hFF) || (z[30:23] == 8'hFE && z[22:0] == 23'h7FFFFF));
    endproperty
    assert property (p_huge) 
        $display("PASS: Huge status OK");
    else
        $error("FAIL: Huge status asserted but output is neither Inf nor maxNormal");
endmodule

bind fp_adder_top test_status_bits inst_bits (
    .resetn(resetn), 
    .status(status)
);

bind fp_adder_top test_status_z_combinations inst_z (
    .clk(clk),
    .a(a),
    .b(b),
    .z(result),
    .status(status)
);