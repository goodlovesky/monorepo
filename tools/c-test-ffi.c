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
#include <sys/stat.h>

/* ---- 基础 FFI (Phase 0.2) ---- */
typedef int (*proxy_init_fn)(const char *home, const char *version, int sdk);
typedef char *(*proxy_version_fn)(void);
typedef char *(*proxy_pong_fn)(const char *input);
typedef char *(*proxy_query_state_fn)(void);
typedef void (*proxy_free_string_fn)(char *ptr);
typedef int (*proxy_shutdown_fn)(void);
typedef char *(*proxy_last_error_message_fn)(int code);

/* ---- 引擎 FFI (Phase 0.3) ---- */
typedef int (*proxy_engine_start_fn)(const char *config, const char *cwd, const char *log_file);
typedef int (*proxy_engine_stop_fn)(void);
typedef int (*proxy_engine_is_running_fn)(void);
typedef char *(*proxy_engine_status_fn)(void);

void test_phase02(void *lib) {
    printf("=== Phase 0.2 — Basic FFI ===\n\n");

    proxy_version_fn proxy_version = (proxy_version_fn)dlsym(lib, "proxy_version");
    proxy_init_fn proxy_init = (proxy_init_fn)dlsym(lib, "proxy_init");
    proxy_pong_fn proxy_pong = (proxy_pong_fn)dlsym(lib, "proxy_pong");
    proxy_query_state_fn proxy_query_state = (proxy_query_state_fn)dlsym(lib, "proxy_query_state");
    proxy_free_string_fn proxy_free_string = (proxy_free_string_fn)dlsym(lib, "proxy_free_string");
    proxy_shutdown_fn proxy_shutdown = (proxy_shutdown_fn)dlsym(lib, "proxy_shutdown");
    proxy_last_error_message_fn proxy_last_error_message = (proxy_last_error_message_fn)dlsym(lib, "proxy_last_error_message");

    if (!proxy_version || !proxy_init || !proxy_pong || !proxy_query_state || !proxy_free_string || !proxy_shutdown) {
        fprintf(stderr, "Failed to load Phase 0.2 symbols: %s\n", dlerror());
        return;
    }

    char *v = proxy_version();
    printf("[0.2.1] proxy_version() = %s\n", v);
    proxy_free_string(v);

    char *p = proxy_pong("hello from C");
    printf("[0.2.2] proxy_pong(\"hello from C\") = %s\n", p);
    proxy_free_string(p);

    int rc = proxy_init("/tmp/c-test-ffi-home", "0.1.0", 35);
    printf("[0.2.3] proxy_init() = %d (%s)\n", rc, proxy_last_error_message(rc));

    char *s = proxy_query_state();
    printf("[0.2.4] proxy_query_state() = %s\n", s);
    proxy_free_string(s);

    rc = proxy_shutdown();
    printf("[0.2.5] proxy_shutdown() = %d (%s)\n", rc, proxy_last_error_message(rc));
    printf("\n");
}

void test_phase03(void *lib) {
    printf("=== Phase 0.3 — Engine FFI ===\n\n");

    proxy_engine_start_fn proxy_engine_start = (proxy_engine_start_fn)dlsym(lib, "proxy_engine_start");
    proxy_engine_stop_fn proxy_engine_stop = (proxy_engine_stop_fn)dlsym(lib, "proxy_engine_stop");
    proxy_engine_is_running_fn proxy_engine_is_running = (proxy_engine_is_running_fn)dlsym(lib, "proxy_engine_is_running");
    proxy_engine_status_fn proxy_engine_status = (proxy_engine_status_fn)dlsym(lib, "proxy_engine_status");
    proxy_free_string_fn proxy_free_string = (proxy_free_string_fn)dlsym(lib, "proxy_free_string");
    proxy_last_error_message_fn proxy_last_error_message = (proxy_last_error_message_fn)dlsym(lib, "proxy_last_error_message");

    if (!proxy_engine_start || !proxy_engine_stop || !proxy_engine_is_running || !proxy_engine_status) {
        fprintf(stderr, "Failed to load Phase 0.3 symbols: %s\n", dlerror());
        printf("  (engine symbols not available — build with --features not --no-default-features?)\n\n");
        return;
    }

    // 0. status 初始
    char *st = proxy_engine_status();
    printf("[0.3.0] initial status: %s\n", st ? st : "(null)");
    if (st) proxy_free_string(st);

    // 1. 用一个不存在的配置文件启动（应该失败）
    int rc = proxy_engine_start("/tmp/not_exist.yaml", "/tmp", NULL);
    printf("[0.3.1] proxy_engine_start(\"/tmp/not_exist.yaml\") = %d (%s)  [期望非 0]\n",
           rc, proxy_last_error_message(rc));
    if (rc == 0) {
        fprintf(stderr, "ERROR: 应当启动失败但返回了 0\n");
        return;
    }

    // 2. 写一个最小配置，尝试启动
    const char *config_path = "/tmp/c-test-ffi-config.yaml";
    FILE *f = fopen(config_path, "w");
    if (f) {
        fprintf(f,
            "port: 17890\n"
            "socks-port: 17891\n"
            "mixed-port: 17892\n"
            "allow-lan: false\n"
            "mode: rule\n"
            "log-level: info\n"
            "external-controller: 127.0.0.1:16170\n"
            "dns:\n"
            "  enable: true\n"
            "  listen: 127.0.0.1:53053\n"
            "  default-nameserver: [114.114.114.114]\n"
            "  enhanced-mode: fake-ip\n"
            "  fake-ip-range: 198.18.0.1/16\n"
            "  nameserver: [114.114.114.114]\n"
            "rules:\n"
            "  - MATCH,DIRECT\n"
        );
        fclose(f);
        printf("[0.3.2] wrote test config to %s\n", config_path);
    }

    // 创建 cwd
    mkdir("/tmp/c-test-ffi-home", 0755);

    // 启动引擎（实际启动会失败，因为没有 geoip/geosite 数据，但能验证 FFI 路径）
    rc = proxy_engine_start(config_path, "/tmp/c-test-ffi-home", NULL);
    printf("[0.3.3] proxy_engine_start(valid config) = %d (%s)\n",
           rc, proxy_last_error_message(rc));

    // 3. is_running
    int running = proxy_engine_is_running();
    printf("[0.3.4] proxy_engine_is_running() = %d  (1=跑, 0=没跑)\n", running);

    // 4. status
    st = proxy_engine_status();
    printf("[0.3.5] status: %s\n", st ? st : "(null)");
    if (st) proxy_free_string(st);

    // 5. 停止（即使没成功启动也要清理）
    rc = proxy_engine_stop();
    printf("[0.3.6] proxy_engine_stop() = %d (%s)\n", rc, proxy_last_error_message(rc));

    // 6. is_running after stop
    running = proxy_engine_is_running();
    printf("[0.3.7] proxy_engine_is_running() = %d  (期望 0)\n", running);
    printf("\n");
}

int main(void) {
    printf("=== core-bridge FFI test ===\n\n");

    void *lib = dlopen("./target/release/libcore_bridge.dylib", RTLD_NOW);
    if (!lib) {
        fprintf(stderr, "Failed to load library: %s\n", dlerror());
        return 1;
    }

    test_phase02(lib);
    test_phase03(lib);

    dlclose(lib);
    printf("=== ALL TESTS COMPLETED ===\n");
    return 0;
}
