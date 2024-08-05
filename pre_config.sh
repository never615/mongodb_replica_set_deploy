#!/bin/bash
set -eo pipefail

echo "Installing MongoDB pre config"

# 将 vm.swappiness 设置为 1
echo "vm.swappiness=1" >> /etc/sysctl.conf
sysctl -p


# 调整ulimit设置
cat >> /etc/security/limits.conf <<EOF
* soft nofile 65536
* hard nofile 65536
root soft nofile 65536
root hard nofile 65536

# 进程数限制
* soft nproc 65565
* hard nproc 65565
root soft nproc 65565
root hard nproc 65565
EOF



# 禁用透明大页
cat >> /etc/systemd/system/disable-transparent-huge-pages.service <<EOF
[Unit]
Description=Disable Transparent Huge Pages (THP)
DefaultDependencies=no
After=sysinit.target local-fs.target
Before=mongod.service

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'echo never | tee /sys/kernel/mm/transparent_hugepage/enabled > /dev/null'

[Install]
WantedBy=basic.target

EOF


systemctl daemon-reload
systemctl start disable-transparent-huge-pages
systemctl enable disable-transparent-huge-pages

mkdir -p /etc/tuned/virtual-guest-no-thp


cat >> /etc/tuned/virtual-guest-no-thp/tuned.conf <<EOF
[main]
include=virtual-guest

[vm]
transparent_hugepages=never
EOF


tuned-adm profile virtual-guest-no-thp

# 关闭包含atime的存储卷的数据库文件，提高mongodb性能
sed -i 's/defaults/defaults,noatime/' /etc/fstab
