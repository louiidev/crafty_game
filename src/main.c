#include <emscripten/emscripten.h>
#include <emscripten/html5.h>

#include <stdio.h>
#include <string.h>
#include <time.h>

// #include "spall.h"

extern void _main();

int main()
{
    _main();
    return 0;
}

extern uint64_t get_random_seed()
{
    uint32_t high, low;

    // Use Web Crypto API to get two 32-bit random values
    EM_ASM({
        var array = new Uint32Array(2);
        self.crypto.getRandomValues(array);
        setValue($0, array[0], 'i32'); // High 32 bits
        setValue($1, array[1], 'i32'); // Low 32 bits
    },
           &high, &low);

    // Combine high and low parts into a 64-bit value
    return ((uint64_t)high << 32) | (uint64_t)low;
}

// note: this isn't gonna be high res on web.
// use emscripten_get_now() for relative high res timing.
extern uint64_t unix_time_nanoseconds()
{
    struct timespec ts;
    // For real "wall clock" time, use CLOCK_REALTIME
    clock_gettime(CLOCK_REALTIME, &ts);
    return (uint64_t)ts.tv_sec * 1000000000ULL + (uint64_t)ts.tv_nsec;
}

// asyncify-friendly "blocking" syncfs
EM_JS(void, pull_syncfs_blocking, (), {
    Asyncify.handleAsync(async() = > {
        console.log("Starting FS.syncfs in JS...");

        // Wrap FS.syncfs in a Promise
        await new Promise((resolve, reject) = > {
            FS.syncfs(true, function(err) {
		if (err) {
		  console.error("error syncing FS:", err);
		  reject(err);
		  return;
		}
		console.log("FS sync finished successfully!");
		resolve(); });
        });

        // Once we reach here, the Wasm stack will resume
    });
});

// asyncify-friendly "blocking" syncfs
EM_JS(void, push_syncfs_blocking, (), {
    Asyncify.handleAsync(async() = > {
        console.log("Starting FS.syncfs in JS...");

        // Wrap FS.syncfs in a Promise
        await new Promise((resolve, reject) = > {
            FS.syncfs(false, function(err) {
		if (err) {
		  console.error("error syncing FS:", err);
		  reject(err);
		  return;
		}
		console.log("FS sync finished successfully!");
		resolve(); });
        });

        // Once we reach here, the Wasm stack will resume
    });
});

void mount_idbfs()
{
    EM_ASM({
        console.log("mounting idbfs");
        if (typeof FS == = 'undefined' || typeof IDBFS == = 'undefined')
        {
            console.error("FS or IDBFS is not available. Ensure they are linked properly.");
            return;
        }
        FS.mkdir('/persist');
        FS.mount(IDBFS, {}, '/persist');
    });
    pull_syncfs_blocking();
}

int sync_fs(void)
{

    puts("sync start");

    push_syncfs_blocking();

    puts("sync end");

    return 0;
}

typedef struct
{
    char *endpoint;
    char *body;
} fetch_context_t;

void free_context(fetch_context_t *ctx)
{
    free(ctx->endpoint);
    free(ctx->body);
    free(ctx);
}
