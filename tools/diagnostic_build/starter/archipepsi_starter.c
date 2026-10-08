/*
 * Archipepsi diagnostic build: the one program a player (or the
 * Archipepsi Launcher) starts.
 *
 * It does what "Start Archipepsi (Windows).bat" plus a hand-started Godot
 * do in a checkout, with the bundled runtime instead of an installed one:
 *
 *   1. refuse to start when something already listens on the bridge port
 *      (a bridge left running from a checkout would otherwise answer the
 *      game, with ITS saves, and nothing on screen would say so);
 *   2. start the bundled bridge -- runtime\python\python.exe -m
 *      archipepsi_bridge --ap=mock --epsilon=fallback --mock-scale=prototype
 *      --save-dir <per-user folder> -- exactly the arguments of the
 *      checkout's Start bat plus the save folder;
 *   3. wait until the bridge accepts connections;
 *   4. start the game, passing every argument this program was given
 *      straight through to it;
 *   5. when the game exits, stop the bridge.
 *
 * The bridge and the game are placed in one job object that closes with
 * this process, so neither can outlive it as an orphan.
 *
 * Saves never go in the installation folder:
 *   %LOCALAPPDATA%\Archipepsi\Diagnostic Campaign\saves   the campaign
 *   %LOCALAPPDATA%\Archipepsi\Diagnostic Campaign\logs    bridge + starter logs
 * ARCHIPEPSI_DIAGNOSTIC_HOME overrides that folder (the build's tests use it
 * so they never touch a real save).
 *
 * Built twice from this one file (tools/diagnostic_build/build.sh):
 *   Archipepsi-Diagnostic.exe          GUI subsystem. Bridge output goes to
 *                                      a log file; problems are message boxes.
 *   Archipepsi-Diagnostic.console.exe  console subsystem (-DSTARTER_CONSOLE).
 *                                      Bridge and game print into this window,
 *                                      and the game is game\Archipepsi.console.exe.
 *
 * Plain Win32 and the C runtime only: no dependency to ship or license
 * beyond the MinGW-w64 runtime noted in THIRD_PARTY_NOTICES.txt.
 */
#define WIN32_LEAN_AND_MEAN
#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
#include <shlobj.h>
#include <stdio.h>
#include <stdarg.h>
#include <wchar.h>

#ifndef BRIDGE_PORT
#error "BRIDGE_PORT must be defined by the build (schemas/constants.py)"
#endif
#ifndef BUILD_REVISION
#define BUILD_REVISION L"unknown"
#endif

#define TITLE L"Archipepsi diagnostic build"
#define BRIDGE_START_TIMEOUT_MS 120000
#define PATH_CAP 4096
#define CMD_CAP 32768

static wchar_t g_home[PATH_CAP];
static wchar_t g_logs[PATH_CAP];
static FILE *g_log;

static void note(const wchar_t *fmt, ...)
{
    va_list ap;
    SYSTEMTIME t;
    GetLocalTime(&t);
#ifdef STARTER_CONSOLE
    va_start(ap, fmt);
    fwprintf(stdout, L"  ");
    vfwprintf(stdout, fmt, ap);
    fwprintf(stdout, L"\n");
    fflush(stdout);
    va_end(ap);
#endif
    if (!g_log)
        return;
    fwprintf(g_log, L"%04d-%02d-%02d %02d:%02d:%02d  ", t.wYear, t.wMonth,
             t.wDay, t.wHour, t.wMinute, t.wSecond);
    va_start(ap, fmt);
    vfwprintf(g_log, fmt, ap);
    va_end(ap);
    fwprintf(g_log, L"\n");
    fflush(g_log);
}

/* A problem the player has to read. A message box in the windowed build,
 * the console (and a pause, so the window does not vanish) in the other. */
static void tell(const wchar_t *fmt, ...)
{
    wchar_t msg[8192];
    va_list ap;
    va_start(ap, fmt);
    _vsnwprintf(msg, 8191, fmt, ap);
    msg[8191] = 0;
    va_end(ap);
    note(L"PROBLEM: %ls", msg);
#ifdef STARTER_CONSOLE
    fwprintf(stdout, L"\n%ls\n\n  Press Enter to close this window.", msg);
    fflush(stdout);
    getwchar();
#else
    MessageBoxW(NULL, msg, TITLE, MB_OK | MB_ICONWARNING);
#endif
}

