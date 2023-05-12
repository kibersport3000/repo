#include <iostream>
#define F first
#define S second
#define M 64
#define N 60
#define K 32


using namespace std;

const int CACHE_WAY = 2;
const int CACHE_SETS_COUNT = 32;
const int CACHE_SET_SIZE = 5;
const int CACHE_OFFSET_SIZE = 4;
int TICS = 0; ///cache and ram tics
int CALLS = 0; ///number of cache-calls
int HITS = 0;///number of cache-hits
int timer = 1;///this timer is used to update the last use
int ADD_TICS = 0;///tics for arithmetic and iterations
int8_t a[M][K];
int16_t b[K][N];
int32_t c[M][N];

///CLASS FOR CACHE
class Cache {
    private:
        /// CLASS FOR CACHLINES
        class Cacheline {
            public:
                int tag; ///cache tag
                int used; /// the last change of the element
                int d; ///dirty
                int v; ///valid

                Cacheline() {
                    this -> tag = 0;
                    this -> d = 0;
                    this -> v = 0;
                    this -> used = 0;
                }
                Cacheline(int tag, int d, int v, int used) {
                    this -> tag = tag;
                    this -> d = d;
                    this -> v = v;
                    this -> used = used;
                }
        };

        ///CLASS FOR EACH CACHESET(CONTAINS CACHE_WAY(2) LINES)
        class Cacheset {
            public:
                Cacheline lines[CACHE_WAY];
        };
    public:
        Cacheset sets[CACHE_SETS_COUNT];
        void put(int address) {
            CALLS++; ///increasing number of all calls
            int tag = address >> (CACHE_SET_SIZE + CACHE_OFFSET_SIZE); ///calculating cache tag
            int cacheSet = ((address >> CACHE_OFFSET_SIZE) % (1 << CACHE_SET_SIZE)); ///calculating cache set
            TICS += 6; ///cache answers
            for (int i = 0; i < CACHE_WAY; i++) {
                ///check if current cache set contains out tag and is valid
                if (sets[cacheSet].lines[i].v == 1 && sets[cacheSet].lines[i].tag == tag) {
                    sets[cacheSet].lines[i].used = timer++;
                    sets[cacheSet].lines[i].d = 1;
                    HITS++;
                    return;
                }
            }
            /// We must update information in ram before writing new
            TICS += 4; ///waiting 4 tics before sending query to ram
            TICS += 100; ///ram response time
            int way = 0;
            ///Check for the oldest update
            if (sets[cacheSet].lines[1].used < sets[cacheSet].lines[0].used) {
                way = 1;
            } else {
                way = 0;
            }
            ///check for old information in ram before writing something in cache
            if (sets[cacheSet].lines[way].d) {
                TICS += 100; ///going to ram
            }
            /// updating information
            sets[cacheSet].lines[way].v = 1;
            sets[cacheSet].lines[way].tag = tag;
            sets[cacheSet].lines[way].used = timer++;
            sets[cacheSet].lines[way].d = 1;
            return;
        }

        void get(int address) {
            CALLS++;
            int tag = address >> (CACHE_SET_SIZE + CACHE_OFFSET_SIZE); ///calculating cache tag
            int cacheSet = ((address >> CACHE_OFFSET_SIZE) % (1 << CACHE_SET_SIZE)); ///calculating cache set
            TICS += 6; ///cache answers
            for (int i = 0; i < CACHE_WAY; i++) {
                ///check if current cache set contains out tag and is valid
                if (sets[cacheSet].lines[i].v && sets[cacheSet].lines[i].tag == tag) {
                    sets[cacheSet].lines[i].used = timer;
                    timer++;
                    HITS++; ///increasing number of cache hits
                    return;
                }
            }

            ///There is no our information in cache

            TICS += 4; ///waiting 4 tics before sending query to ram
            TICS += 100; ///ram response time

            ///Check for the oldest update
            int way = 0;
            if (sets[cacheSet].lines[1].used < sets[cacheSet].lines[0].used) {
                way = 1;
            }
            ///check for old information in ram before writing something in cache
            if (sets[cacheSet].lines[way].d) {
                TICS += 100; ///going to ram
            }
            /// updating information
            sets[cacheSet].lines[way].v = 1;
            sets[cacheSet].lines[way].tag = tag;
            sets[cacheSet].lines[way].used = timer++;
            sets[cacheSet].lines[way].d = 0;
            return;
        }
};


Cache cache;

void mmul() {
    int pa = 0;
    int pc = 0;
    ADD_TICS += 2; /// pa, pc

    int y;
    ADD_TICS++; /// y
    for (y = 0; y < M; y++) {
        int x;
        ADD_TICS++; /// x
        for (x = 0; x < N; x++) {
            int pb = 0;
            int32_t s = 0;
            ADD_TICS += 2; /// pb = 0, s = 0

            int k;
            ADD_TICS++; /// k
            for (k = 0; k < K; k++) {
                cache.get(pa * K + k); ///Trying to get information from cache
                cache.get(M * K + 2 * (pb * N + x)); ///Trying to get information from cache
                s += a[pa][k] * b[pb][x];
                pb++;
                ADD_TICS += 5; /// a[pa][k] * b[pb][x]
                ADD_TICS += 3; /// s += ..., pb++, k -> k + 1
            }
            cache.put(M * K + K * N * 2 + 4 * (pc * N + x)); ///putting new information in cache
            c[pc][x] = s;

            ADD_TICS++; /// x -> x + 1
        }
        pa++;
        pc++;
        ADD_TICS += 3; /// pa++, pb++, y -> y + 1

    }

    ADD_TICS++; /// mmul() -> exit
    return;
}

int32_t main(void) {
    mmul();
    printf("TICS FOR CACHE AND RAM: %d\nTICS_FOR_INIT_AND_ARITHMETIC: %d\nALL_TICS: %d\nHITS: %d\nCALLS: %d\nHIT_PERCENT: %f\nMISS_PERCENT: %f\n",
            TICS, ADD_TICS, TICS + ADD_TICS, HITS, CALLS, 100.0 * (1.0 * HITS) / (1.0 * CALLS), 100.0 * (1.0 * (CALLS - HITS) / (1.0 * CALLS)));
    return 0;
}
