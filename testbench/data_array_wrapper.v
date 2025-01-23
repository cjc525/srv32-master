module data_array_wrapper (
  input CK,
  input CS, 
  input [1:0] OE,
  input [1:0] WEB, // WEB[0]->set0; WEB[1]->set1
  input [15:0] BWEB,  
  input [4:0] A,
  input [127:0] DI,
  output reg [127:0] DO
);

  reg [63:0] DO1, DO2, DO3, DO4;

  assign DO = (OE[0])? {DO2, DO1} : {DO4, DO3};

  TS1N16ADFPCLLLVTA128X64M4SWSHOD_data_array i_data_array1_1 (
    .CLK        (CK),
    .A          (A),
    .CEB        (1'b0),  // chip enable, active LOW
    .WEB        (WEB[0]),  // write:LOW, read:HIGH
    .BWEB       ({{8{BWEB[7]}}, {8{BWEB[6]}}, {8{BWEB[5]}}, {8{BWEB[4]}}, {8{BWEB[3]}}, {8{BWEB[2]}}, {8{BWEB[1]}}, {8{BWEB[0]}}}),  // bitwise write enable write:LOW
    .D          (DI[63:0]),  // Data into RAM
    .Q          (DO1),  // Data out of RAM
    .RTSEL      (),
    .WTSEL      (),
    .SLP        (),
    .DSLP       (),
    .SD         (),
    .PUDELAY    ()
  );
  
  
    TS1N16ADFPCLLLVTA128X64M4SWSHOD_data_array i_data_array1_2 (
    .CLK        (CK),
    .A          (A),
    .CEB        (1'b0),  // chip enable, active LOW
    .WEB        (WEB[0]),  // write:LOW, read:HIGH
    .BWEB       ({{8{BWEB[15]}}, {8{BWEB[14]}}, {8{BWEB[13]}}, {8{BWEB[12]}}, {8{BWEB[11]}}, {8{BWEB[10]}}, {8{BWEB[9]}}, {8{BWEB[8]}}}),  // bitwise write enable write:LOW
    .D          (DI[127:64]),  // Data into RAM
    .Q          (DO2),  // Data out of RAM
    .RTSEL      (),
    .WTSEL      (),
    .SLP        (),
    .DSLP       (),
    .SD         (),
    .PUDELAY    ()
  );

  TS1N16ADFPCLLLVTA128X64M4SWSHOD_data_array i_data_array2_1 (
    .CLK        (CK),
    .A          (A),
    .CEB        (1'b0),  // chip enable, active LOW
    .WEB        (WEB[1]),  // write:LOW, read:HIGH
    .BWEB       ({{8{BWEB[7]}}, {8{BWEB[6]}}, {8{BWEB[5]}}, {8{BWEB[4]}}, {8{BWEB[3]}}, {8{BWEB[2]}}, {8{BWEB[1]}}, {8{BWEB[0]}}}),  // bitwise write enable write:LOW
    .D          (DI[63:0]),  // Data into RAM
    .Q          (DO3),  // Data out of RAM
    .RTSEL      (),
    .WTSEL      (),
    .SLP        (),
    .DSLP       (),
    .SD         (),
    .PUDELAY    ()
  );
  
  TS1N16ADFPCLLLVTA128X64M4SWSHOD_data_array i_data_array2_2 (
    .CLK        (CK),
    .A          (A),
    .CEB        (1'b0),  // chip enable, active LOW
    .WEB        (WEB[1]),  // write:LOW, read:HIGH
    .BWEB       ({{8{BWEB[15]}}, {8{BWEB[14]}}, {8{BWEB[13]}}, {8{BWEB[12]}}, {8{BWEB[11]}}, {8{BWEB[10]}}, {8{BWEB[9]}}, {8{BWEB[8]}}}),  // bitwise write enable write:LOW
    .D          (DI[127:64]),  // Data into RAM
    .Q          (DO4),  // Data out of RAM
    .RTSEL      (),
    .WTSEL      (),
    .SLP        (),
    .DSLP       (),
    .SD         (),
    .PUDELAY    ()
  );


endmodule
