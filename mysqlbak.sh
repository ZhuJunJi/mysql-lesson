#!/bin/bash
# https://mp.weixin.qq.com/s?__biz=Mzg2NzIyNzM0OA==&mid=2247483703&idx=1&sn=33e6fbba4c745f3c6a0f3d52242a8b27&chksm=cebf828cf9c80b9af01425e9525b16c922e41606f0202ef1f762da55d57085877cd6e535a0ef&mpshare=1&scene=1&srcid=&key=f9a94282848b718a3341d17bc72ecd7a965671f475ee2edc444022fdf51d38646468fedb97d4751359ea4ab1ee9c9de1751905d6c92c0487d6c80e5f4f691f268e3d88fb9b7285e1589f8725c5ea7230&ascene=1&uin=MTE0Mzg5MzQyMg%3D%3D&devicetype=Windows+10&version=62060833&lang=zh_CN&pass_ticket=Vbs%2FelbLzEuLOX5HHAlGHng1jZ1AtBDNEdPIr4MbwDToW6V1N86ZtcPd3kobJbK2
#数据库名
dbname='***'
#数据库用户
mysql_user='***'
#数据库密码
mysql_password='***'
#数据库端口
mysql_port='3306'
#备份时间
backtime=`date +%Y%m%d%H%M%S`
#日志备份路径
logpath='/usr/local/mysql/backup/log'
#数据备份路径
datapath='/usr/local/mysql/backup/data'
#需要备份的mysql容器名字
docker_name='mysql_container'
# 判断MYSQL是否启动,mysql没有启动则备份退出
mysql_ps=`ps -ef |grep mysql |wc -l`
mysql_listen=`netstat -an |grep LISTEN |grep $mysql_port|wc -l`
if [ [$mysql_ps == 0] -o [$mysql_listen == 0] ]; then
  echo "ERROR:MySQL is not running! backup stop!" >> ${logpath}/mysqllog.log
  exit
fi
#日志记录头部
echo "备份时间为${backtime},备份数据库表 ${dbname} 开始..." >> ${logpath}/mysqllog.log
#备份数据库
source=`docker exec ${docker_name} mysqldump -u${mysql_user} -p${mysql_password} ${dbname}> ${datapath}/${backtime}.sql` 2>> ${logpath}/mysqllog.log;
#备份成功以下操作
if [ "$?" == 0 ];then 
cd $datapath
#为节约硬盘空间，将数据库压缩
tar zcf ${dbname}${backtime}.tar.gz ${backtime}.sql > /dev/null
#删除原始文件，只留压缩后文件
rm -f ${datapath}/${backtime}.sql
#删除七天前备份，也就是只保存7天内的备份
find $datapath -name "*.tar.gz" -type f -mtime +7 -exec rm -rf {} \; > /dev/null 2>&1

echo "数据库表 ${dbname} 备份成功!!" >> ${logpath}/mysqllog.log
else
#备份失败则进行以下操作
echo "数据库表 ${dbname} 备份失败!!" >> ${logpath}/mysqllog.log
fi
