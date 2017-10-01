#!/usr/bin/env bash

fname=$(date +%Y%m%d-%H%M%S)
ost=/usr/local/or_debug/openresty-systemtap-toolkit/
savep=/usr/local/or_debug/result
fgp=/usr/local/or_debug/FlameGraph

mkdir -p $savep

time=100

function help(){
    echo "Usage: cpu_flame.sh <options>
    Options:
        -p <pid>      set the nginx worker's pid (default is the max cpu used nginx worker's pid)
        -t <t>        set the time cost value you want to monitor, unit seconds (default is 100s)
        -h            display this help and exit
    "
}

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
    # 默认找到CPU占用最大的nginx worker进程
    pid=$(ps auxw| grep "nginx: worker process" | sort -rn -k3 | head -1 | awk '{print $2}')
fi

$ost/ngx-sample-lua-bt -p $pid --luajit20 -t $time > $savep/$fname.bt

$ost/fix-lua-bt $savep/$fname.bt > $savep/$fname_tmp.bt

$fgp/stackcollapse-stap.pl $savep/$fname_tmp.bt > $savep/$fname.cbt
$fgp/flamegraph.pl $savep/$fname.cbt > $savep/$fname.svg

cd $savep
rm -rf $savep/$fname*.*bt

hip=`ifconfig |grep -E "(:| )(10\.|172\.)" | sed "s/addr://g" | awk -F' ' '{print $2}' | awk '{print $1}' | sed "2d" | awk 'NR==1{print}'`

ps -ef|grep "python -m SimpleHTTPServer" | grep -v grep | awk '{print $2}' | xargs sudo kill -9

echo "visit url：http://$hip:8000/$fname.svg"
python -m SimpleHTTPServer &
