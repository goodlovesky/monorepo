/*
 * c-test-ffi.c — 手动验证 core-bridge 的 FFI 导出
 *
 * 用法:
 *   1. cargo build --release -p core-bridge
 *   2. clang tools/c-test-ffi.c -L target/release -lcore_bridge -o /tmp/c-test-ffi
 *   3. /tmp/c-test-ffi
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>

typedef int (*proxy_init_fn)(const char *home, const char *version, int sdk);
typedef char *(*proxy_version_fn)(void);
typedef char *(*proxy_pong_fn)(const char *input);
typedef char *(*proxy_query_state_fn)(void);
typedef void (*proxy_free_string_fn)(char *ptr);
typedef int (*proxy_shutdown_fn)(void);
typedef char *(*proxy_last_error_message_fn)(int code);

int main(void) {
    printf("=== core-bridge FFI test ===\n\n");

    void *lib = dlopen("./target/release/libcore_bridge.dylib", RTLD_NOW);
    if (!lib) {
        fprintf(stderr, "Failed to load library: %s\n", dlerror());
        return 1;
    }

    proxy_version_fn proxy_version = (proxy_version_fn)dlsym(lib, "proxy_version");
    proxy_init_fn proxy_init = (proxy_init_fn)dlsym(lib, "proxy_init");
    proxy_pong_fn proxy_pong = (proxy_pong_fn)dlsym(lib, "proxy_pong");
    proxy_query_state_fn proxy_query_state = (proxy_query_state_fn)dlsym(lib, "proxy_query_state");
    proxy_free_string_fn proxy_free_string = (proxy_free_string_fn)dlsym(lib, "proxy_free_string");
    proxy_shutdown_fn proxy_shutdown = (proxy_shutdown_fn)dlsym(lib, "proxy_shutdown");
    proxy_last_error_message_fn proxy_last_error_message = (proxy_last_error_message_fn)dlsym(lib, "proxy_last_error_message");

    if (!proxy_version || !proxy_init || !proxy_pong || !proxy_query_state || !proxy_free_string || !proxy_shutdown) {
        fprintf(stderr, "Failed to load symbols: %s\n", dlerror());
        dlclose(lib);
        return 1;
    }

    // 1. version
    char *v = proxy_version();
    printf("proxy_version() = %s\n", v);
    proxy_free_string(v);

    // 2. pong
    char *p = proxy_pong("hello from C");
    printf("proxy_pong(\"hello from C\") = %s\n", p);
    proxy_free_string(p);

    // 3. init
    int rc = proxy_init("/tmp/c-test-ffi-home", "0.1.0", 35);
    printf("proxy_init() = %d (%s)\n", rc, proxy_last_error_message(rc));
    if (rc != 0) {
        dlclose(lib);
        return 1;
    }

    // 4. query state
    char *s = proxy_query_state();
    printf("proxy_query_state() = %s\n", s);
    proxy_free_string(s);

    // 5. shutdown
    rc = proxy_shutdown();
    printf("proxy_shutdown() = %d (%s)\n", rc, proxy_last_error_message(rc));

    dlclose(lib);
    printf("\n=== ALL TESTS PASSED ===\n");
    return 0;
}
