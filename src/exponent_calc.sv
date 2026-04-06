module exponent_calc (
    input logic [7:0] exp_a, exp_b, // Exponents of the two floating point numbers

    output logic [7:0] max_exp,     // Maximum exponent between exp_a and exp_b
    output logic [8:0] exp_diff,    // Difference between the two exponents (9 bits to accommodate negative values)
    output logic sign_exp_diff      // Sign of the exponent difference (1 if exp_a > exp_b, 0 otherwise)
);

    assign sign_exp_diff = (exp_a > exp_b);
    assign max_exp       = sign_exp_diff ? exp_a : exp_b;
    assign exp_diff      = {1'b0, exp_a} - {1'b0, exp_b};

endmodule