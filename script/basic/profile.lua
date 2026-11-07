--profile.lua
local log_debug = logger.debug

local QPROFILE  = quanta.getenv("QUANTA_PROFILE")

local PROFDUMP  = "{:<25} {:^9} {:^9} {:^9} {:^12} {:^8} {:^10} {:^12} [{}]{}:{}]"

--是否启动监控
if QPROFILE then
    require("lprofile")
    --开启hook
    profile.hook()
end

--开始监控
function quanta.profile()
    if QPROFILE then
        profile.enable()
    end
end

--监控指定文件函数
--监控文件： 只传source文件，默认监控所有函数
--监控函数： 需要传2个参数，监控表target的source函数
function quanta.perfwatch(source, target)
    if QPROFILE then
        profile.watch(source, target)
    end
end

--监控过滤指定文件函数
function quanta.perfignore(source)
    if QPROFILE then
        profile.ignore_file(source)
    end
end

--输出火焰图：filename 为输出 SVG 路径，C++ 层直接写文件
--include_suspend 省略/nil 时为 true：格宽按墙钟（含挂起等待），历史行为
--传 false：按 CPU 口径，等待时间从整条调用链上剔除（挂起帧宽度归 0）
function quanta.flamedump(filename, include_suspend)
    if QPROFILE then
        local ok = profile.flame(filename, include_suspend)
        log_debug("[TimerMgr][flamedump] {} -> {}", filename, ok and "ok" or "failed")
        return ok
    end
    return false
end

--输出监控
function quanta.perfdump(top)
    if QPROFILE then
        profile.disable()
        log_debug("--------------------------------------------------------------------------------------------------------------------------------")
        log_debug("{:<25} {:^9} {:^9} {:^9} {:^12} {:^8} {:^10} {:^12} {:<10}", "name", "avg", "min", "max", "all", "per(%)", "suspend", "count", "source")
        log_debug("--------------------------------------------------------------------------------------------------------------------------------")
        for _, ev in pairs(profile.dump(top)) do
            log_debug(PROFDUMP, ev.name, ev.avg, ev.min, ev.max, ev.all, ev.per, ev.suspend, ev.count, ev.flag,  ev.src, ev.line)
        end
        log_debug("--------------------------------------------------------------------------------------------------------------------------------")
    end
end
