--signal.lua
local get_signal    = quanta.get_signal
local set_signal    = quanta.set_signal

--信号定义
local SYS_SIGNAL = {
    SIGHUP    = 1,
    SIGINT    = 2,
    SIGQUIT   = 3,
    SIGILL    = 4,
    SIGTRAP   = 5,
    SIGABRT   = 6,
    SIGIOT    = 6,
    SIGBUS    = 7,
    SIGFPE    = 8,
    SIGKILL   = 9,
    SIGUSR1   = 10,
    SIGSEGV   = 11,
    SIGUSR2   = 12,
    SIGPIPE   = 13,
    SIGALRM   = 14,
    SIGTERM   = 15,
    SIGSTKFLT = 16,
    SIGCHLD   = 17,
    SIGCONT   = 18,
    SIGSTOP   = 19,
    SIGTSTP   = 20,
    SIGTTIN   = 21,
    SIGTTOU   = 22,
    SIGURG    = 23,
    SIGXCPU   = 24,
    SIGXFSZ   = 25,
    SIGVTALRM = 26,
    SIGPROF   = 27,
    SIGWINCH  = 28,
    SIGIO     = 29,
    SIGPOLL   = 29,
    SIGPWR    = 30,
    SIGSYS    = 31,
    SIGUNUSED = 31,
    SIGRTMIN  = 32,
}

local EXIT_SIGNAL = {
    [SYS_SIGNAL.SIGINT]  = "SIGINT",
    [SYS_SIGNAL.SIGTERM] = "SIGTERM",
    [SYS_SIGNAL.SIGQUIT] = "SIGQUIT",
    [SYS_SIGNAL.SIGKILL] = "SIGKILL",
    [SYS_SIGNAL.SIGUSR1] = "SIGUSR1",
    [SYS_SIGNAL.SIGUSR2] = "SIGUSR2",
}

signal = {}
signal.init = function()
    for sig in pairs(EXIT_SIGNAL) do
        quanta.register_signal(sig)
    end
    quanta.ignore_signal(SYS_SIGNAL.SIGPIPE)
    quanta.ignore_signal(SYS_SIGNAL.SIGCHLD)
end

signal.check = function()
    local signalv = get_signal()
    for sig, sig_name in pairs(EXIT_SIGNAL) do
        if signalv & (1 << sig) ~= 0 then
            return true
        end
    end
    return false
end

signal.quit = function()
    set_signal(SYS_SIGNAL.SIGQUIT)
end
