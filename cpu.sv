`include "cache.sv"
`include "ram.sv"


module cpu(input clk, input[18:0] A, input[15:0] D, input[3:0] C, input dmp);
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
    integer CacheHitCount;
    integer cacheCalls;
    reg reset;
    integer hits;
    reg[2:0] C2;
    cache cache(.clk(clk), .A(A), .D(D), .C(C), .dmp(dmp), .R(reset));
    ram ram(.clk(clk), .A(A), .D(D), .C(C2), .dmp(dmp), .R(reset));
    integer ready;

    initial begin
        cacheCalls = 0;
        hits = 0;
        ready = 0;
    end;

    task response();
        begin
            ready = 1;
        end;
    endtask


    ///прочитать 8 бит
    task read8(input[18:0] address);
        reg[CACHE_TAG_SIZE - 1:0] tag;
        reg[CACHE_SET_SIZE - 1:0] set;
        reg[CACHE_OFFSET_SIZE - 1:0] offset;
        reg[CACHELINE_SIZE * 8 - 1:0] line;
        reg[CACHE_TAG_SIZE - 1:0] cache_tag;
        reg[CACHE_SET_SIZE - 1:0] cache_set;
        reg[CACHELINE_SIZE * 8 - 1:0] cacheline;
        reg[0:0] w;
        reg[0:0] temp;
        begin
            ready = 0;
            cacheCalls++;
            tag = (address >> (CACHE_ADDR_SIZE - CACHE_TAG_SIZE));
            set = ((address % ((1 << CACHE_SET_SIZE) * (1 << CACHE_OFFSET_SIZE))) >> CACHE_OFFSET_SIZE);
            offset = (address % (1 << CACHE_OFFSET_SIZE));
            if (cache.isInCache(address)) begin
                hits++;
                buffer8 = cache.get8Bits(address);
            end else begin
                ram.ready = 0;
                line = ram.readLine(tag, set);
                wait(ram.ready != 0);
                buffer8 = 0;
                for (integer i = offset * 8; i <= offset * 8 + 7; i++) begin
                    buffer8 *= 2;
                    buffer8 += line[i];
                end;
                w = cache.firstChanged(set);
                cache.changed[w][set] = cache.totalCount++;
                if (cache.dirty[w][set] == 1 && cache.valid[w][set] == 1) begin
                    cacheline = 0;
                    cache_tag = cache.tags[w][set];
                    cache_set = set;
                    for (integer i = 0; i < (1 << CACHE_OFFSET_SIZE); i++) begin
                        cacheline *= (1 << 8);
                        cacheline += cache.cache[w][set][i];
                    end;
                    #100;
                    ram.ready = 0;
                    ram.writeLine(cache_tag, cache_set, cacheline);
                    wait(ram.ready != 0);
                end;
                for (integer i = 0; i < (1 << CACHE_OFFSET_SIZE); i++) begin
                    cache.cache[w][set][i] = 0;
                    for (integer j = 0; j < 8; j++) begin
                        cache.cache[w][set][i] *= 2;
                        cache.cache[w][set][i] += line[i * 8 + j];
                    end
                end
                cache.dirty[w][set] = 0;
                cache.valid[w][set] = 1;
                cache.tags[w][set] = tag;
            end;
            ready = 1;
        end;
    endtask

    ///прочитать 16 бит
    task read16(input[18:0] address);
        reg[CACHE_TAG_SIZE - 1:0] tag;
        reg[CACHE_SET_SIZE - 1:0] set;
        reg[CACHE_OFFSET_SIZE - 1:0] offset;
        reg[CACHELINE_SIZE * 8 - 1:0] line;
        reg[CACHE_TAG_SIZE - 1:0] cache_tag;
        reg[CACHE_SET_SIZE - 1:0] cache_set;
        reg[CACHELINE_SIZE * 8 - 1:0] cacheline;
        reg[0:0] w;
        reg[0:0] temp;
        begin
            ready = 0;
            cacheCalls++;
            tag = (address >> (CACHE_ADDR_SIZE - CACHE_TAG_SIZE));
            set = ((address % ((1 << CACHE_SET_SIZE) * (1 << CACHE_OFFSET_SIZE))) >> CACHE_OFFSET_SIZE);
            offset = (address % (1 << CACHE_OFFSET_SIZE));
            if (cache.isInCache(address)) begin
                hits++;
                buffer16 = cache.get16Bits(address);
            end else begin
                ram.ready = 0;
                line = ram.readLine(tag, set);
                wait(ram.ready != 0);
                buffer16 = 0;

                w = cache.firstChanged(set);
                cache.changed[w][set] = cache.totalCount++;
                if (cache.dirty[w][set] == 1 && cache.valid[w][set] == 1) begin
                    cacheline = 0;
                    cache_tag = cache.tags[w][set];
                    cache_set = set;
                    for (integer i = 0; i < (1 << CACHE_OFFSET_SIZE); i++) begin
                        cacheline *= (1 << 8);
                        cacheline += cache.cache[w][set][i];
                    end;
                    #100;
                    ram.ready = 0;
                    ram.writeLine(cache_tag, cache_set, cacheline);
                    wait(ram.ready != 0);
                end;
                for (integer i = 0; i < (1 << CACHE_OFFSET_SIZE); i++) begin
                    cache.cache[w][set][i] = 0;
                    for (integer j = 0; j < 8; j++) begin
                        cache.cache[w][set][i] *= 2;
                        cache.cache[w][set][i] += line[i * 8 + j];
                    end
                end
                buffer16 = (cache.cache[w][set][offset] * (1 << 8) + cache.cache[w][set][offset + 1]); 
                cache.dirty[w][set] = 0;
                cache.valid[w][set] = 1;
                cache.tags[w][set] = tag;
            end;
            ready = 1;
        end;
    endtask

    ///прочитать 32 бита
    task read32(input[18:0] address);
        reg[CACHE_TAG_SIZE - 1:0] tag;
        reg[CACHE_SET_SIZE - 1:0] set;
        reg[CACHE_OFFSET_SIZE - 1:0] offset;
        reg[CACHELINE_SIZE * 8 - 1:0] line;
        reg[CACHE_TAG_SIZE - 1:0] cache_tag;
        reg[CACHE_SET_SIZE - 1:0] cache_set;
        reg[CACHELINE_SIZE * 8 - 1:0] cacheline;
        reg[0:0] w;
        reg[0:0] temp;
        begin
            ready = 0;
            cacheCalls++;
            tag = (address >> (CACHE_ADDR_SIZE - CACHE_TAG_SIZE));
            set = ((address % ((1 << CACHE_SET_SIZE) * (1 << CACHE_OFFSET_SIZE))) >> CACHE_OFFSET_SIZE);
            offset = (address % (1 << CACHE_OFFSET_SIZE));
            if (cache.isInCache(address)) begin
                hits++;
                buffer32 = cache.get32Bits(address);
            end else begin
                ram.ready = 0;
                line = ram.readLine(tag, set);
                wait(ram.ready != 0);
                buffer32 = 0;
                w = cache.firstChanged(set);
                cache.changed[w][set] = cache.totalCount++;
                if (cache.dirty[w][set] == 1 && cache.valid[w][set]) begin
                    cacheline = 0;
                    cache_tag = cache.tags[w][set];
                    cache_set = set;
                    for (integer i = 0; i < (1 << CACHE_OFFSET_SIZE); i++) begin
                        cacheline *= (1 << 8);
                        cacheline += cache.cache[w][set][i];
                    end;
                    #100;
                    ram.ready = 0;
                    ram.writeLine(cache_tag, cache_set, cacheline);
                    wait(ram.ready != 0);
                end;
                for (integer i = 0; i < (1 << CACHE_OFFSET_SIZE); i++) begin
                    cache.cache[w][set][i] = 0;
                    for (integer j = 0; j < 8; j++) begin
                        cache.cache[w][set][i] *= 2;
                        cache.cache[w][set][i] += line[i * 8 + j];
                    end
                end
                buffer32 = cache.cache[w][set][offset] * (1 << 24);
                buffer32 += (cache.cache[w][set][offset + 1] * (1 << 16));
                buffer32 += (cache.cache[w][set][offset + 2] * (1 << 8));
                buffer32 += cache.cache[w][set][offset + 3];
                cache.dirty[w][set] = 0;
                cache.valid[w][set] = 1;
                cache.tags[w][set] = tag;
            end;
            ready = 1;
        end;
    endtask

    ///записать 8 бит
    task write8(input[18:0] address, input[7:0] data);
        reg[CACHE_TAG_SIZE - 1:0] tag;
        reg[CACHE_SET_SIZE - 1:0] set;
        reg[CACHE_OFFSET_SIZE - 1:0] offset;
        reg[CACHELINE_SIZE * 8 - 1:0] line;
        reg[CACHE_TAG_SIZE - 1:0] cache_tag;
        reg[CACHE_SET_SIZE - 1:0] cache_set;
        reg[CACHELINE_SIZE * 8 - 1:0] cacheline;
        reg[0:0] w;
        reg[0:0] temp;
        begin
            ready = 0;
            cacheCalls++;
            tag = (address >> (CACHE_ADDR_SIZE - CACHE_TAG_SIZE));
            set = ((address % ((1 << CACHE_SET_SIZE) * (1 << CACHE_OFFSET_SIZE))) >> CACHE_OFFSET_SIZE);
            offset = (address % (1 << CACHE_OFFSET_SIZE));
            if (cache.isInCache(address) == 1) begin
                hits++;
                cache.put8Bits(address, data);
            end else begin
                cacheline = 0;
                cache_tag = cache.tags[w][set];
                cache_set = set;
                for (integer i = 0; i < (1 << CACHE_OFFSET_SIZE); i++) begin
                    cacheline *= (1 << 8);
                    cacheline += cache.cache[w][set][i];
                end;
                line = 0;
                ram.ready = 0;
                line = ram.readLine(tag, set);
                wait(ram.ready != 0);
                w = cache.firstChanged(set);
                cache.changed[w][set] = cache.totalCount++;
                if (cache.dirty[w][cache_set] == 1 && cache.valid[w][cache_set] == 1) begin 
                    #100;
                    ram.ready = 0;
                    ram.writeLine(cache_tag, cache_set, cacheline);
                    wait(ram.ready != 0);
                end
                for (integer i = 0; i < (1 << CACHE_OFFSET_SIZE); i++) begin
                    cache.cache[w][set][i] = 0;
                    for (integer j = 0; j < 8; j++) begin
                        cache.cache[w][set][i] *= 2;
                        cache.cache[w][set][i] += line[i * 8 + j];
                    end;
                end;
                cache.cache[w][set][offset] = data;
                cache.dirty[w][set] = 1;
                cache.valid[w][set] = 1;
                cache.tags[w][set] = tag;
            end;
        end;
    endtask
    
    ///записать 16 бит
    task write16(input[18:0] address, input[15:0] data);
        reg[CACHE_TAG_SIZE - 1:0] tag;
        reg[CACHE_SET_SIZE - 1:0] set;
        reg[CACHE_OFFSET_SIZE - 1:0] offset;
        reg[CACHELINE_SIZE * 8 - 1:0] line;
        reg[CACHE_TAG_SIZE - 1:0] cache_tag;
        reg[CACHE_SET_SIZE - 1:0] cache_set;
        reg[CACHELINE_SIZE * 8 - 1:0] cacheline;
        reg[0:0] w;
        reg[0:0] temp;
        begin
            ready = 0;
            cacheCalls++;
            tag = (address >> (CACHE_ADDR_SIZE - CACHE_TAG_SIZE));
            set = ((address % ((1 << CACHE_SET_SIZE) * (1 << CACHE_OFFSET_SIZE))) >> CACHE_OFFSET_SIZE);
            offset = (address % (1 << CACHE_OFFSET_SIZE));
            if (cache.isInCache(address) == 1) begin
                hits++;
                cache.put16Bits(address, data);
            end else begin
                cacheline = 0;
                cache_tag = cache.tags[w][set];
                cache_set = set;
                for (integer i = 0; i < (1 << CACHE_OFFSET_SIZE); i++) begin
                    cacheline *= (1 << 8);
                    cacheline += cache.cache[w][set][i];
                end;
                line = 0;
                ram.ready = 0;
                line = ram.readLine(tag, set);
                wait(ram.ready != 0);
                w = cache.firstChanged(set);
                cache.changed[w][set] = cache.totalCount++;
                if (cache.dirty[w][cache_set] == 1 && cache.valid[w][cache_set] == 1) begin 
                    #100;
                    ram.ready = 0;
                    ram.writeLine(cache_tag, cache_set, cacheline);
                    wait(ram.ready != 0);
                end
                for (integer i = 0; i < (1 << CACHE_OFFSET_SIZE); i++) begin
                    cache.cache[w][set][i] = 0;
                    for (integer j = 0; j < 8; j++) begin
                        cache.cache[w][set][i] *= 2;
                        cache.cache[w][set][i] += line[i * 8 + j];
                    end;
                end;
                cache.cache[w][set][offset] = (data >> 8);
                cache.cache[w][set][offset + 1] = (data % (1 << 8));
                cache.dirty[w][set] = 1;
                cache.valid[w][set] = 1;
                cache.tags[w][set] = tag;
            end;
            ready = 1;
        end;
    endtask
    
    ///записать 32 бита
    task write32(input[18:0] address, input[31:0] data);
        reg[CACHE_TAG_SIZE - 1:0] tag;
        reg[CACHE_SET_SIZE - 1:0] set;
        reg[CACHE_OFFSET_SIZE - 1:0] offset;
        reg[CACHELINE_SIZE * 8 - 1:0] line;
        reg[CACHE_TAG_SIZE - 1:0] cache_tag;
        reg[CACHE_SET_SIZE - 1:0] cache_set;
        reg[CACHELINE_SIZE * 8 - 1:0] cacheline;
        reg[0:0] w;
        reg[0:0] temp;
        begin
            ready = 0;
            cacheCalls++;
            tag = (address >> (CACHE_ADDR_SIZE - CACHE_TAG_SIZE));
            set = ((address % ((1 << CACHE_SET_SIZE) * (1 << CACHE_OFFSET_SIZE))) >> CACHE_OFFSET_SIZE);
            offset = (address % (1 << CACHE_OFFSET_SIZE));
            if (cache.isInCache(address) == 1) begin
                hits++;
                cache.put32Bits(address, data);
            end else begin
                cacheline = 0;
                cache_tag = cache.tags[w][set];
                cache_set = set;
                for (integer i = 0; i < (1 << CACHE_OFFSET_SIZE); i++) begin
                    cacheline *= (1 << 8);
                    cacheline += cache.cache[w][set][i];
                end;
                line = 0;
                ram.ready = 0;
                line = ram.readLine(tag, set);
                wait(ram.ready != 0);
                w = cache.firstChanged(set);
                cache.changed[w][set] = cache.totalCount++;
                if (cache.dirty[w][cache_set] == 1 && cache.valid[w][cache_set] == 1) begin 
                    #100;
                    ram.ready = 0;
                    ram.writeLine(cache_tag, cache_set, cacheline);
                    wait(ram.ready != 0);
                end
                for (integer i = 0; i < (1 << CACHE_OFFSET_SIZE); i++) begin
                    cache.cache[w][set][i] = 0;
                    for (integer j = 0; j < 8; j++) begin
                        cache.cache[w][set][i] *= 2;
                        cache.cache[w][set][i] += line[i * 8 + j];
                    end;
                end;
                cache.cache[w][set][offset] = (data >> 24);
                cache.cache[w][set][offset + 1] = (data >> 16) % (1 << 8);
                cache.cache[w][set][offset + 2] = (data >> 8) % (1 << 8);
                cache.cache[w][set][offset + 3] = data % (1 << 8);
                cache.dirty[w][set] = 1;
                cache.valid[w][set] = 1;
                cache.tags[w][set] = tag;
            end;
            ready = 1;
        end;
    endtask

    reg[18:0] fulladdress;
    reg[2:0] fullcommand;
    reg[31:0] fulldata;
    integer counter;
    reg[31:0] buffer32;
    reg[15:0] buffer16;
    reg[7:0] buffer8;
    reg[0:0] tmp;
    reg[CACHE_SET_SIZE - 1:0] cacheset;

    initial begin
        counter = 0;
    end;

    task go();
        begin
            fulladdress = A;
            fullcommand = C;
            fulldata = D; 
            counter++;
            if (fullcommand == 0) begin 
                ///NOP
                counter = 0;
                fullcommand = 0;
                fulldata = 0;
                #6; ///запрос к кэшу
            end else if (fullcommand == 1) begin
                ///READ8
                if (counter == 1) begin
                    #6;///запрос к кэшу
                    if (!cache.isInCache(fulladdress)) begin
                        #104; ///запрос к памяти
                    end;
                    read8(fulladdress);
                    counter = 0;
                end;
            end else if (fullcommand == 2) begin
                ///READ16
                if (counter == 1) begin
                    #6; ///запрос к кэшу
                    if (!cache.isInCache(fulladdress)) begin
                        #104;///запрос к памяти
                    end;
                    read16(fulladdress);
                    counter = 0;
                end;
            end else if (fullcommand == 3) begin
                ///READ32
                if (counter == 2) begin
                    #6; /// запрос к кэшу
                    if (!cache.isInCache(fulladdress)) begin
                        #104; /// запрос к памяти
                    end;
                    read32(fulladdress);
                    counter = 0;
                end;
            end else if (fullcommand == 4) begin
                ///WRITE8
                cacheset = ((fulladdress >> CACHE_OFFSET_SIZE) % (1 << CACHE_SET_SIZE));
                #6; /// запрос к кэшу
                cache.invalidateLine(cacheset);
                counter = 0;
            end else if (fullcommand == 5) begin
                if (counter == 1) begin
                    #6; /// запрос к кэшу
                    if (!cache.isInCache(fulladdress)) begin
                        #104; /// запрос к памяти
                    end;
                    write8(fulladdress, (fulldata >> 8));
                    counter = 0;
                end;
            end else if (fullcommand == 6) begin
                ///WRITE16
                if (counter == 1) begin
                    #6; ///запрос к кэшу
                    if (!cache.isInCache(fulladdress)) begin
                        #104; ///запрос к памяти
                    end;
                    write16(fulladdress, fulldata);
                    counter = 0;
                end;
            end else if (fullcommand == 7) begin
                ///WRITE32
                if (counter == 2) begin
                    #6; ///запрос к кэшу
                    if (!cache.isInCache(fulladdress)) begin
                        #104; ///запрос к памяти
                    end;
                    write32(fulladdress, fulldata);
                    counter = 0;
                end;
            end else if (fullcommand == 8) begin
                ///RESPONSE
                #6; ///запрос к кэшу
                response();
                counter = 0;
            end
        end
    endtask
endmodule