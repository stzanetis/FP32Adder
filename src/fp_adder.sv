module fp_adder (
    input logic [31:0] a, b,    // Floating point inputs
    input logic [2:0] round,    // Rounding mode

    output logic [31:0] result, // Floating point result
    output logic [7:0] status   // Status flags
);
    // Floating point number sign calculation stage
    logic sign;
    assign sign = (a[31] == b[31]) ? a[31] : ((a[30:0] > b[30:0]) ? a[31] : b[31]);

    // Exponent calculation stage
    logic [7:0] max_exp;
    logic [8:0] exp_diff;
    logic sign_exp_diff;

    exponent_calc u_exp_calc (
        .exp_a(a[30:23]),
        .exp_b(b[30:23]),
        .max_exp(max_exp),
        .exp_diff(exp_diff),
        .sign_exp_diff(sign_exp_diff)
    );
 
    // Mantissa calculation stage
    logic [27:0] result_mant;

    mantissa_calc u_mant_calc (
        .exp_diff(exp_diff),
        .mant_a({1'b1, a[22:0]}),   // Implicit leading 1
        .mant_b({1'b1, b[22:0]}),   // Implicit leading 1
        .sign_exp_diff(sign_exp_diff),
        .sa(a[31]),
        .sb(b[31]),
        .result_mant(result_mant)
    );

    // Truncation and normalization stage
    logic [8:0] norm_exp;
    logic [26:0] norm_mant;

    norm_adder u_norm_adder (
        .max_exp(max_exp),
        .result_mant(result_mant),
        .norm_exp(norm_exp),
        .norm_mant(norm_mant)
    );

    // Rounding stage
    logic [24:0] rounded_mant;
    logic inexact_bit;

    round_adder u_round_adder (
        .round(round),
        .norm_mant(norm_mant[25:0]),
        .z_sign(sign),
        .rounded_mant(rounded_mant),
        .inexact_bit(inexact_bit)
    );

    // Post-round normalization stage
    logic [8:0] final_exp;
    logic [22:0] final_fraction;

    always_comb begin
        if (rounded_mant[24]) begin
            // Overflow in rounding, shift right by 1
            final_fraction = rounded_mant[23:1];
            final_exp = norm_exp + 9'd1;
        end else begin
            final_fraction = rounded_mant[22:0];
            final_exp = norm_exp;
        end
    end

    logic overflow_flag;
    logic underflow_flag;

    // Overflow occurs if the exponent reaches 255 or above (since 255 is reserved for Inf/NaN) and is positive (bit 8 is 0)
    assign overflow_flag = (final_exp >= 9'd255) && (final_exp[8] == 1'b0);

    // Underflow occurs if the exponent is <= 0. Since final_exp is 9 bits, bit 8 indicates a negative number in 2's complement.
    assign underflow_flag = (final_exp == 9'd0) || (final_exp[8] == 1'b1);

    logic [31:0] z_calc;
    assign z_calc = {sign, final_exp[7:0], final_fraction};

    // Exception handling stage
    logic zero_f, inf_f, nan_f, tiny_f, huge_f, inexact_f;

    exception_adder u_exception_adder (
        .a(a),
        .b(b),
        .round(round),
        .overflow(overflow_flag),
        .underflow(underflow_flag),
        .inexact_bit(inexact_bit),
        .z_calc(z_calc),
        .result(result),
        .zero_f(zero_f),
        .inf_f(inf_f),
        .nan_f(nan_f),
        .tiny_f(tiny_f),
        .huge_f(huge_f),
        .inexact_f(inexact_f)
    );

    assign status = {1'b0, 1'b0, inexact_f, huge_f, tiny_f, nan_f, inf_f, zero_f};

endmodule