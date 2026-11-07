`default_nettype none
`timescale 1ns / 1ps

/*
 * Audio testbench: runs the design at its real clock and writes the piezo
 * voltage (uo[0] - uo[1]) as one character per sample: '+', '-' or '0'.
 * test/wav.py turns that file into a WAV.
 *
 * Plusargs:
 *   +slots=N    16th-note slots to simulate (default 256 = one loop)
 *   +ui=N       value for ui_in (default 0)
 *   +out=FILE   sample file (default wav_samples.txt)
 *
 * Samples every 28 clocks: 1.24 MHz / 28 = 44286 Hz.
 */
module wav_tb ();
  reg clk = 0;
  reg rst_n = 0;
  reg [7:0] ui_in = 0;
  wire [7:0] uo_out, uio_out, uio_oe;
`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  tt_um_aerospace_venoms_nyancat dut (
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (8'd0),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (1'b1),
      .clk    (clk),
      .rst_n  (rst_n)
  );

  // 1.24 MHz -> 806.45 ns period; the exact value only matters for the
  // waveform viewer, sampling is done in clock cycles.
  always #403 clk = ~clk;

  integer fd, slots, ui, k;
  reg [8*256-1:0] fname;
  initial begin
    if (!$value$plusargs("slots=%d", slots)) slots = 256;
    if (!$value$plusargs("ui=%d", ui)) ui = 0;
    if (!$value$plusargs("out=%s", fname)) fname = "wav_samples.txt";
    ui_in = ui[7:0];
    fd = $fopen(fname, "w");
    repeat (4) @(posedge clk);
    rst_n = 1;
    for (k = 0; k < slots * 131072 / 28; k = k + 1) begin  // 2^17 clocks per slot
      repeat (28) @(posedge clk);
      $fwrite(fd, "%s", (uo_out[0] & ~uo_out[1]) ? "+" : (uo_out[1] & ~uo_out[0]) ? "-" : "0");
    end
    $fclose(fd);
    $finish;
  end
endmodule
