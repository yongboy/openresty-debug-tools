#!/usr/bin/env bash

PYTHONPATH="/usr/local/or_debug/openresty-gdb-utils/"
export PYTHONPATH

function help(){
    echo "Usage: auto_gdb.sh <options>
    Options:
        -p <pid>      set the nginx worker's pid (default is the max rss used nginx worker's pid)
        -h            display this help and exit
    "
}

while getopts "p:h" arg
do
    case $arg in
        p)
            pid=$OPTARG
            ;;
        h)
            help
            exit 1
            ;;
        ?)
            help
            exit 1
            ;;
    esac
done

if [ ! $pid ]; then
    # 默认找到RSS物理内存使用最大的nginx worker进程
    pid=$(ps auxw | grep "nginx: worker process" | sort -rn -k6 | head -1 | awk '{print $2}')
    echo "got used RES memory max nginx worker pid: $pid for auto gdb"
fi

# 若是遇到nginx (deleted): No such file or directory问题，可以改变一下GDB命令启动格式
# gdb /path/nginx $pid
gdb -p $pid
