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

endmodule