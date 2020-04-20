--signal.lua
local log_info      = logger.info

--信号定义
local sys_signal = {
    SIGHUP = 1,
    SIGINT = 2,
    SIGQUIT = 3,
    SIGILL = 4,
    SIGTRAP = 5,
    SIGABRT = 6,
    SIGIOT = 6,
    SIGBUS = 7,
    SIGFPE = 8,
    SIGKILL = 9,
    SIGUSR1 = 10,
    SIGSEGV = 11,
    SIGUSR2 = 12,
    SIGPIPE = 13,
    SIGALRM = 14,
    SIGTERM = 15,
    SIGSTKFLT = 16,
    SIGCHLD = 17,
    SIGCONT = 18,
    SIGSTOP = 19,
    SIGTSTP = 20,
    SIGTTIN = 21,
    SIGTTOU = 22,
    SIGURG = 23,
    SIGXCPU = 24,
    SIGXFSZ = 25,
    SIGVTALRM = 26,
    SIGPROF = 27,
    SIGWINCH = 28,
    SIGIO = 29,
    SIGPOLL = 29,
    SIGPWR = 30,
    SIGSYS = 31,
    SIGUNUSED = 31,
    SIGRTMIN = 32,
}

signal = {}
signal.init = function()
    quanta.register_signal(sys_signal.SIGINT)
    quanta.register_signal(sys_signal.SIGTERM)
    quanta.ignore_signal(sys_signal.SIGPIPE)
    --quanta.ignore_signal(sys_signal.SIGCHLD)
end

signal.check = function()
    local quanta_signal = quanta.signal
    if quanta_signal & (1 << sys_signal.SIGINT) ~= 0 then
        log_info("signal.check ->SIGINT")
        return true
    end
    if quanta_signal & (1 << sys_signal.SIGQUIT) ~= 0 then
        log_info("signal.check ->SIGQUIT")
        return true
    end
    if quanta_signal & (1 << sys_signal.SIGTERM) ~= 0 then
        log_info("signal.check ->SIGTERM")
        return true
    end
    return false
end

signal.quit = function()
    quanta.signal = (1 << sys_signal.SIGQUIT)
end
