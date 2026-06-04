#include <moonbit.h>

#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#if defined(_WIN32)
#include <windows.h>
// shellapi.h (CommandLineToArgvW) depends on the base Win32 types and macros
// from windows.h, so it must be included after it.
#include <shellapi.h>
// CommandLineToArgvW lives in shell32; MSVC needs it linked explicitly.
#pragma comment(lib, "shell32.lib")
#elif defined(__APPLE__)
#include <crt_externs.h>
#include <fcntl.h>
#include <mach-o/dyld.h>
#include <signal.h>
#include <sys/types.h>
#include <unistd.h>
#else
#include <fcntl.h>
#include <signal.h>
#include <sys/types.h>
#include <unistd.h>
#endif

static moonbit_bytes_t
mini_tmux_empty_bytes(void) {
  return moonbit_make_bytes(0, 0);
}

static moonbit_bytes_t
mini_tmux_copy_bytes(const void *data, size_t len) {
  if (!data || len > INT32_MAX) {
    return mini_tmux_empty_bytes();
  }
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)len, 0);
  if (len > 0) {
    memcpy(out, data, len);
  }
  return out;
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t
moonbit_mini_tmux_self_executable(void) {
#if defined(_WIN32)
  DWORD cap = 260;
  for (;;) {
    char *path = (char *)malloc((size_t)cap);
    if (!path) {
      return mini_tmux_empty_bytes();
    }
    DWORD n = GetModuleFileNameA(NULL, path, cap);
    if (n == 0) {
      free(path);
      return mini_tmux_empty_bytes();
    }
    if (n < cap - 1) {
      moonbit_bytes_t out = mini_tmux_copy_bytes(path, (size_t)n);
      free(path);
      return out;
    }
    free(path);
    cap *= 2;
  }
#elif defined(__APPLE__)
  uint32_t size = 0;
  if (_NSGetExecutablePath(NULL, &size) != -1 || size == 0) {
    return mini_tmux_empty_bytes();
  }
  char *path = (char *)malloc((size_t)size);
  if (!path) {
    return mini_tmux_empty_bytes();
  }
  if (_NSGetExecutablePath(path, &size) != 0) {
    free(path);
    return mini_tmux_empty_bytes();
  }
  moonbit_bytes_t out = mini_tmux_copy_bytes(path, strlen(path));
  free(path);
  return out;
#elif defined(__linux__)
  size_t cap = 256;
  for (;;) {
    char *path = (char *)malloc(cap);
    if (!path) {
      return mini_tmux_empty_bytes();
    }
    ssize_t n = readlink("/proc/self/exe", path, cap);
    if (n < 0) {
      free(path);
      return mini_tmux_empty_bytes();
    }
    if ((size_t)n < cap) {
      moonbit_bytes_t out = mini_tmux_copy_bytes(path, (size_t)n);
      free(path);
      return out;
    }
    free(path);
    cap *= 2;
  }
#else
  return mini_tmux_empty_bytes();
#endif
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t
moonbit_mini_tmux_self_args_flat(void) {
#if defined(_WIN32)
  int argc = 0;
  LPWSTR *argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (!argv || argc <= 0) {
    if (argv) {
      LocalFree(argv);
    }
    return mini_tmux_empty_bytes();
  }
  size_t total = 0;
  for (int i = 0; i < argc; i++) {
    int len = WideCharToMultiByte(
      CP_UTF8, 0, argv[i], -1, NULL, 0, NULL, NULL);
    if (len <= 0) {
      LocalFree(argv);
      return mini_tmux_empty_bytes();
    }
    total += (size_t)len;
  }
  if (total > INT32_MAX) {
    LocalFree(argv);
    return mini_tmux_empty_bytes();
  }
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)total, 0);
  size_t pos = 0;
  for (int i = 0; i < argc; i++) {
    int len = WideCharToMultiByte(
      CP_UTF8, 0, argv[i], -1, (char *)out + pos, (int)(total - pos), NULL, NULL);
    if (len <= 0) {
      LocalFree(argv);
      return mini_tmux_empty_bytes();
    }
    pos += (size_t)len;
  }
  LocalFree(argv);
  return out;
#elif defined(__APPLE__)
  int argc = *_NSGetArgc();
  char **argv = *_NSGetArgv();
  if (argc <= 0 || !argv) {
    return mini_tmux_empty_bytes();
  }
  size_t total = 0;
  for (int i = 0; i < argc; i++) {
    if (!argv[i]) {
      return mini_tmux_empty_bytes();
    }
    total += strlen(argv[i]) + 1;
  }
  if (total > INT32_MAX) {
    return mini_tmux_empty_bytes();
  }
  moonbit_bytes_t out = moonbit_make_bytes((int32_t)total, 0);
  size_t pos = 0;
  for (int i = 0; i < argc; i++) {
    size_t len = strlen(argv[i]);
    memcpy(out + pos, argv[i], len);
    pos += len + 1;
  }
  return out;
