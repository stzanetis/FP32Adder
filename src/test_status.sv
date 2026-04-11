module test_status_bits(
    input logic [7:0] status
);
    // Bit 0: Zero
    // Bit 1: Infinity
    // Bit 2: Invalid (NaN)
    // Bit 3: Tiny
    // Bit 4: Huge
    // Bit 5: Inexact
    logic zero_f, inf_f, nan_f, tiny_f, huge_f, inexact_f;
    assign zero_f = status[0];
    assign inf_f = status[1];
    assign nan_f = status[2];
    assign tiny_f = status[3];
    assign huge_f = status[4];
    assign inexact_f = status[5];

    // Immediate Assertions: Assert that conflicting status bits are never asserted simultaneously
    always_comb begin
        if (zero_f) begin
            assert (!inf_f) else $error("Zero and Infinity cannot be asserted together");
            assert (!nan_f) else $error("Zero and Invalid cannot be asserted together");
            assert (!tiny_f) else $error("Zero and Tiny cannot be asserted together");
            assert (!huge_f) else $error("Zero and Huge cannot be asserted together");
        end
        if (inf_f) begin
            assert (!nan_f) else $error("Infinity and Invalid cannot be asserted together");
            assert (!tiny_f) else $error("Infinity and Tiny cannot be asserted together");
            assert (!huge_f) else $error("Infinity and Huge cannot be asserted together");
            assert (!zero_f) else $error("Infinity and Zero cannot be asserted together");
        end
        if (nan_f) begin
            assert (!tiny_f) else $error("Invalid and Tiny cannot be asserted together");
            assert (!huge_f) else $error("Invalid and Huge cannot be asserted together");
            assert (!inexact_f) else $error("Invalid and Inexact cannot be asserted together");
        end
        if (tiny_f) begin
            assert (!huge_f) else $error("Tiny and Huge cannot be asserted together");
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
    assert property (p_zero) else $error("test_status_z_combinations: Zero status asserted but exponent is not 0.");

    // If the 'inf' status bit asserts to 1 then at the same cycle all the bits of the exponent of 'z' must be equal to 1.
    property p_inf;
        @(posedge clk) inf_f |-> (z[30:23] == 8'hFF);
    endproperty
    assert property (p_inf) else $error("test_status_z_combinations: Inf status asserted but exponent is not all 1s.");

    // If the 'nan' status bit asserts to 1 then 3 cycles before all the bits of the exponent of 'a' and 'b' must be equal to 1 and the 'a' and 'b' signals have opposite signs.
    property p_nan;
        @(posedge clk) nan_f |-> ($past(a[30:23], 3) == 8'hFF && $past(b[30:23], 3) == 8'hFF && ($past(a[31], 3) != $past(b[31], 3)));
    endproperty
    assert property (p_nan) else $error("test_status_z_combinations: NaN status asserted but inputs 3 cycles ago were not +Inf and -Inf.");

    // If the 'huge' status bit asserts to 1 then at the same cycle all the bits of the exponent of 'z' must be equal to 1, or all the bits of the exponent of 'z' except the LSB must be equal to 1, the LSB must be 0 and all the bits of the mantissa of 'z' to be equal to 1 (maxNormal case).
    property p_huge;
        @(posedge clk) huge_f |-> ((z[30:23] == 8'hFF) || (z[30:23] == 8'hFE && z[22:0] == 23'h7FFFFF));
    endproperty
    assert property (p_huge) else $error("test_status_z_combinations: Huge status asserted but output is neither Inf nor maxNormal.");

endmodule