static int make_dirs(const wchar_t *path)
{
    /* SHCreateDirectoryExW makes every missing level; ERROR_ALREADY_EXISTS
     * is success. */
    int rc = SHCreateDirectoryExW(NULL, path, NULL);
    return rc == ERROR_SUCCESS || rc == ERROR_ALREADY_EXISTS
        || rc == ERROR_FILE_EXISTS;
}

static int resolve_home(void)
{
    DWORD n = GetEnvironmentVariableW(L"ARCHIPEPSI_DIAGNOSTIC_HOME", g_home,
                                      PATH_CAP);
    if (n == 0 || n >= PATH_CAP) {
        wchar_t base[PATH_CAP];
        PWSTR known = NULL;
        n = GetEnvironmentVariableW(L"LOCALAPPDATA", base, PATH_CAP);
        if (n == 0 || n >= PATH_CAP) {
            if (SHGetKnownFolderPath(&FOLDERID_LocalAppData, 0, NULL, &known)
                != S_OK)
                return 0;
            lstrcpynW(base, known, PATH_CAP);
            CoTaskMemFree(known);
        }
        _snwprintf(g_home, PATH_CAP, L"%ls\\Archipepsi\\Diagnostic Campaign",
                   base);
    }
    _snwprintf(g_logs, PATH_CAP, L"%ls\\logs", g_home);
    return make_dirs(g_logs);
}

/* Does something accept connections on 127.0.0.1:BRIDGE_PORT right now? */
static int port_answers(void)
{
    SOCKET s;
    struct sockaddr_in a;
    int ok;
    s = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (s == INVALID_SOCKET)
        return 0;
    ZeroMemory(&a, sizeof a);
    a.sin_family = AF_INET;
    a.sin_port = htons(BRIDGE_PORT);
    a.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    ok = connect(s, (struct sockaddr *)&a, sizeof a) == 0;
    closesocket(s);
    return ok;
}

/* Everything after this program's own name on its command line, verbatim,
 * so quoting survives exactly as the caller wrote it. */
static const wchar_t *passthrough_args(void)
{
    const wchar_t *p = GetCommandLineW();
    if (*p == L'"') {
        p++;
        while (*p && *p != L'"')
            p++;
        if (*p)
            p++;
    } else {
        while (*p && *p != L' ' && *p != L'\t')
            p++;
    }
    while (*p == L' ' || *p == L'\t')
        p++;
    return p;
}

static void log_tail(const wchar_t *path, wchar_t *out, size_t cap)
{
    FILE *f = _wfopen(path, L"rb");
    char buf[1500];
    long size;
    size_t got;
    out[0] = 0;
    if (!f)
        return;
    fseek(f, 0, SEEK_END);
    size = ftell(f);
    fseek(f, size > (long)sizeof buf - 1 ? size - (long)sizeof buf + 1 : 0,
          SEEK_SET);
    got = fread(buf, 1, sizeof buf - 1, f);
    buf[got] = 0;
    fclose(f);
    MultiByteToWideChar(CP_UTF8, 0, buf, -1, out, (int)cap);
    out[cap - 1] = 0;
}

/* THE GAME IN TWO PARTS, joined on first run.
 *
 * A 50 MB zip does not fit every channel the build travels (the chat's
 * upload limit is why the review builds ship as `-part1of2` and
 * `-part2of2`), so the split package carries
 * game\Archipepsi.exe.part1 and .part2 instead of the executable, with
 * its byte count in game\Archipepsi.exe.size.
 *
 * Joining here rather than in a `.bat` keeps the one entry point: the
 * Archipepsi Launcher verifies the parts against SHA256SUMS.txt and then
 * starts this program, exactly as for a whole package.
 *
 * Returns 1 when the game is now in place (joined, or already whole), 0
 * when it could not be, having said why.
 */
