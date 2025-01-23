							
module L1C_data(
    input                         clk           ,
    input                         rst           ,
    // Core to CPU wrapper
    input [32-1:0]        core_addr     ,
    input                         core_req      ,
    input                         core_write    ,	// DM_wen from CPU; modified bitwidth from 4 to 1; active high
    input [32-1:0]        core_in       ,
    // Mem to CPU wrapper
    input [32-1:0]        D_out         ,
    // CPU wrapper to core
    output reg [32-1:0] core_out      ,
    output reg                  core_wait     ,
    // CPU wrapper to Mem
    output reg                  D_req         ,
    output reg [32-1:0] D_addr        ,

    input                         axi_ready     ,
    output reg                  cpu_ready     ,
    output reg                  axi_valid     
);

    reg [5-1:0]        index        ;
    reg [128-1:0]         DA_out       ;
    reg [128-1:0]         DA_in        ;
    reg [16-1:0]        DA_write     ;
    reg [2-1:0]        DA_wen       ;
    reg [2-1:0]        DA_read      ;
    reg [23-1:0]          TA_out0      ;
    reg [23-1:0]          TA_out1      ;
    reg [23-1:0]          TA_in        ;
    reg [2-1:0]        TA_write     ;
    reg                                TA_read      ;
    reg [32-1:0]       valid        ;
    reg [32-1:0]       valid_reg    ;
    reg [32-1:0]               core_addr_reg;

    reg [1:0]                  sram_counter    ;
    integer                      i               ;   
    reg                        lru_buffer[31:0];    // 0->set0; 1->set1
    reg                        hit             ;
    reg                        hit0            ;    // set 0 hit
    reg                        hit1            ;    // set 1 hit

    assign hit0 = (core_addr_reg[31:9] == TA_out0 && valid_reg[{1'b0, core_addr_reg[8:4]}]);
    assign hit1 = (core_addr_reg[31:9] == TA_out1 && valid_reg[{1'b1, core_addr_reg[8:4]}]);
    assign hit  = (hit0 || hit1);

  
    data_array_wrapper DA(
      .A    (index)   ,
      .DO   (DA_out)  ,
      .DI   (DA_in)   ,
      .CK   (clk)     ,
      .WEB  (DA_wen)  ,
      .BWEB (DA_write),	// each bit control 1 byte, 128=16*8 bits
      .OE   (DA_read) ,
      .CS   (1'b1)
    );
    
    tag_array_wrapper  TA(
      .A    (index)   ,
      .DO0  (TA_out0) ,
      .DO1  (TA_out1) ,
      .DI   (TA_in)   ,
      .CK   (clk)     ,
      .WEB  (TA_write),
      .OE   (TA_read) ,
      .CS   (1'b1)
    );
  
    ///////////// L1C_Data Controller (READ & WRITE) ///////////////

    localparam IDLE        = 3'd0;
    localparam READ_HIT    = 3'd1;
    localparam READ_AXI    = 3'd2;
    localparam WRITE_HIT   = 3'd3;
    localparam WRITE_CACHE = 3'd4;
    localparam DONE        = 3'd5;

    reg [2:0] cstate, nstate;


    always @(posedge clk or posedge rst) begin
        if(rst) cstate <= IDLE;
        else cstate <= nstate;
    end

    always @(*) begin
        case(cstate)
            IDLE: begin
                if(core_req) begin
                    if(core_write) nstate = WRITE_HIT;
                    else nstate = READ_HIT;
                end
                else begin
                    nstate = IDLE;
                end
            end
            READ_HIT: begin
                if(hit) nstate = IDLE;
                else nstate = READ_AXI;
            end
            READ_AXI: begin
                if(sram_counter == 2'd3 && axi_ready) nstate = DONE;
                else nstate = READ_AXI;
            end
            WRITE_HIT: begin
                if(!hit) begin
                    nstate = IDLE;
                end
                else begin
                    nstate = WRITE_CACHE;
                end
            end
            WRITE_CACHE: begin
                // nstate = DONE;
                nstate = DONE;
                else nstate = WRITE_CACHE;
            end
            DONE: begin
                nstate = IDLE;
            end
            default: begin
                nstate = IDLE;
            end
        endcase
    end

    // core_out : Output instruction to CPU
    always @(*) begin
        case(cstate)
            IDLE: begin
                core_out = 32'd0;
            end
            READ_HIT: begin
                if(hit) begin
                    case(core_addr_reg[3:2])
                        2'b00: core_out = DA_out[31:0];
                        2'b01: core_out = DA_out[63:32];
                        2'b10: core_out = DA_out[95:64];
                        2'b11: core_out = DA_out[127:96];
                    endcase
                end
                else begin
                    core_out = 32'd0;
                end
            end
            READ_AXI: begin
                // core_out = 32'd0;
                if(core_addr_reg[3:2] == sram_counter) begin
                    core_out = D_out;
                end
                else begin
                    core_out = 32'd0;
                end
            end
            WRITE_HIT: begin
                core_out = 32'd0;
            end
            WRITE_CACHE: begin
                core_out = 32'd0;
            end
            DONE: begin
                core_out = 32'd0;
            end
            default: begin
                core_out = 32'd0;
            end
        endcase
    end

    // core_wait: Output busy signal to CPU
    always @(*) begin
        case(cstate)
            IDLE: begin
                core_wait = 1'b0;
            end
            READ_HIT: begin
                if(hit) begin
                    core_wait = 1'b0;
                end
                else begin
                    core_wait = 1'b1;
                end
            end
            READ_AXI: begin
                core_wait = 1'b1;
            end
            WRITE_HIT: begin
                core_wait = 1'b1;
            end
            WRITE_CACHE: begin
                core_wait = 1'b1;
            end
            DONE: begin
                core_wait = 1'b1;
            end
            default: begin
                core_wait = 1'b0;
            end
        endcase
    end

    // D_req: Ouptut request to AXI
    always @(*) begin
        case(cstate)
            IDLE: begin
                D_req = 1'b0;
            end
            READ_HIT: begin
                if(hit) begin
                    D_req = 1'b0;
                end
                else begin
                    D_req = 1'b1;
                end
            end
            READ_AXI: begin
                D_req = 1'b1;
            end
            WRITE_HIT: begin
                D_req = 1'b0;
            end
            WRITE_CACHE: begin
                D_req = 1'b0;
            end
            DONE: begin
                D_req = 1'b0;
            end
            default: begin
                D_req = 1'b0;
            end
        endcase
    end

    // D_addr: Ouptut address to AXI
    always @(*) begin
        case(cstate)
            IDLE: begin
                D_addr = 32'd0;
            end
            READ_HIT: begin
                if(hit) begin
                    D_addr = 32'd0;
                end
                else begin
                    D_addr = {core_addr_reg[31:4], 4'd0};
                end
            end
            READ_AXI: begin
                D_addr = {core_addr_reg[31:4], 4'd0};
            end
            WRITE_HIT: begin
                D_addr = 32'd0;
            end
            WRITE_CACHE: begin
                D_addr = 32'd0;
            end
            DONE: begin
                D_addr = 32'd0;
            end
            default: begin
                D_addr = 32'd0;
            end
        endcase
    end

    // index (Addr)
    always @(*) begin
        case(cstate)
            IDLE: begin
                index = core_addr[8:4];
            end
            READ_HIT: begin
                // if(hit) begin
                //     index = core_addr_reg[8:4];
                // end
                // else begin
                //     index = 5'd0;
                // end
                index = core_addr_reg[8:4];
            end
            READ_AXI: begin
                index = core_addr_reg[8:4];
            end
            WRITE_HIT: begin
                // if(hit) begin
                //     index = core_addr_reg[8:4];
                // end
                // else begin
                //     index = 5'd0;
                // end
                index = core_addr_reg[8:4];
            end
            WRITE_CACHE: begin
                index = core_addr_reg[8:4];
            end
            DONE: begin
                index = 5'd0;
            end
            default: begin
                index = 5'd0;
            end
        endcase
    end

    // Data Array
    always @(*) begin
        case(cstate)
            IDLE: begin
                DA_write = {16{1'b1}};
                DA_wen = 2'b11;
                DA_read = 2'b00;
                DA_in = 128'd0;
            end
            READ_HIT: begin
                if(hit) begin
                    DA_write = {16{1'b1}};
                    DA_wen = 2'b11;
                    DA_read = (hit0)? 2'b01 : 2'b10;
                    DA_in = 128'd0;
                end
                else begin
                    DA_write = {16{1'b1}};
                    DA_wen = 2'b11;
                    DA_read = 2'b00;
                    DA_in = 128'd0;
                end
            end
            READ_AXI: begin
                case(sram_counter)
                    2'd0: begin
                        DA_write = {{12{1'b1}}, 4'b0000};
                        DA_in = {96'd0, D_out};
                    end 
                    2'd1: begin
                        DA_write = {{8{1'b1}}, 4'b0000, {4{1'b1}}};
                        DA_in = {64'd0, D_out, 32'd0};
                    end
                    2'd2: begin
                        DA_write = {{4{1'b1}}, 4'b0000, {8{1'b1}}};
                        DA_in = {32'd0, D_out, 64'd0};
                    end
                    2'd3: begin
                        DA_write = {4'b0000, {12{1'b1}}};
                        DA_in = {D_out, 96'd0};
                    end
                endcase
                if(!valid_reg[{1'b0, core_addr_reg[8:4]}]) begin
                    DA_wen = 2'b10;
                end
                else if(!valid_reg[{1'b1, core_addr_reg[8:4]}]) begin
                    DA_wen = 2'b01;
                end
                else if(lru_buffer[core_addr_reg[8:4]] == 1'b0) begin // write into set 1
                    DA_wen = 2'b01;
                end
                else begin
                    DA_wen = 2'b10;
                end
                DA_read = 2'b00;
            end
            WRITE_HIT: begin
                DA_write = {16{1'b1}};
                DA_wen = 2'b11;
                DA_read = 2'b00;
                DA_in = 128'd0;
            end
            WRITE_CACHE: begin
                case(core_addr_reg[3:2])
                    2'b00: begin // write into first block
                        DA_write = {{12{1'b1}}, 4'b0000};
                        DA_in = {96'd0, core_in};
                    end
                    2'b01: begin // write into second block
                        DA_write = {{8{1'b1}}, 4'b0000, {4{1'b1}}};
                        DA_in = {64'd0, core_in, 32'd0};
                    end
                    2'b10: begin // write into third block
                        DA_write = {{4{1'b1}}, 4'b0000, {8{1'b1}}};
                        DA_in = {32'd0, core_in, 64'd0};
                    end
                    2'b11: begin // write into fourth block
                        DA_write = {4'b0000, {12{1'b1}}};
                        DA_in = {core_in, 96'd0};
                    end
                endcase
                // if(!valid_reg[{1'b0, core_addr_reg[8:4]}]) begin
                //     DA_wen = 2'b10;
                // end
                // else if(!valid_reg[{1'b1, core_addr_reg[8:4]}]) begin
                //     DA_wen = 2'b01;
                // end
                if(hit0) begin
                    DA_wen = 2'b10;
                end
                else if(hit1) begin
                    DA_wen = 2'b01;
                end
                else if(lru_buffer[core_addr_reg[8:4]] == 1'b0) begin // write into set 1
                    DA_wen = 2'b01;
                end
                else begin
                    DA_wen = 2'b10;
                end
                DA_read = 2'b00;
            end
            DONE: begin
                DA_write = {16{1'b1}};
                DA_wen = 2'b11;
                DA_read = 2'b00;
                DA_in = 128'd0;
            end
            default: begin
                DA_write = {16{1'b1}};
                DA_wen = 2'b11;
                DA_read = 2'b00;
                DA_in = 128'd0;
            end
        endcase
    end

    // Tag Array
    always @(*) begin
        case(cstate)
            IDLE: begin
                TA_write = 2'b11;
                TA_read = 1'b0;
                TA_in = 23'd0;
            end
            READ_HIT: begin
                TA_write = 2'b11;
                TA_read = 1'b1;
                TA_in = 23'd0;
            end
            READ_AXI: begin
                if(sram_counter == 2'd3 && axi_ready) begin
                    if(!valid_reg[{1'b0, core_addr_reg[8:4]}]) begin
                        TA_write = 2'b10;
                    end
                    else if(!valid_reg[{1'b1, core_addr_reg[8:4]}]) begin
                        TA_write = 2'b01;
                    end
                    else if(lru_buffer[core_addr_reg[8:4]] == 1'b0) begin // write into set 1
                        TA_write = 2'b01;
                    end
                    else begin
                        TA_write = 2'b10;
                    end
                end
                else begin
                    TA_write = 2'b11;
                end
                TA_read = 1'b0;
                TA_in = core_addr_reg[31:9];
            end
            WRITE_HIT: begin
                TA_write = 2'b11;
                TA_read = 1'b1;
                TA_in = 23'd0;
            end
            WRITE_CACHE: begin
                // if(!valid_reg[{1'b0, core_addr_reg[8:4]}]) begin
                //     TA_write = 2'b10;
                // end
                // else if(!valid_reg[{1'b1, core_addr_reg[8:4]}]) begin
                //     TA_write = 2'b01;
                // end
                if(hit0) begin
                    TA_write = 2'b10;
                end
                else if(hit1) begin
                    TA_write = 2'b01;
                end
                else if(lru_buffer[core_addr_reg[8:4]] == 1'b0) begin // write into set 1
                    TA_write = 2'b01;
                end
                else begin
                    TA_write = 2'b10;
                end
                TA_read = 1'b0;
                TA_in = core_addr_reg[31:9];
            end
            DONE: begin
                TA_write = 2'b11;
                TA_read = 1'b0;
                TA_in = 23'd0;
            end
            default: begin
                TA_write = 2'b11;
                TA_read = 1'b0;
                TA_in = 23'd0;
            end
        endcase
    end

    // lru_buffer
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            for(i=0; i<32; i=i+1) begin
                lru_buffer[i] <= 1'b0;
            end
        end
        else begin
            case(cstate)
                READ_HIT: begin
                    if(hit) begin
                        lru_buffer[core_addr_reg[8:4]] <= (hit0)? 1'b0 : 1'b1;
                    end
                end
                READ_AXI: begin
                    if(TA_write == 2'b10) begin
                        lru_buffer[core_addr_reg[8:4]] <= 1'b0;
                    end
                    else if(TA_write == 2'b01) begin
                        lru_buffer[core_addr_reg[8:4]] <= 1'b1;
                    end
                end
                WRITE_HIT: begin
                    if(hit) begin
                        lru_buffer[core_addr_reg[8:4]] <= (hit0)? 1'b0 : 1'b1;
                    end
                end
            endcase
        end
    end

    // sram_counter
    always @(posedge clk or posedge rst) begin
        if(rst) begin
            sram_counter <= 2'd0;
        end
        else begin
            case(cstate)
                READ_AXI: begin
                    if(axi_ready) begin
                        sram_counter <= sram_counter + 2'd1;
                    end
                end
                DONE: begin
                    sram_counter <= 2'd0;
                end
            endcase
        end
    end

    // cpu_ready
    always @(*) begin
        case(cstate)
            IDLE: begin
                cpu_ready = 1'b0;
            end
            READ_HIT: begin
                if(hit) begin
                    cpu_ready = 1'b1;
                end
                else begin
                    cpu_ready = 1'b0;
                end
            end
            READ_AXI: begin
                if(core_addr_reg[3:2] == sram_counter) begin
                    cpu_ready = axi_ready;
                end
                else begin
                    cpu_ready = 1'b0;
                end
            end
            WRITE_HIT: begin
                // if(hit) begin
                //     if(BVALID && BREADY) begin
                //         cpu_ready = 1'b1;
                //     end
                //     else begin
                //         cpu_ready = 1'b0;
                //     end
                // end
                // else begin
                //     cpu_ready = 1'b1;
                // end
                cpu_ready = 1'b0;
            end
            WRITE_CACHE: begin
                cpu_ready = 1'b0;
            end
            DONE: begin
                cpu_ready = 1'b0;
            end
            default: begin
                cpu_ready = 1'b0;
            end
        endcase
    end

     // axi_valid
    always @(*) begin
        case(cstate)
            IDLE: begin
                axi_valid = 1'b0;
            end
            READ_HIT: begin
                if(hit) begin
                    axi_valid = 1'b0;
                end
                else begin
                    axi_valid = 1'b1;
                end
            end
            READ_AXI: begin
                axi_valid = 1'b0;
            end
            WRITE_HIT: begin
                axi_valid = 1'b0;
            end
            WRITE_CACHE: begin
                axi_valid = 1'b0;
            end
            DONE: begin
                axi_valid = 1'b0;
            end
            default: begin
                axi_valid = 1'b0;
            end
        endcase
    end

    // valid
    always @(*) begin
        case(cstate)
            IDLE: begin
                valid = valid_reg;
            end
            READ_HIT: begin
                valid = valid_reg;
            end
            READ_AXI: begin
                if(sram_counter == 2'd3 && axi_ready) begin
                    if(!valid_reg[{1'b0, core_addr_reg[8:4]}]) begin
                        valid = valid_reg | (64'b1 <<  {1'b0, core_addr_reg[8:4]});
                    end
                    else if(!valid_reg[{1'b1, core_addr_reg[8:4]}]) begin
                        valid = valid_reg | (64'b1 <<  {1'b1, core_addr_reg[8:4]});
                    end
                    else begin
                        valid = valid_reg;
                    end
                    // else if(lru_buffer[core_addr_reg[8:4]] == 1'b0) begin // write into bank 1
                    //     valid = valid_reg | (64'b1 <<  {1'b1, core_addr_reg[8:4]});
                    // end
                    // else begin
                    //     valid = valid_reg | (64'b1 <<  {1'b0, core_addr_reg[8:4]});
                    // end
                end
                else begin
                    valid = valid_reg;
                end
            end
            WRITE_HIT: begin
                valid = valid_reg;
            end
            WRITE_CACHE: begin
                // if(lru_buffer[core_addr_reg[8:4]] == 1'b0) begin // write into bank 1
                //     if(valid_reg[{1'b1, core_addr_reg[8:4]}]) begin
                //         valid = valid_reg;
                //     end
                //     else begin
                //         valid = valid_reg | (64'b1 <<  {1'b1, core_addr_reg[8:4]});
                //     end
                // end
                // else begin
                //     if(valid_reg[{1'b0, core_addr_reg[8:4]}]) begin
                //         valid = valid_reg;
                //     end
                //     else begin
                //         valid = valid_reg | (64'b1 <<  {1'b0, core_addr_reg[8:4]});
                //     end
                // end
                // if(!valid_reg[{1'b0, core_addr_reg[8:4]}]) begin
                //     valid = valid_reg | (64'b1 <<  {1'b0, core_addr_reg[8:4]});
                // end
                // else if(!valid_reg[{1'b1, core_addr_reg[8:4]}]) begin
                //     valid = valid_reg | (64'b1 <<  {1'b1, core_addr_reg[8:4]});
                // end
                // else begin
                //     valid = valid_reg;
                // end
                if(hit0) begin
                    valid = valid_reg | (64'b1 <<  {1'b0, core_addr_reg[8:4]});
                end
                else if(hit1) begin
                    valid = valid_reg | (64'b1 <<  {1'b1, core_addr_reg[8:4]});
                end
                else begin
                    valid = valid_reg;
                end
            end
            DONE: begin
                valid = valid_reg;
            end
            default: begin
                valid = valid_reg;
            end
        endcase
    end

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            valid_reg <= 64'd0;
        end
        else begin
            valid_reg <= valid;
        end
    end

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            core_addr_reg <= 32'd0;
        end
        else begin
            if(core_req) 
                core_addr_reg <= core_addr; 
        end
    end


/* =========== Assertion =========== */
`ifdef NOT_SYN_ASSERT

    int hit_count_for_read ;
    int req_count_for_read ;
    int hit_count_for_write;
    int req_count_for_write;

    always @(posedge clk or posedge rst) begin
        if(rst) begin
            hit_count_for_read  <= 32'd0;
            req_count_for_read  <= 32'd0;
            hit_count_for_write <= 32'd0;
            req_count_for_write <= 32'd0;
        end
        else begin
            if(cstate == IDLE && core_req) begin
                if(core_write) req_count_for_write <= req_count_for_write + 32'd1;
                else req_count_for_read <= req_count_for_read + 32'd1;
            end
            else if(cstate == READ_HIT && hit) begin
                hit_count_for_read <= hit_count_for_read + 32'd1;
            end
            else if(cstate == WRITE_HIT && hit) begin
                hit_count_for_write <= hit_count_for_write + 32'd1;
            end 
        end
    end

    always @(posedge clk) begin
        $display("READ : Hit count/Request count: %d/%d", hit_count_for_read , req_count_for_read );
        $display("WRITE: Hit count/Request count: %d/%d", hit_count_for_write, req_count_for_write);
    end
`endif
endmodule

