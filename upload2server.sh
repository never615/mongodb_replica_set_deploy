#!/bin/bash

set -eo pipefail


#如果$1为空，则提示并中断
if [ -z $1 ]; then
	echo "Usage: $0 file [file]"
	exit 1
fi

# echo "Uploading file $1 to server path $2"


#如果$2为空，则提示并中断
if [ -z $2 ]; then
	echo "Usage: $0 file [file]"
	exit 1
fi


# 上传文件到多个服务器
# $1: 上传的文件
# $2: 服务器路径

read -s -p "Enter password for server : " password

#echo 换行
echo -e "\n"

for server in "${@:3}"; do
	echo "Uploading file $1 to server $server, server path $2"
	sshpass -p $password scp $1 $server:$2
done



