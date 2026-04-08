module lzc (
    input  logic [27:0] result_mant,
    output logic [4:0]  leading_zeroes
);

    always_comb begin
        leading_zeroes = 5'd28; // Default to all zeros
        for (int i = 27; i >= 0; i--) begin
            if (result_mant[i]) begin
                leading_zeroes = 5'(27 - i);
                break;
            end
        end
    end

endmodule