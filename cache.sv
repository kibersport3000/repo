module cache(input clk, input[18:0] A, input[15:0] D, input[3:0] C, input dmp, input R);
    parameter reg[3:0] BYTE_SIZE = 8;
    parameter reg[1:0] CACHE_WAY = 2;
    parameter reg[10:0] CACHE_SIZE = 1024;
    parameter reg[6:0] CACHELINE_COUNT = 64;
    parameter reg[4:0] CACHELINE_SIZE = 16;
    parameter reg[5:0] CACHE_SETS_COUNT = 32;
    parameter reg[3:0] CACHE_TAG_SIZE = 10;
    parameter reg[4:0] CACHE_ADDR_SIZE = 19;
    parameter reg[2:0] CACHE_OFFSET_SIZE = 4;
    parameter reg[2:0] CACHE_SET_SIZE = 5;
    reg[CACHE_TAG_SIZE - 1:0] tags[0:CACHE_WAY - 1][0:CACHE_SETS_COUNT - 1];
    reg[0:0] valid[0:CACHE_WAY - 1][0:CACHE_SETS_COUNT - 1]; 
    reg[0:0] dirty[0:CACHE_WAY - 1][0:CACHE_SETS_COUNT - 1];
    reg[7:0] cache[0:CACHE_WAY - 1][0:CACHE_SETS_COUNT - 1][0:CACHELINE_SIZE - 1];
    integer changed[0:CACHE_WAY - 1][0:CACHE_SETS_COUNT - 1];
    integer totalCount;
    reg ready = 0;

    always @(R == 1) begin
        reset();
    end;

    initial begin
        // $display("Cache initialization begins");
        totalCount = 1;
        for (reg[1:0] i = 0; i < CACHE_WAY; i += 1) begin
            for (reg[6:0] j = 0; j < CACHE_SETS_COUNT; j += 1) begin
                valid[i][j] = 0;
                dirty[i][j] = 0;
                tags[i][j] = 0;
                changed[i][j] = 0;
                for (reg [4:0] k = 0; k < CACHELINE_SIZE; k += 1) begin
                    cache[i][j][k] = 0;
                end;
            end;
        end;
        // $display("Cache initialization ends");
    end;

    task response();
        begin
            ready = 1;
        end;
    endtask
    
    task reset();
        begin
            ready = 0;
            for (reg[1:0] i = 0; i < CACHE_WAY; i += 1) begin
                for (reg[6:0] j = 0; j < CACHE_SETS_COUNT; j += 1) begin
                    valid[i][j] = 0;
                    dirty[i][j] = 0;
                    tags[i][j] = 0;
                    changed[i][j] = 0;
                    for (reg [4:0] k = 0; k < CACHELINE_SIZE; k += 1) begin
                        cache[i][j][k] = 0;
                    end;
                end;
            end;
            ready = 1;
        end;
    endtask


    task invalidateLine(input[0:CACHE_SET_SIZE-1] set);
        begin
            ready = 0;
            for (integer i = 0; i < CACHE_WAY; i++) begin 
                valid[i][set] = 0;
            end
            ready = 1;
        end
    endtask

    function reg[0:0] firstChanged(input[0:CACHE_SET_SIZE - 1] set);
        begin
            ready = 0;
            firstChanged = 0;
            if (changed[1][set] < changed[0][set]) begin
                firstChanged = 1;
            end;
            ready = 1;
        end;
    endfunction

    function reg[0:0] isInCache(input[CACHE_ADDR_SIZE - 1:0] address);
        reg[CACHE_TAG_SIZE - 1:0] tag;
        reg[CACHE_SET_SIZE - 1:0] set;
        reg[CACHE_OFFSET_SIZE - 1:0] offset;
        begin 
            ready = 0;
            tag = (address >> (CACHE_ADDR_SIZE - CACHE_TAG_SIZE));
            set = ((address % ((1 << CACHE_SET_SIZE) * (1 << CACHE_OFFSET_SIZE))) >> CACHE_OFFSET_SIZE);
            offset = (address % (1 << CACHE_OFFSET_SIZE));
            isInCache = 0;
            for (integer i = 0; i < CACHE_WAY; i++) begin
                if (tag == tags[i][set] && valid[i][set]) begin
                    isInCache = 1;
                end;
            end;
            ready = 1;
        end
    endfunction


    ///прочитать 8 бит из кэша
    function reg[0:7] get8Bits(input[18:0] address);
        reg[CACHE_TAG_SIZE - 1:0] tag;
        reg[CACHE_SET_SIZE - 1:0] set;
        reg[CACHE_OFFSET_SIZE - 1:0] offset;
        begin 
            ready = 0;
            tag = (address >> (CACHE_ADDR_SIZE - CACHE_TAG_SIZE));
            set = ((address % ((1 << CACHE_SET_SIZE) * (1 << CACHE_OFFSET_SIZE))) >> CACHE_OFFSET_SIZE);
            offset = (address % (1 << CACHE_OFFSET_SIZE));
            for (integer i = 0; i < CACHE_WAY; i++) begin
                if (tag == tags[i][set] && valid[i][set]) begin
                    get8Bits = cache[i][set][offset];
                    changed[i][set] = totalCount++;
                end;
            end;
            ready = 1;
        end
    endfunction

    ///прочитать 16 бит из кэша
    function reg[0:15] get16Bits(input[18:0] address);
        reg[CACHE_TAG_SIZE - 1:0] tag;
        reg[CACHE_SET_SIZE - 1:0] set;
        reg[CACHE_OFFSET_SIZE - 1:0] offset;
        begin 
            ready = 0;
            get16Bits = 0;
            tag = (address >> (CACHE_ADDR_SIZE - CACHE_TAG_SIZE));
            set = ((address % ((1 << CACHE_SET_SIZE) * (1 << CACHE_OFFSET_SIZE))) >> CACHE_OFFSET_SIZE);
            offset = (address % (1 << CACHE_OFFSET_SIZE));
            for (integer i = 0; i < CACHE_WAY; i++) begin
                if (tag == tags[i][set] && valid[i][set]) begin
                    for (integer j = offset; j <= offset + 1; j++) begin
                        get16Bits = (get16Bits * (1 << BYTE_SIZE));
                        get16Bits += cache[i][set][j];
                        changed[i][set] = totalCount++;
                    end;
                end;
            end;
            ready = 1;
        end
    endfunction

    ///прочитать 32 бит из кэша
    function reg[0:31] get32Bits(input[18:0] address);
        reg[CACHE_TAG_SIZE - 1:0] tag;
        reg[CACHE_SET_SIZE - 1:0] set;
        reg[CACHE_OFFSET_SIZE - 1:0] offset;
        begin 
            ready = 0;
            get32Bits = 0;
            tag = (address >> (CACHE_ADDR_SIZE - CACHE_TAG_SIZE));
            set = ((address % ((1 << CACHE_SET_SIZE) * (1 << CACHE_OFFSET_SIZE))) >> CACHE_OFFSET_SIZE);
            offset = (address % (1 << CACHE_OFFSET_SIZE));
            for (integer i = 0; i < CACHE_WAY; i++) begin
                if (tag == tags[i][set] && valid[i][set]) begin
                    for (integer j = offset; j <= offset + 3; j++) begin
                        get32Bits = (get32Bits * (1 << BYTE_SIZE));
                        get32Bits += cache[i][set][j];
                        changed[i][set] = totalCount++;
                    end;
                end;
            end;
            ready = 1;
        end
    endfunction

    ///записать 8 бит в кэш
    task put8Bits(input[18:0] address, input[7:0] data);
        reg[CACHE_TAG_SIZE - 1:0] tag;
        reg[CACHE_SET_SIZE - 1:0] set;
        reg[CACHE_OFFSET_SIZE - 1:0] offset;
        begin 
            ready = 0;
            tag = (address >> (CACHE_ADDR_SIZE - CACHE_TAG_SIZE));
            set = ((address % ((1 << CACHE_SET_SIZE) * (1 << CACHE_OFFSET_SIZE))) >> CACHE_OFFSET_SIZE);
            offset = (address % (1 << CACHE_OFFSET_SIZE));
            for (integer i = 0; i < CACHE_WAY; i++) begin
                if (tag == tags[i][set] && valid[i][set]) begin
                    cache[i][set][offset] = data;
                    changed[i][set] = totalCount++;
                end;
            end;
            ready = 1;
        end    
    endtask

    ///записать 16 бит в кэш
    task put16Bits(input[18:0] address, input[15:0] data);
        reg[CACHE_TAG_SIZE - 1:0] tag;
        reg[CACHE_SET_SIZE - 1:0] set;
        reg[CACHE_OFFSET_SIZE - 1:0] offset;
        begin 
            ready = 0;
            tag = (address >> (CACHE_ADDR_SIZE - CACHE_TAG_SIZE));
            set = ((address % ((1 << CACHE_SET_SIZE) * (1 << CACHE_OFFSET_SIZE))) >> CACHE_OFFSET_SIZE);
            offset = (address % (1 << CACHE_OFFSET_SIZE));
            for (integer i = 0; i < CACHE_WAY; i++) begin
                if (tag == tags[i][set] && valid[i][set]) begin
                    cache[i][set][offset] = (data >> 8);
                    cache[i][set][offset + 1] = (data % (1 << 8));
                    changed[i][set] = totalCount++;
                end;
            end;
            ready = 1;
        end    
    endtask

    ///записать 32 бита в кэш
    task put32Bits(input[18:0] address, input [32:0] data);
        reg[CACHE_TAG_SIZE - 1:0] tag;
        reg[CACHE_SET_SIZE - 1:0] set;
        reg[CACHE_OFFSET_SIZE - 1:0] offset;
        begin 
            ready = 0;
            tag = (address >> (CACHE_ADDR_SIZE - CACHE_TAG_SIZE));
            set = ((address % ((1 << CACHE_SET_SIZE) * (1 << CACHE_OFFSET_SIZE))) >> CACHE_OFFSET_SIZE);
            offset = (address % (1 << CACHE_OFFSET_SIZE));
            for (integer i = 0; i < CACHE_WAY; i++) begin
                if (tag == tags[i][set] && valid[i][set]) begin
                    cache[i][set][offset] = (data >> 24);
                    cache[i][set][offset + 1] = (data >> 16) % (1 << 8);
                    cache[i][set][offset + 2] = (data >> 8) % (1 << 8);
                    cache[i][set][offset + 3] = (data % (1 << 8));
                    changed[i][set] = totalCount++;
                end;
            end;
            ready = 1;
        end    
    endtask

endmodule