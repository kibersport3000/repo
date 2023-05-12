module ram(input clk, input[18:0] A, input[15:0] D, input[2:0] C, input dmp, input R);
    parameter reg[19:0] MEM_SIZE = 524288; /// 2 ^ 19 
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
    reg[BYTE_SIZE - 1:0] data[0:MEM_SIZE - 1];
    integer SEED = 225526;
    reg ready = 0;

    always @(R == 1) begin
        reset();
    end;

    initial begin    
        // $display("RAM initialization begins");
        for (integer i = 0; i < MEM_SIZE; i += 1) begin
            data[i] = $random(SEED)>>16;  
        end
        // $display("RAM initialization ends \n");
    end;


    task reset();
        begin
            for (integer i = 0; i < MEM_SIZE; i += 1) begin
                data[i] = $random(SEED)>>16;  
            end
        end;
    endtask

    task response();
        begin
            ready = 1;
        end;
    endtask
    
    ///Функция для записи в память кэшлинии
    task writeLine(input[0:CACHE_TAG_SIZE - 1] tag, input[0:CACHE_SET_SIZE - 1] set, input[0:CACHELINE_SIZE * 8 - 1] line);
        reg[0:CACHE_ADDR_SIZE] cur;
        reg[7:0] byte;
        begin
            ready = 0;
            cur = (((tag << CACHE_SET_SIZE) + set) << CACHE_OFFSET_SIZE);
            for (integer i = 0; i < (1 << CACHE_OFFSET_SIZE); i++) begin
                byte = 0;
                for (integer j = 0; j < 8; j++) begin
                    byte *= 2;
                    byte += line[i * 8 + j];
                end;
                data[cur + i] = byte;
            end
            ready = 1;
        end;
    endtask


    ///Фунцкия для извлечения кэшлинии из памяти
    function reg[0:CACHELINE_SIZE * 8 - 1] readLine(input[0:CACHE_TAG_SIZE - 1] tag, input[0:CACHE_SET_SIZE - 1] set);
        reg[0:CACHE_ADDR_SIZE] cur;
        begin
            ready = 0;
            readLine = 0;
            cur = (((tag << CACHE_SET_SIZE) + set) << CACHE_OFFSET_SIZE);
            for (integer i = 0; i < (1 << CACHE_OFFSET_SIZE); i++) begin
               readLine *= (1 << 8);
               readLine += data[cur + i];
            end
            ready = 1;
        end;
    endfunction
endmodule   
