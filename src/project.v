/*
 * Copyright (c) 2026 Ames
 * SPDX-License-Identifier: Apache-2.0
 *
 * Nyan Cat player. Plays the Nyan Cat loop as a square wave, driven
 * push-pull on uo[0]/uo[1] so a piezo across those two pins sees twice
 * the voltage swing.
 *
 * Timing at 1.24 MHz: one eighth note = 2^18 clocks (~141.9 BPM).
 * A single 26-bit counter holds {slot[7:0], position-in-slot[17:0]};
 * the song is 256 eighth-note slots (A, A', B, B).
 */

`default_nettype none

module tt_um_aerospace_venoms_nyancat (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  localparam [3:0] CODE_HOLD = 4'd0;
  localparam [3:0] CODE_REST = 4'd1;
  localparam       DIV_BITS  = 10;     // must match model/nyan.py

  // ---- controls ----
  wire       pause  = ui_in[0];     // freeze the song and mute
  wire [1:0] octave = ui_in[2:1];   // play 0..3 octaves lower
  wire       ffwd   = ui_in[3];     // fast-forward: song runs 16x faster

  // ---- song position ----
  reg  [25:0] cnt;
  wire [7:0]  slot       = cnt[25:18];
  wire        slot_start = (cnt[17:0] == 18'd0);
  wire        in_gap     = (cnt[17:14] == 4'd0);   // first ~13 ms of a slot

  // Fast-forward steps by 16 and clears the low bits, so slot_start is
  // still hit exactly once per slot whenever ffwd is toggled.
  wire [25:0] cnt_next = {cnt[25:4], ffwd ? 4'hF : cnt[3:0]} + 26'd1;

  wire [3:0] code;
  nyan_rom rom (
      .addr    ({slot[7], slot[5:0]}),   // A,A' share the A half; B,B share the B half
      .second_a(slot[7:6] == 2'b01),
      .code    (code)
  );

  reg [3:0] note;    // current note code (REST or pitch)
  reg       fresh;   // note was (re)triggered at the start of this slot

  // ---- tone generator ----
  wire [DIV_BITS-1:0] half_m1;
  nyan_pitch pitch (
      .note   (note),
      .half_m1(half_m1)
  );

  reg [DIV_BITS-1:0] div;
  reg                phase;
  reg [2:0]          pre;      // octave prescaler

  wire tone_tick = (octave == 2'd0) ? 1'b1 :
                   (octave == 2'd1) ? pre[0] :
                   (octave == 2'd2) ? &pre[1:0] : &pre[2:0];

  always @(posedge clk) begin
    if (!rst_n) begin
      cnt   <= 26'd0;
      note  <= CODE_REST;
      fresh <= 1'b0;
      div   <= {DIV_BITS{1'b0}};
      phase <= 1'b0;
      pre   <= 3'd0;
    end else if (!pause) begin
      cnt <= cnt_next;
      pre <= pre + 3'd1;

      if (tone_tick) begin
        if (div == {DIV_BITS{1'b0}}) begin
          div   <= half_m1;
          phase <= ~phase;
        end else begin
          div <= div - 1'b1;
        end
      end

      if (slot_start) begin
        fresh <= (code != CODE_HOLD);
        if (code != CODE_HOLD) begin
          note  <= code;
          div   <= {DIV_BITS{1'b0}};
          phase <= 1'b0;
          pre   <= 3'd0;
        end
      end
    end
  end

  wire sounding = !pause && (note != CODE_REST) && !(fresh && in_gap);

  // Registered outputs: both pins low when silent, so no DC across the piezo.
  reg out_a, out_b, led;
  always @(posedge clk) begin
    if (!rst_n) begin
      out_a <= 1'b0;
      out_b <= 1'b0;
      led   <= 1'b0;
    end else begin
      out_a <= sounding & phase;
      out_b <= sounding & ~phase;
      led   <= sounding;
    end
  end

  assign uo_out  = {slot[0], note, led, out_b, out_a};
  assign uio_out = 8'd0;
  assign uio_oe  = 8'd0;

  wire _unused = &{ena, ui_in[7:4], uio_in, 1'b0};

endmodule