#elif defined(__linux__)
  int fd = open("/proc/self/cmdline", O_RDONLY);
  if (fd < 0) {
    return mini_tmux_empty_bytes();
  }
  size_t cap = 256;
  size_t len = 0;
  char *buf = (char *)malloc(cap);
  if (!buf) {
    close(fd);
    return mini_tmux_empty_bytes();
  }
  for (;;) {
    if (len == cap) {
      size_t new_cap = cap * 2;
      char *new_buf = (char *)realloc(buf, new_cap);
      if (!new_buf) {
        free(buf);
        close(fd);
        return mini_tmux_empty_bytes();
      }
      buf = new_buf;
      cap = new_cap;
    }
    ssize_t n = read(fd, buf + len, cap - len);
    if (n == 0) {
      break;
    }
    if (n < 0) {
      free(buf);
      close(fd);
      return mini_tmux_empty_bytes();
    }
    len += (size_t)n;
    if (len > INT32_MAX) {
      free(buf);
      close(fd);
      return mini_tmux_empty_bytes();
    }
  }
  close(fd);
  moonbit_bytes_t out = mini_tmux_copy_bytes(buf, len);
  free(buf);
  return out;
#else
  return mini_tmux_empty_bytes();
#endif
}

struct mini_tmux_argv {
  char *buf;
  char **argv;
};

static void
mini_tmux_free_argv(struct mini_tmux_argv argv) {
  free(argv.argv);
  free(argv.buf);
}

static struct mini_tmux_argv
mini_tmux_argv_from_flat(moonbit_bytes_t flat) {
  struct mini_tmux_argv result = {0};
  if (!flat) {
    return result;
  }
  size_t len = (size_t)Moonbit_array_length(flat);
  if (len == 0 || flat[len - 1] != '\0') {
    return result;
  }
  int argc = 0;
  for (size_t i = 0; i < len; i++) {
    if (flat[i] == '\0') {
      argc++;
    }
  }
  if (argc == 0) {
    return result;
  }
  result.buf = (char *)malloc(len);
  result.argv = (char **)calloc((size_t)argc + 1, sizeof(char *));
  if (!result.buf || !result.argv) {
    mini_tmux_free_argv(result);
    result.buf = NULL;
    result.argv = NULL;
    return result;
  }
  memcpy(result.buf, flat, len);
  char *start = result.buf;
  int index = 0;
  for (size_t i = 0; i < len; i++) {
    if (result.buf[i] == '\0') {
      result.argv[index++] = start;
      start = result.buf + i + 1;
    }
  }
  result.argv[index] = NULL;
  return result;
}

static char *
mini_tmux_bytes_to_cstring(moonbit_bytes_t bytes) {
  if (!bytes) {
    return NULL;
  }
  size_t len = (size_t)Moonbit_array_length(bytes);
  char *out = (char *)malloc(len + 1);
  if (!out) {
    return NULL;
  }
  memcpy(out, bytes, len);
  out[len] = '\0';
  return out;
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_mini_tmux_spawn_detached(
  moonbit_bytes_t argv_flat,
  moonbit_bytes_t env_key_bytes,
  moonbit_bytes_t env_value_bytes,
  moonbit_bytes_t log_path_bytes
) {
#if defined(_WIN32)
  (void)argv_flat;
  (void)env_key_bytes;
  (void)env_value_bytes;
  (void)log_path_bytes;
  return -1;
#else
  struct mini_tmux_argv argv = mini_tmux_argv_from_flat(argv_flat);
  char *env_key = mini_tmux_bytes_to_cstring(env_key_bytes);
  char *env_value = mini_tmux_bytes_to_cstring(env_value_bytes);
  char *log_path = mini_tmux_bytes_to_cstring(log_path_bytes);
  if (!argv.argv || !argv.argv[0] || !env_key || !env_value || !log_path) {
    mini_tmux_free_argv(argv);
    free(env_key);
    free(env_value);
    free(log_path);
    return -1;
  }

  pid_t pid = fork();
  if (pid < 0) {
    mini_tmux_free_argv(argv);
    free(env_key);
    free(env_value);
    free(log_path);
    return -1;
  }
  if (pid > 0) {
    mini_tmux_free_argv(argv);
    free(env_key);
    free(env_value);
    free(log_path);
    return (int32_t)pid;
  }

  if (setsid() < 0) {
    _exit(127);
  }
  signal(SIGHUP, SIG_IGN);

  int devnull = open("/dev/null", O_RDONLY);
  if (devnull >= 0) {
    dup2(devnull, STDIN_FILENO);
    if (devnull > STDERR_FILENO) {
      close(devnull);
    }
  }

  int log_fd = open(log_path, O_WRONLY | O_CREAT | O_APPEND, 0600);
  if (log_fd >= 0) {
    dup2(log_fd, STDOUT_FILENO);
    dup2(log_fd, STDERR_FILENO);
    if (log_fd > STDERR_FILENO) {
      close(log_fd);
    }
  }

  setenv(env_key, env_value, 1);
  execvp(argv.argv[0], argv.argv);
  _exit(127);
#endif
}

MOONBIT_FFI_EXPORT
int32_t
moonbit_mini_tmux_process_id(void) {
#if defined(_WIN32)
  return (int32_t)GetCurrentProcessId();
#else
  return (int32_t)getpid();
#endif
}

MOONBIT_FFI_EXPORT
moonbit_bytes_t
moonbit_mini_tmux_platform(void) {
#if defined(_WIN32)
  return mini_tmux_copy_bytes("windows", 7);
#elif defined(__APPLE__)
  return mini_tmux_copy_bytes("macos", 5);
#else
  return mini_tmux_copy_bytes("unix", 4);
#endif
}
