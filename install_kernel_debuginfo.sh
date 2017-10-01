#!/usr/bin/env bash

# 获取当前CentOS系统大版本，比如是6，还是7
bv=`grep -o "[0-9]*" /etc/issue | head -1`

# 获取内核版本，比如2.6.32-642.el6.x86_64
klv=`uname -r`

kdev=kernel-devel-${klv}.rpm
if [ ! -f "$kdev" ]; then
    # 若下载不到，直接Google搜索，是最节省体力的方式
    wget ftp://ftp.pbone.net/mirror/ftp.scientificlinux.org/linux/scientific/6.8/x86_64/os/Packages/$kdev
fi
rpm -ivh $kdev

kdc=kernel-debuginfo-common-x86_64-${klv}.rpm
if [ ! -f "$kdc" ]; then
    wget http://debuginfo.centos.org/${bv}/x86_64/$kdc
fi
rpm -ivh $kdc

kd=kernel-debuginfo-${klv}.rpm
if [ ! -f "$kd" ]; then
    wget http://debuginfo.centos.org/${bv}/x86_64/$kd
fi
rpm -ivh $kd

echo "done"
