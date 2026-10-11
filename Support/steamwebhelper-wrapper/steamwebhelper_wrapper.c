// WinHub's stand-in for Steam's steamwebhelper.exe (see SteamWebHelperWrapper.swift).
//
// Wine 11's macOS driver does not show what one process draws into another
// process's window. Chromium draws Steam's windows from its GPU process, so they
// stay black. This program starts the original helper, renamed to
// steamwebhelper_real.exe, with the same arguments plus --in-process-gpu for the
// main (browser) process. WINHUB_CEF_FLAGS replaces the added switches, e.g. for
// testing "--single-process".
//
// Build: x86_64-w64-mingw32-gcc -municode -mwindows -O2 -s -o steamwebhelper.exe steamwebhelper_wrapper.c
#include <windows.h>
#include <wchar.h>

// Lets WinHub tell any build of this wrapper apart from Steam's helper.
__attribute__((used)) static const char marker[] = "WINHUB-STEAMWEBHELPER-WRAPPER";

#define DEFAULT_FLAGS L"--in-process-gpu"

// Returns the command line without the program name.
static const wchar_t *skip_program(const wchar_t *cmd) {
    if (*cmd == L'"') {
        cmd++;
        while (*cmd && *cmd != L'"') cmd++;
        if (*cmd) cmd++;
    } else {
        while (*cmd && *cmd != L' ' && *cmd != L'\t') cmd++;
    }
    while (*cmd == L' ' || *cmd == L'\t') cmd++;
    return cmd;
}

int WINAPI wWinMain(HINSTANCE instance, HINSTANCE previous, PWSTR command_line, int show) {
    (void)instance, (void)previous, (void)command_line, (void)show;
    wchar_t real[MAX_PATH];
    DWORD length = GetModuleFileNameW(NULL, real, MAX_PATH);
    if (length == 0 || length >= MAX_PATH) return 1;
    wchar_t *slash = wcsrchr(real, L'\\');
    if (!slash || (size_t)(slash - real) + 1 + wcslen(L"steamwebhelper_real.exe") >= MAX_PATH) return 1;
    wcscpy(slash + 1, L"steamwebhelper_real.exe");

    const wchar_t *arguments = skip_program(GetCommandLineW());
    // Chromium's child processes get --type=…; only the browser process needs the switches.
    wchar_t flags[1024] = L"";
    if (!wcsstr(arguments, L"--type=")) {
        DWORD n = GetEnvironmentVariableW(L"WINHUB_CEF_FLAGS", flags, 1024);
        if (n == 0 || n >= 1024) wcscpy(flags, DEFAULT_FLAGS);
    }

    size_t size = wcslen(real) + wcslen(flags) + wcslen(arguments) + 8;
    wchar_t *command = HeapAlloc(GetProcessHeap(), 0, size * sizeof(wchar_t));
    if (!command) return 1;
    swprintf(command, size, L"\"%ls\" %ls %ls", real, flags, arguments);

    STARTUPINFOW startup = { .cb = sizeof(startup) };
    PROCESS_INFORMATION process;
    if (!CreateProcessW(real, command, NULL, NULL, FALSE, 0, NULL, NULL, &startup, &process)) return 1;
    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD code = 1;
    GetExitCodeProcess(process.hProcess, &code);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return (int)code;
}
