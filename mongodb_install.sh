#!/bin/bash

set -eo pipefail

#解压mongodb:
tar -zxvf mongodb-linux-x86_64-rhel80-7.0.12.tgz
chmod +x mongodb-linux-x86_64-rhel80-7.0.12/bin/*
cp mongodb-linux-x86_64-rhel80-7.0.12/bin/* /usr/local/bin/

#解压mongosh:
tar -zxvf mongosh-2.2.15-linux-x64.tgz
chmod +x mongosh-2.2.15-linux-x64/bin/mongosh
cp mongosh-2.2.15-linux-x64/bin/mongosh /usr/local/bin/
cp mongosh-2.2.15-linux-x64/bin/mongosh_crypt_v1.so /usr/local/lib/

# mongo运行前准备
mkdir -p /data/mongodb/data
mkdir -p /data/mongodb/log
touch /data/mongodb/log/mongod.log
groupadd mongod
useradd -M -s /bin/false  -g mongod mongod
chown -R mongod:mongod /data/mongodb

# 允许访问 cgroup
cat > mongodb_cgroup_memory.te <<EOF
module mongodb_cgroup_memory 1.0;

require {
      type cgroup_t;
      type mongod_t;
      class dir search;
      class file { getattr open read };
}

#============= mongod_t ==============
allow mongod_t cgroup_t:dir search;
allow mongod_t cgroup_t:file { getattr open read };
EOF

checkmodule -M -m -o mongodb_cgroup_memory.mod mongodb_cgroup_memory.te
semodule_package -o mongodb_cgroup_memory.pp -m mongodb_cgroup_memory.mod
semodule -i mongodb_cgroup_memory.pp

# 允许访问 netstat 以支持 FTDC
cat > mongodb_proc_net.te <<EOF
module mongodb_proc_net 1.0;

require {
    type cgroup_t;
    type configfs_t;
    type file_type;
    type mongod_t;
    type proc_net_t;
    type sysctl_fs_t;
    type var_lib_nfs_t;

    class dir { search getattr };
    class file { getattr open read };
}

#============= mongod_t ==============
allow mongod_t cgroup_t:dir { search getattr } ;
allow mongod_t cgroup_t:file { getattr open read };
allow mongod_t configfs_t:dir getattr;
allow mongod_t file_type:dir { getattr search };
allow mongod_t file_type:file getattr;
allow mongod_t proc_net_t:file { open read };
allow mongod_t sysctl_fs_t:dir search;
allow mongod_t var_lib_nfs_t:dir search;
EOF

checkmodule -M -m -o mongodb_proc_net.mod mongodb_proc_net.te
semodule_package -o mongodb_proc_net.pp -m mongodb_proc_net.mod
semodule -i mongodb_proc_net.pp

# 使用自定义 MongoDB 目录路径处理SELinux权限
semanage fcontext -a -t mongod_var_lib_t '/data/mongodb/data.*'
chcon -Rv -u system_u -t mongod_var_lib_t '/data/mongodb/data'
restorecon -R -v '/data/mongodb/data'

semanage fcontext -a -t mongod_log_t '/data/mongodb/log.*'
chcon -Rv -u system_u -t mongod_log_t '/data/mongodb/log'
restorecon -R -v '/data/mongodb/log'

cp mongod.conf /etc/mongod.conf

cat > /etc/systemd/system/mongod.service <<EOF
[Unit]
Description=MongoDB Database Server
Documentation=https://docs.mongodb.org/manual
After=network.target

[Service]
User=mongod
Group=mongod
ExecStart=/usr/local/bin/mongod --config /etc/mongod.conf
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
PIDFile=/var/run/mongodb/mongod.pid
TimeoutSec=30
RemainAfterExit=yes
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable mongod
systemctl start mongod



