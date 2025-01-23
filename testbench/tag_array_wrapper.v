module tag_array_wrapper (
  input CK,
  input CS,
  input OE,
  input [1:0] WEB,
  input [4:0] A,
  input [22:0] DI,
  output [22:0] DO0,
  output [22:0] DO1
);

  wire [31:0] DO0_out, DO1_out;
  assign DO0 = DO0_out[22:0];
  assign DO1 = DO1_out[22:0];

  TS1N16ADFPCLLLVTA128X64M4SWSHOD_tag_array i_tag_array1 (
    .CLK        (CK),
    .A          (A),
    .CEB        (1'b0),  // chip enable, active LOW
    .WEB        (WEB[0]),  // write:LOW, read:HIGH
    .BWEB       ({9'b1, {23{WEB[0]}}}),  // bitwise write enable write:LOW
    .D          ({9'b0, DI}),  // Data into RAM
    .Q          (DO0_out),  // Data out of RAM
    .RTSEL      (),
    .WTSEL      (),
    .SLP        (),
    .DSLP       (),
    .SD         (),
    .PUDELAY    ()
  );

  TS1N16ADFPCLLLVTA128X64M4SWSHOD_tag_array i_tag_array2 (
    .CLK        (CK),
    .A          (A),
    .CEB        (1'b0),  // chip enable, active LOW
    .WEB        (WEB[1]),  // write:LOW, read:HIGH
    .BWEB       ({9'b1, {23{WEB[1]}}}),  // bitwise write enable write:LOW
    .D          ({9'b0, DI}),  // Data into RAM
    .Q          (DO1_out),  // Data out of RAM
    .RTSEL      (),
    .WTSEL      (),
    .SLP        (),
    .DSLP       (),
    .SD         (),
    .PUDELAY    ()
  );

endmodule