static int join_game(const wchar_t *dir, const wchar_t *game)
{
    wchar_t whole[PATH_CAP], part[PATH_CAP], sizefile[PATH_CAP];
    wchar_t buf[64];
    FILE *out, *in, *f;
    static char copy[1 << 20];
    size_t got;
    long long want = -1, written = 0;
    int n;

    /* ALWAYS Archipepsi.exe, never `game`. The console twin is a 184 kB
     * wrapper that launches Archipepsi.exe, so the console build needs
     * the joined file just as much -- and keying this on `game` meant the
     * console starter found its own wrapper, skipped the join, and
     * started a wrapper with nothing behind it. `test.sh` step 10 caught
     * exactly that. */
    (void)game;
    _snwprintf(whole, PATH_CAP, L"%ls\\game\\Archipepsi.exe", dir);
    if (GetFileAttributesW(whole) != INVALID_FILE_ATTRIBUTES)
        return 1;
    _snwprintf(part, PATH_CAP, L"%ls.part1", whole);
    if (GetFileAttributesW(part) == INVALID_FILE_ATTRIBUTES)
        return 1;                       /* not a split package: say nothing */

    _snwprintf(sizefile, PATH_CAP, L"%ls.size", whole);
    if ((f = _wfopen(sizefile, L"r")) != NULL) {
        if (fgetws(buf, 64, f))
            want = _wtoi64(buf);
        fclose(f);
    }
    if (want <= 0) {
        tell(L"This build is incomplete: it says the game arrives in parts "
             L"but does not say how big the whole file should be. Install "
             L"the build again.");
        return 0;
    }

    note(L"joining the game's parts (expecting %lld bytes)", want);
    if ((out = _wfopen(whole, L"wb")) == NULL) {
        tell(L"Could not write the game into\n%ls\\game\n\nIf the folder is "
             L"read-only, copy the build somewhere you can write to and "
             L"start it again.", dir);
        return 0;
    }
    for (n = 1;; n++) {
        _snwprintf(part, PATH_CAP, L"%ls.part%d", whole, n);
        if ((in = _wfopen(part, L"rb")) == NULL)
            break;
        while ((got = fread(copy, 1, sizeof copy, in)) > 0) {
            if (fwrite(copy, 1, got, out) != got) {
                fclose(in);
                fclose(out);
                DeleteFileW(whole);
                tell(L"Ran out of room while joining the game's parts. Free "
                     L"some disk space and start it again.");
                return 0;
            }
            written += (long long)got;
        }
        fclose(in);
    }
    fclose(out);
    if (written != want) {
        DeleteFileW(whole);
        tell(L"The joined game is %lld bytes, not the %lld it should be, so "
             L"a part is damaged or from a different build.\n\nDownload "
             L"BOTH parts again, from the same message, and install again.",
             written, want);
        return 0;
    }
    note(L"joined %lld bytes; removing the parts", written);
    for (n = 1;; n++) {
        _snwprintf(part, PATH_CAP, L"%ls.part%d", whole, n);
        if (!DeleteFileW(part))
            break;
    }
    return GetFileAttributesW(whole) != INVALID_FILE_ATTRIBUTES;
}

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE prev, PWSTR cmd, int show)
{
    wchar_t dir[PATH_CAP], saves[PATH_CAP], python[PATH_CAP];
    wchar_t bridge_cwd[PATH_CAP], game[PATH_CAP], bridge_log[PATH_CAP];
    wchar_t starter_log[PATH_CAP], tail[2048];
    static wchar_t cmdline[CMD_CAP];
    wchar_t *slash;
    WSADATA wsa;
    HANDLE job, log_handle = INVALID_HANDLE_VALUE;
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION lim;
    STARTUPINFOW si;
    PROCESS_INFORMATION bridge, play;
    SECURITY_ATTRIBUTES sa;
    SYSTEMTIME t;
    DWORD waited = 0, code = 0, game_code = 0;
    (void)inst; (void)prev; (void)cmd; (void)show;

    GetModuleFileNameW(NULL, dir, PATH_CAP);
    slash = wcsrchr(dir, L'\\');
    if (slash)
        *slash = 0;

    if (!resolve_home()) {
        tell(L"Could not create the save folder under %%LOCALAPPDATA%%.\n"
             L"Nothing was started.");
        return 2;
    }
    _snwprintf(saves, PATH_CAP, L"%ls\\saves", g_home);
    _snwprintf(starter_log, PATH_CAP, L"%ls\\starter.log", g_logs);
    g_log = _wfopen(starter_log, L"a, ccs=UTF-8");
    GetLocalTime(&t);
    _snwprintf(bridge_log, PATH_CAP,
               L"%ls\\bridge-%04d%02d%02d-%02d%02d%02d.log", g_logs, t.wYear,
               t.wMonth, t.wDay, t.wHour, t.wMinute, t.wSecond);

    note(L"Archipepsi diagnostic build, revision %ls", BUILD_REVISION);
    note(L"installed in %ls", dir);
    note(L"saves        %ls", saves);
    note(L"logs         %ls", g_logs);

    _snwprintf(python, PATH_CAP, L"%ls\\runtime\\python\\python.exe", dir);
    _snwprintf(bridge_cwd, PATH_CAP, L"%ls\\runtime\\bridge", dir);
#ifdef STARTER_CONSOLE
    _snwprintf(game, PATH_CAP, L"%ls\\game\\Archipepsi.console.exe", dir);
#else
    _snwprintf(game, PATH_CAP, L"%ls\\game\\Archipepsi.exe", dir);
#endif
    if (!join_game(dir, game))
        return 2;                       /* join_game has already said why */
    if (GetFileAttributesW(python) == INVALID_FILE_ATTRIBUTES
        || GetFileAttributesW(game) == INVALID_FILE_ATTRIBUTES) {
        tell(L"This build is incomplete: the game or its bundled Python is "
             L"missing from\n%ls\n\nInstall the build again. Nothing was "
             L"started.", dir);
        return 2;
    }

    WSAStartup(MAKEWORD(2, 2), &wsa);
    if (port_answers()) {
        tell(L"Something is already using the bridge port (%d).\n\n"
             L"This is almost always an Archipepsi bridge left running, from "
             L"this build or from a checkout's \"Start Archipepsi\" window. "
             L"The game would talk to THAT bridge and its saves, so this "
             L"build did not start.\n\nClose the other bridge (or the other "
             L"Archipepsi) and try again.", BRIDGE_PORT);
        return 3;
    }

    job = CreateJobObjectW(NULL, NULL);
    ZeroMemory(&lim, sizeof lim);
    lim.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    SetInformationJobObject(job, JobObjectExtendedLimitInformation, &lim,
                            sizeof lim);

    /* -B AND -X utf8 ON THE COMMAND LINE, not in the environment.
     *
     * The embeddable distribution has a python312._pth, which puts the
     * interpreter in isolated mode: it IGNORES every PYTHON* environment
     * variable. Setting PYTHONDONTWRITEBYTECODE here is what the first
     * version did, and the bundled interpreter duly wrote 121 __pycache__
     * files into the installation folder on its first run -- so the folder
     * no longer matched SHA256SUMS.txt, and an installation on a
     * read-only path would have been a different failure again. `-B` is
     * read before any of that and does work.
     *
     * -X utf8 for the same reason: the bridge logs Zone names with
     * arrows and other non-ASCII in them, and the console it inherits
     * need not be a UTF-8 code page.
     *
     * Everything else the bridge would take from the environment is given
     * on the command line, deliberately: the scale, the provider, the AP
     * mode and the save folder. */
    _snwprintf(cmdline, CMD_CAP,
               L"\"%ls\" -B -X utf8 -m archipepsi_bridge --ap=mock "
               L"--epsilon=fallback --mock-scale=prototype "
               L"--save-dir \"%ls\"", python, saves);
    note(L"bridge: %ls", cmdline);

    ZeroMemory(&si, sizeof si);
    si.cb = sizeof si;
#ifndef STARTER_CONSOLE
    ZeroMemory(&sa, sizeof sa);
    sa.nLength = sizeof sa;
    sa.bInheritHandle = TRUE;
    log_handle = CreateFileW(bridge_log, GENERIC_WRITE,
                             FILE_SHARE_READ | FILE_SHARE_WRITE, &sa,
                             CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (log_handle != INVALID_HANDLE_VALUE) {
        si.dwFlags = STARTF_USESTDHANDLES;
        si.hStdInput = NULL;
        si.hStdOutput = log_handle;
        si.hStdError = log_handle;
    }
    note(L"bridge log: %ls", bridge_log);
#else
    (void)sa;
#endif
    if (!CreateProcessW(NULL, cmdline, NULL, NULL, TRUE,
#ifdef STARTER_CONSOLE
                        CREATE_SUSPENDED,
#else
                        CREATE_SUSPENDED | CREATE_NO_WINDOW,
#endif
                        NULL, bridge_cwd, &si, &bridge)) {
        tell(L"Windows would not start the bundled bridge (error %lu).\n"
             L"If an antivirus quarantined runtime\\python\\python.exe, "
             L"restore it or install the build again.", GetLastError());
        return 4;
    }
    AssignProcessToJobObject(job, bridge.hProcess);
    ResumeThread(bridge.hThread);
    CloseHandle(bridge.hThread);
    if (log_handle != INVALID_HANDLE_VALUE)
        CloseHandle(log_handle);

    note(L"waiting for the bridge on 127.0.0.1:%d", BRIDGE_PORT);
    for (;;) {
        if (WaitForSingleObject(bridge.hProcess, 250) == WAIT_OBJECT_0) {
            GetExitCodeProcess(bridge.hProcess, &code);
            log_tail(bridge_log, tail, 2048);
            tell(L"The bridge stopped before the game could start (exit code "
                 L"%lu).\n\nIts log is\n%ls\n\nLast lines:\n%ls", code,
                 bridge_log, tail);
            return 5;
        }
        waited += 250;
        if (port_answers())
            break;
        if (waited >= BRIDGE_START_TIMEOUT_MS) {
            TerminateProcess(bridge.hProcess, 1);
            tell(L"The bridge did not start listening within %d seconds, so "
                 L"it was stopped and the game was not started.\n\nIts log "
                 L"is\n%ls", BRIDGE_START_TIMEOUT_MS / 1000, bridge_log);
            return 6;
        }
    }
    note(L"bridge ready after %lu ms", waited);

    _snwprintf(cmdline, CMD_CAP, L"\"%ls\" %ls", game, passthrough_args());
    note(L"game: %ls", cmdline);
    ZeroMemory(&si, sizeof si);
    si.cb = sizeof si;
    if (!CreateProcessW(NULL, cmdline, NULL, NULL, FALSE, CREATE_SUSPENDED,
                        NULL, dir, &si, &play)) {
        TerminateProcess(bridge.hProcess, 1);
        tell(L"Windows would not start the game (error %lu). If an antivirus "
             L"quarantined game\\Archipepsi.exe, restore it or install the "
             L"build again.", GetLastError());
        return 7;
    }
    AssignProcessToJobObject(job, play.hProcess);
    ResumeThread(play.hThread);
    CloseHandle(play.hThread);

    WaitForSingleObject(play.hProcess, INFINITE);
    GetExitCodeProcess(play.hProcess, &game_code);
    note(L"game exited with code %lu", game_code);

    /* Saves are written temp + fsync + replace (bridge store.py), so
     * stopping the bridge between writes cannot leave a half-written
     * campaign. */
    if (WaitForSingleObject(bridge.hProcess, 0) == WAIT_OBJECT_0) {
        GetExitCodeProcess(bridge.hProcess, &code);
        note(L"bridge had already exited with code %lu", code);
    } else {
        TerminateProcess(bridge.hProcess, 0);
        WaitForSingleObject(bridge.hProcess, 10000);
        note(L"bridge stopped");
    }
    if (g_log)
        fclose(g_log);
    return (int)game_code;
}

#ifdef STARTER_CONSOLE
int wmain(void)
{
    return wWinMain(GetModuleHandleW(NULL), NULL, NULL, SW_SHOWNORMAL);
}
#endif
