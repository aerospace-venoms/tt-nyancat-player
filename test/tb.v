`default_nettype none
`timescale 1ns / 1ps

/* This testbench just instantiates the module and makes some convenient wires
   that can be driven / tested by the cocotb test.py.
*/
module tb ();

  // Waveform dumping is off by default: the song is millions of cycles long.
  // Run `make WAVES=1` to get tb.fst.
  initial begin
    if ($test$plusargs("waves")) begin
      $dumpfile("tb.fst");
      $dumpvars(0, tb);
    end
  end

  // The clock is generated here rather than from cocotb: running it inside
  // the simulator is much faster. 806 ns period ~= 1.24 MHz.
  // `cycle` counts rising edges so tests can measure periods in clocks.
  reg clk = 1'b0;
  always #403 clk = ~clk;
  integer cycle = 0;
  always @(posedge clk) cycle <= cycle + 1;

  // Wire up the inputs and outputs:
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Replace tt_um_example with your module name:
  tt_um_aerospace_venoms_nyancat user_project (

      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // not reset
  );

  // Convenience taps for the tests.
  wire       out_a = uo_out[0];
  wire       out_b = uo_out[1];
  wire       led   = uo_out[2];
  wire [3:0] note  = uo_out[6:3];

  // Push-pull safety: the two piezo pins must never both be high.
  reg both_high_seen = 1'b0;
  always @(posedge clk) if (out_a & out_b) both_high_seen <= 1'b1;

endmodule
