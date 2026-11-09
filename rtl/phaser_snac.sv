// Sega Master System Light Phaser (via SNAC) to NES Zapper adapter
//
// Light: the Phaser sensor is much faster than the NES Zapper sensor. Zapper
// games expect "light" to stay asserted for roughly 10-25 scanlines after the
// target box is seen, so the Phaser TH pulse is held for HOLD scanlines.
//
// Trigger: the Phaser has a simple switch, the Zapper has a two stage trigger.
// Zapper games fire when the trigger bit falls from 1 to 0. This copies the
// virtual Zapper in zapper.sv: on a press the trigger bit is 1 for about
// 38.6 ms, then 0, and a new press is ignored for about 136 ms in total.
// The trigger is only re-armed after TL stays released for DEBOUNCE clocks
// (about 20 ms), so switch bounce on release cannot cause a second shot.
//
// th_n      : Phaser TH pin (DB9 pin 7), low = light seen
// tl_n      : Phaser TL pin (DB9 pin 6), low = trigger pressed
// light_n   : NES $4017 bit 3 value, 0 = light detected
// trigger   : NES $4017 bit 4 value, 1 = trigger half-pulled
module phaser_snac #(parameter [4:0] HOLD = 5'd26, parameter [19:0] DEBOUNCE = 20'd429545)
(
	input        clk,
	input  [8:0] scanline,
	input        th_n,
	input        tl_n,
	output       light_n,
	output       trigger
);

reg [2:0]  th_sync = 3'b111;
reg [2:0]  tl_sync = 3'b111;
reg [8:0]  old_scanline;
reg [4:0]  hold_cnt = 5'd0;
reg [21:0] trig_cnt = 22'd0;
reg        pressed  = 1'b0;
reg [19:0] rel_cnt  = 20'd0;

wire tl_pressed = ~tl_sync[2];

assign light_n = (hold_cnt == 5'd0);
assign trigger = (trig_cnt > 22'd2_100_000);

always @(posedge clk) begin
	th_sync      <= {th_sync[1:0], th_n};
	tl_sync      <= {tl_sync[1:0], tl_n};
	old_scanline <= scanline;

	// Light hold
	if (~th_sync[2])
		hold_cnt <= HOLD;
	else if (old_scanline != scanline && hold_cnt != 5'd0)
		hold_cnt <= hold_cnt - 1'b1;

	// Trigger one-shot
	if (trig_cnt != 22'd0) trig_cnt <= trig_cnt - 1'b1;

	if (trig_cnt == 22'd0 && tl_pressed && ~pressed) begin
		trig_cnt <= 22'd2_930_000;
		pressed  <= 1'b1;
	end

	// Release debounce
	if (tl_pressed)
		rel_cnt <= 20'd0;
	else if (pressed) begin
		if (rel_cnt == DEBOUNCE)
			pressed <= 1'b0;
		else
			rel_cnt <= rel_cnt + 1'b1;
	end
end

endmodule
