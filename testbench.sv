`include "cpu.sv"


module main();
    parameter integer M = 64;
    parameter integer N = 60;
    parameter integer K = 32;
    integer pa;
    integer pb;
    integer pc;
    integer s;
    reg[0:31] anow;
    integer bnow;
    reg clk = 0;
    reg[0:7] a[M:0][K:0];
    reg[0:15] b[K:0][N:0];
    reg[0:31] c[M:0][N:0];
    reg[0:31] add = 0;
    integer hits;
    reg[15:0] D;
    reg[3:0] C;
    reg[18:0] A;
    reg dmp = 0;

    cpu cpu(.clk(clk), .A(A), .D(D), .C(C), .dmp(dmp));
    ram ram(); /// simple ram only for arrays

    integer cur;
    reg[0:0] temp;
    integer s1;
    initial begin
        hits = 0;
        pa = 0;
        pb = 0;
        pc = 0;
        s = 0;
        s1 = 0;
        anow = 0;
        bnow = 0;
        cpu.ready = 0;
        $dumpfile ("dump.vcd");
        $dumpvars(anow, main);
        for (integer i = 0; i < M; i++) begin
            for (integer j = 0; j < K; j++) begin 
                a[i][j] = ram.data[i * K + j];
            end
        end

        for (integer i = 0; i < K; i++) begin
            for (integer j = 0; j < N; j++) begin 
                b[i][j] = ram.data[M * K + 2 * (i * N + j)] * (1 << 8) + ram.data[M * K + 2 * (i * N + j) + 1]; 
            end
        end

        add += 2; /// pa, pc
        add++; 
        for (integer y = 0; y < M; y++) begin
            add++;
            for (integer x = 0; x < N; x++) begin 
                pb = 0;
                s = 0;
                add += 2;
                add++;
                for (integer k = 0; k < K; k++) begin
                    A = pa * K + k;
                    C = 1;
                    D = 0;
                    cpu.go();
                    wait(cpu.ready != 0);
                    cpu.ready = 0;
                    anow = cpu.buffer8;
                    cpu.buffer8 = 0;
                    A = M * K + 2 * (pb * N + x);
                    C = 2;
                    D = 0;
                    cpu.go();
                    wait(cpu.ready != 0);
                    cpu.ready = 0;
                    bnow = cpu.buffer16;
                    cpu.buffer16 = 0;
                    s1 = a[pa][k];
                    s1 *= b[pb][x];
                    s += a[pa][k] * b[pb][x];
                    add += 5;
                    add += 3;
                    pb++;
                end

                /// data for C is to large to be transported for one time
                c[pc][x] = s;       
                add++;

                A = M * K + K * N * 2 + 4 * (pc * N + x);
                C = 7;
                D = (s >> 16);
                cpu.go();
                
                A = M * K + K * N * 2 + 4 * (pc * N + x);
                C = 7;
                D = (s % (1 << 16));
                cpu.go();
                wait(cpu.ready != 0);
                cpu.ready = 0;
            end 
            pa++;
            pc++;
            add += 3;
        end
        add++; /// exit from mmul
        $display("TICS FOR CACHE AND RAM: %0t\nTICS_FOR_INIT_AND_ARITHMETIC: %0d\nALL_TICS: %0d\nHITS: %0d\nCALLS: %0d\nHIT_PERCENT: %0f\nMISS_PERCENT: %0f", $time, add, $time + add, cpu.hits, cpu.cacheCalls, (1.0 * cpu.hits / (1.0 * cpu.cacheCalls) * 100), 100.0 - (1.0 * cpu.hits / (1.0 * cpu.cacheCalls) * 100)); 
        $finish;
    end

    always begin
        #1;
        clk = ~clk;
    end;
endmodule