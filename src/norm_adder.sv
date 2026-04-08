module norm_adder (
    input logic [7:0] max_exp,      // Maximum exponent from the exponent calculation stage
    input logic [27:0] result_mant, // Resulting mantissa from the mantissa calculation stage

    output logic [8:0] norm_exp,    // Normalized exponent after adjustment
    output logic [26:0] norm_mant   // Normalized mantissa after adjustment
);
    logic [4:0] leading_zeroes;
    lzc lzc_inst (
        .result_mant(result_mant),
        .leading_zeroes(leading_zeroes)
    );

    always_comb begin
        if (result_mant == 0) begin
            norm_mant = 27'd0;
            norm_exp = 9'd0;
        end else if (result_mant[27]) begin
            // Result >= 2: Right shift by 1.
            norm_mant = {result_mant[27:2], result_mant[1] | result_mant[0]};
            norm_exp = {1'b0, max_exp} + 9'd1;
        end else if (result_mant[26]) begin
            // Result in [1, 2): Already normalized.
            norm_mant = result_mant[26:0];
            norm_exp = {1'b0, max_exp};
        end else begin
            // Result < 1: Left shift.
            logic [4:0] shift_amt;
            shift_amt = leading_zeroes - 1;
            norm_mant = result_mant[26:0] << shift_amt;
            
            // Protect against exponent underflow wrapping
            if ({1'b0, max_exp} > {4'b0, shift_amt})
                norm_exp = {1'b0, max_exp} - {4'b0, shift_amt};
            else
                norm_exp = 9'd0; 
        end
    end

endmodule