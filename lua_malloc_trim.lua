-- 目的：启动一个单独定时器，每隔一段时间自动调用glibc库对应的libc.so.6文件的malloc_trim()接口，尝试清理掉被缓存已free掉的内存信息
-- 使用方式：
-- 1. 可以单独用作init_worker_by_lua_file指令配置
-- 2. 或单独在对应需要初始化的代码所需要地方，导入即可：require "lua_malloc_trim"
-- User: nieyong@staff.weibo.com
-- Date: 2017/9/20
-- Time: 下午8:45

local ffi = require "ffi"
local glibc = ffi.load("c")

if ffi.os == "Windows" then
    ngx.log(ngx.ALERT, "DOES NOT SUPPORT windows")
    return
elseif ffi.os == "OSX" then
    ngx.log(ngx.ALERT, "DOES NOT SUPPORT MAC OS X")
    return
end

ffi.cdef[[
    int malloc_trim(size_t pad);
]]

local delay = 15 * 60  -- in seconds
local new_timer = ngx.timer.at
local log = ngx.log
local ERR = ngx.ERR
local NOTICE = ngx.NOTICE
local check

check = function(premature)
    if not premature then
        glibc.malloc_trim(1)
        log(NOTICE, "call malloc_trim ...")

        local ok, err = new_timer(delay, check)
        if not ok then
            log(ERR, "failed to create timer: ", err)
            return
        end
    end
end

local ok, err = new_timer(delay, check)
if not ok then
    log(ERR, "failed to create timer: ", err)
    return
end
