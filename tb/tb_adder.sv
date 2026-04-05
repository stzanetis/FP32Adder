// ----------------------------------------------------------------------
// tb_adder.sv
// Reference testbench
// Use the code above (always_comb block) to habdle the exception cases on hardfloat
// ----------------------------------------------------------------------

`timescale 1ns/1ps

module tb_adder ();
    logic [31:0] result;        // result = a + b
    logic [7:0] status;         // Status bits for the result
    logic [31:0] a, b;
    logic [2:0] round;            // Rounding mode
    bit clk, resetn;            // Clock and reset signals

    // -------------------  Testbench variables -------------------



    // -------------------  Instantiate the DUT -------------------
    
	


	// -------------------	Instantiate the hardfloat reference model -------------------
	logic [31:0] results_hf;	// The results_hf 32-bit floatinf point number (after the recoding in Hardfloat), will be translated to the results_ref
	logic [31:0] results_ref;	// This is the golden reference value to be compared with the DUT result
	logic [2:0] rnd_hf;
	logic [31:0] a_hf, b_hf;	// These will be the floating point 32-bit inputs to the Hardfloat rec modules


	// -------------------	Update the reference model inputs -------------------
	always_comb begin
		// If a is NaN => Inf
		if(a[30:23] == '1) begin
			a_hf = {a[31], {8{1'b1}}, {23{1'b0}}};
		end
		// If a is denorm => Zero
		else if(a[30:23] == '0 ) begin
			a_hf = {a[31], {31{1'b0}}};
		end
		else begin
			a_hf = a;
		end

		// If b is NaN => Inf
		if(b[30:23] == '1) begin
			b_hf = {b[31], {8{1'b1}}, {23{1'b0}}};
		end
		// If b is denorm => Zero
		 else if(b[30:23] == '0 ) begin
			b_hf = {b[31], {31{1'b0}}};
		end
		else begin
			b_hf = b;
		end

		// If result is denorm => Zero or Min normal
		if(results_hf[30:23] == '0 && |results_hf[22:0]) begin
			if (round == 3'b001 || round == 3'b000 || (round == 3'b010 && !results_hf[31]) || (round == 3'b011 && results_hf[31]) || round == 3'b100)
				results_ref = {results_hf[31], {31{1'b0}}};
			else
				results_ref = {results_hf[31], {7{1'b0}}, 1'b1, {23{1'b0}}};
		end
		// If result is NaN => Inf
		else if(results_hf[30:23] == '1 && |results_hf[22:0]) begin
			results_ref = {results_hf[31], {8{1'b1}}, {23{1'b0}}};
		end
		else
			results_ref = results_hf;
	end

    // -------------------  Stimulus -------------------
    
endmodule