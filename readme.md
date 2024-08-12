直接在主机上部署三副本的mongodb

适用于redhat8.2,其他系统未测试.

## 安装检查
```
1. 请至少使用 Linux 内核版本2.6.28:uname -a
2. 检查所需依赖项：libcurl openssl xz-libs,yum list installed | grep xz-libs
3. glibc必须安装: ldd --version
4. 检查数据磁盘是否挂载,如果没有则挂载好.挂在到/data目录
5. 确保您的系统已安装 checkpolicy 包：sudo yum install checkpolicy
yum list installed | grep checkpolicy
```


## 运行安装脚本
安装脚本需要以root用户运行,脚本需要有执行权限 chmod +x xx.sh
脚本所在目录包含文件:
* pre_config.sh
* mongodb_install.sh
* mongodb-linux-x86_64-rhel80-7.0.12.tgz
* mongosh-2.2.15-linux-x64.tgz


### 1. 先运行pre_config.sh对linux系统进行配置,以便于更好的运行mongodb.
上传vm-mongodb.zip到服务器,然后解压`unzip vm-mongodb.zip`

#### 上传文件到多个服务器
```
chmod +x upload2server.sh

执行环境需要安装sshpass. `brew installsshpass` `apt-get install sshpass` `yum install sshpass`

./upload2server.sh "/Users/never615/Code/docker/vm-mongodb.zip" "/home/mallto"  "mallto@192.168.1.92" "mallto@192.168.1.226" "mallto@192.168.1.231"
./upload2server.sh "/Users/never615/Code/docker/vm-mongodb.zip" "/mongodb_install"  "root@11.30.199.183" "root@11.30.199.184" "root@11.30.199.185"

解压: unzip vm-mongodb.zip
```


在脚本所在目录以root执行:
```
cd vm-mongodb
chmod +x *.sh
./pre_config.sh
reboot  重启服务器
```

运行完毕后执行`reboot`重启系统,三个服务器都要执行该脚本.
#### 验证:
* `cat /sys/kernel/mm/transparent_hugepage/enabled` 输出结果选择到了never.
* `cat /etc/security/limits.conf` 查看是否修改,应该包含65565.
* `cat /etc/fstab` 查看是否修改,应该包含noatime.
* `cat /proc/sys/vm/swappiness` 查看修改成了1

### 2. 运行mongodb_install.sh 安装mongodb
在脚本所在目录以root执行:
```
chmod +x mongodb_install.sh
./mongodb_install.sh 0    # 后面的0,在三台服务器上分别使用0 1 2,用来标识mongodb多副本的replSetName使用不同名字
```

检查是否成功启动: `systemctl status mongod`

### 3. 三个服务器需要配置dns主机名,联系网管配置,如:
本地测试的时候改linux `/etc/hosts`
```
192.168.1.92   mongodb0.example.net
192.168.1.226  mongodb1.example.net
192.168.1.231  mongodb2.example.net
```


### 多副本
1. 使用mongosh连接mongod实例 `mongosh`
2. 在副本集成员 0 上运行 rs.initiate()
> !!! 在副本集的mongod 一个且仅一个 实例上运行 rs.initiate()。
```
rs.initiate( {
   _id : "rs0",
   members: [
      { _id: 0, host: "mongodb0.example.net:27017" },
      { _id: 1, host: "mongodb1.example.net:27017" },
      { _id: 2, host: "mongodb2.example.net:27017" }
   ]
})

rs.initiate( {
   _id : "rs0",
   members: [
      { _id: 0, host: "kwhdbsvmcprd08.server.ha.org.hk:27017" },
      { _id: 1, host: "kwhdbsvmcprd09.server.ha.org.hk:27017" },
      { _id: 2, host: "kwhdbsvmcprd10.server.ha.org.hk:27017" }
   ]
})
```
3. 查看副本集配置,使用 `rs.conf()` 显示副本集配置对象
4. 确保副本集只有一个主节点,使用 `rs.status()` 标识副本集中的主节点。
