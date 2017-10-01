#!/usr/bin/env bash
# 检测当前内存使用情况，生成内存泄露火焰图，并给出内存泄露火焰图临时访问地址

fname=$(date +%Y%m%d-%H%M%S)
savep=/usr/local/or_debug/result
stpx=/usr/local/or_debug/stapxx
fgp=/usr/local/or_debug/FlameGraph

ost=/usr/local/or_debug/openresty-systemtap-toolkit/

function help(){
    echo "Usage: check_leaks.sh <options>
    Options:
        -p <pid>      set the nginx worker's pid (default is the max rss used nginx worker's pid)
        -t <t>        set the time cost value you want to monitor, unit seconds (default is 300s)
        -h            display this help and exit
    "
}

# 默认检测时间，单位秒
time=300
while getopts "p:t:h" arg
do
    case $arg in
        p)
            pid=$OPTARG
            ;;
        t)
            time=$OPTARG
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
fi

echo "got used RES memory max nginx worker pid: $pid"

mkdir -p $savep

echo "ngx lj gc info:"
$stpx/samples/lj-gc.sxx -x $pid
$stpx/samples/lj-gc-objs.sxx -x $pid -D MAXACTION=300000

echo "ngx-cycle-pool info:"
$ost/ngx-cycle-pool -p $pid

echo "trace memory link ..."
$stpx/samples/sample-bt-leaks.sxx -x $pid --arg time=$time \
        -D STP_NO_OVERLOAD -D MAXMAPENTRIES=100000 > $savep/$fname.bt

$fgp/stackcollapse-stap.pl $savep/$fname.bt > $savep/$fname_tmp.cbt

$fgp/flamegraph.pl --countname=bytes --title="Memory Leak Flame Graph" $savep/$fname_tmp.cbt > $savep/$fname.svg

hip=`ifconfig |grep -E "(:| )(10\.|172\.)" | sed "s/addr://g" | awk -F' ' '{print $2}' | awk '{print $1}' | sed "2d" | awk 'NR==1{print}'`

cd $savep
rm -rf $savep/$fname*.*bt

ps -ef|grep "python -m SimpleHTTPServer" | grep -v grep | awk '{print $2}' | xargs kill -9

echo "visit url：http://$hip:8000/$fname.svg"
python -m SimpleHTTPServer &
