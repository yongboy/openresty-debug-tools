#!/usr/bin/env bash
# 初始化OpenResty跟踪调试环境，自动安装GDB 7.11，SystemTap 2.6，以及所需要依赖项
# 方便后续进行跟踪内存和CPU等问题

# 设定存放目录为 /usr/local/or_debug，按需修改
base=/usr/local/or_debug
mkidr -p $base
cd $base

function install_debuginfo_glibc(){
    drepo=/etc/yum.repos.d/CentOS-Debug.repo
    sn=`grep -o "[0-9]*" /etc/issue | head -1`

    if [ ! -f "${drepo}" ]; then
        echo "install glibc debuginfo package ..."
        cat > ${drepo} <<EOF
[debug]

name=CentOS-${sn} - Debuginfo
baseurl=http://debuginfo.centos.org/${sn}/\$basearch/
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-Debug-${sn}
enabled=1
EOF
        debuginfo-install -y glibc
    else
        echo "had installed glibc debuginfo package ..."
    fi
}

function install_gdb(){
    wget https://ftp.gnu.org/gnu/gdb/gdb-7.11.tar.xz --no-check-certificate
    tar xf gdb-7.11.tar.xz
    cd gdb-7.11

    ./configure --prefix=/usr --with-system-readline --without-guile --with-python
    make -j8
    make -C gdb install

    gdb -v
    cd $base
    rm -rf gdb-7.11*

    cat > ~/.gdbinit <<EOF
directory $base/openresty-gdb-utils

py import sys
py sys.path.append("/data0/or_debug/openresty-gdb-utils")

source luajit20.gdb
source ngx-lua.gdb
source luajit21.py
source ngx-raw-req.py
set python print-stack full
EOF
}

function install_stap(){
    yum install -y elfutils-devel
    wget https://sourceware.org/systemtap/ftp/releases/systemtap-2.6.tar.gz --no-check-certificate
    tar xf systemtap-2.6.tar.gz
    cd systemtap-2.6
    ./configure --prefix=/usr/local --disable-docs \
            --disable-publican --disable-refdocs CFLAGS="-g -O2"

    make -j8
    make install
    cd $base
    rm -rf systemtap-2.6*
    echo $PATH
    export PATH
}

# 初始化文件目录，拉取文件目录
mkdir -p $base
mkdir -p $base/result
cd $base

# 自动安装内核调试包
k=`rpm -qa | grep kernel | grep $(uname -r)`
di=`echo $k | sed "s/ /\n/g" | grep kernel-debuginfo`
de=`echo $k | sed "s/ /\n/g" | grep kernel-devel`
echo "current installed linux kernel debuginfo package:"
echo $di | sed "s/ /\n/g"
echo $de | sed "s/ /\n/g"

if [ "$di" = "" ]||[ "$de" = "" ];then
    echo "now install linux kernel debuginfo package ..."
    yum install -y yum-utils
    yum install -y kernel-devel
    debuginfo-install -y kernel
else
    echo "had installed linux kernel debuginfo package, past ..."
fi

install_debuginfo_glibc

#自动安装gdb、systemtap，和valgrind等
gv=`gdb -v | grep "GNU gdb" | awk '{print $NF}'`
if [ "$gv" != "7.11" ];then
    echo "install gdb 7.11 ..."
    install_gdb
else
    echo "had installed gdb 7.11, past ..."
fi

sv=`stap -V 2>&1 | grep "2.6"`
if [ "$sv" == "" ]; then
    echo "install systemstap 2.6 ..."
    install_stap
else
    echo "had installed systemstap 2.6, past ..."
fi

# 同步一些基础依赖文件
if [ ! -d "$base/stapxx" ]; then
    echo "now clone base depends ..."
    git clone https://github.com/openresty/stapxx.git
    git clone https://github.com/openresty/openresty-gdb-utils.git
    git clone https://github.com/openresty/openresty-systemtap-toolkit.git
    git clone https://github.com/brendangregg/FlameGraph.git

    git clone https://github.com/yongboy/openresty-debug-tools.git
else
    echo "had cloned base depends, past ..."
fi

echo "done!"
