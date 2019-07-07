### docker-compose 构建 Mysql 主从备份

#### docker-compose.yml

```yml
version: '3.0'
services:
  master:
    image: docker.io/mysql:5.7.26
    container_name: mysql_master
    environment:
      - MYSQL_ROOT_PASSWORD=***
    ports:
      - 3306:3306
    volumes:
      - master-conf:/etc/mysql/conf.d
      - master:/var/lib/mysql
    networks:
      - mysqlnet

  slave1:
    image: docker.io/mysql:5.7.26
    container_name: mysql_slave1
    environment:
      - MYSQL_ROOT_PASSWORD=***
    ports:
      - 3307:3306
    volumes:
      - slave1-conf:/etc/mysql/conf.d
      - slave1:/var/lib/mysql
    networks:
      - mysqlnet

  slave2:
    image: docker.io/mysql:5.7.26
    container_name: mysql_slave2
    environment:
      - MYSQL_ROOT_PASSWORD=***
    ports:
      - 3308:3306
    volumes:
      - slave2-conf:/etc/mysql/conf.d
      - slave2:/var/lib/mysql
    networks:
      - mysqlnet

volumes:
  master:
    driver: local
  master-conf:
    driver: local
  slave1:
    driver: local
  slave1-conf:
    driver: local
  slave2:
    driver: local
  slave2-conf:
    driver: local

networks:
  mysqlnet:
```

#### master 配置

```
[mysql]
# 设置mysql客户端默认字符集
default-character-set=utf8mb4
[mysqld]
# 允许最大连接数
max_connections=200
# 服务端使用的字符集默认为8比特编码的latin1字符集
character-set-server=utf8mb4
# 同一局域网内注意要唯一
server-id=100
# 开启二进制功能，可以随便取
log-bin=mysql-bin
[mysqldump]
# 用户名
user=shan
# 密码
password=***
```

#### slave1 配置

```
[mysql]
# 设置mysql客户端默认字符集
default-character-set=utf8mb4
[mysqld]
# 允许最大连接数
max_connections=200
# 服务端使用的字符集默认为8比特编码的latin1字符集
character-set-server=utf8mb4
# 设置server_id,注意要唯一
server-id=101
# 开启二进制日志功能，以备Slave作为其它Slave的Master时使用
log-bin=mysql-slave-bin
# relay_log配置中继日志
relay_log=edu-mysql-relay-bin
```

#### slave2 配置

```
[mysql]
# 设置mysql客户端默认字符集
default-character-set=utf8mb4
[mysqld]
# 允许最大连接数
max_connections=200
# 服务端使用的字符集默认为8比特编码的latin1字符集
character-set-server=utf8mb4
# 设置server_id,注意要唯一
server-id=102
# 开启二进制日志功能，以备Slave作为其它Slave的Master时使用
log-bin=mysql-slave-bin
# relay_log配置中继日志
relay_log=edu-mysql-relay-bin
```

#### master 创建数据同步账号

```mysql
CREATE USER 'user'@'192.168.137.%' IDENTIFIED BY 'password';
GRANT REPLICATION SLAVE ON *.* TO 'user'@'192.168.137.%';
FLUSH PRIVILEGES;
# 查看master信息
SHOW MASTER STATUS;
```

#### slave 配置

```mysql
STOP SLAVE;

change MASTER TO master_host = '192.168.137.100',
master_user = 'user',
master_password = 'password',
master_port = 3306,
master_log_file = 'mysql-bin.000001',
master_log_pos = 971,
master_connect_retry = 30;

START SLAVE;
```

### 定时备份

#### mysqlbak.sh 备份脚本

[Mysql 定时备份	原创： 小彬彬](https://mp.weixin.qq.com/s?__biz=Mzg2NzIyNzM0OA==&mid=2247483703&idx=1&sn=33e6fbba4c745f3c6a0f3d52242a8b27&chksm=cebf828cf9c80b9af01425e9525b16c922e41606f0202ef1f762da55d57085877cd6e535a0ef&mpshare=1&scene=1&srcid=&key=f9a94282848b718a3341d17bc72ecd7a965671f475ee2edc444022fdf51d38646468fedb97d4751359ea4ab1ee9c9de1751905d6c92c0487d6c80e5f4f691f268e3d88fb9b7285e1589f8725c5ea7230&ascene=1&uin=MTE0Mzg5MzQyMg%3D%3D&devicetype=Windows+10&version=62060833&lang=zh_CN&pass_ticket=Vbs%2FelbLzEuLOX5HHAlGHng1jZ1AtBDNEdPIr4MbwDToW6V1N86ZtcPd3kobJbK2)

#### 安装必要工具

```shell
# 安装网络查看工具
yum install net-tools
```

#### 创建存放备份数据的目录

```shell
# data目录存放数据，log存放备份时打印的日志
mkdir -p /usr/local/mysql/backup/{data,log}
```

#### 备份脚本

```shell
#!/bin/bash
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
```

#### 配置定时任务

```shell
vim /etc/crontab
```

```shell
SHELL=/bin/bash
PATH=/sbin:/bin:/usr/sbin:/usr/bin
MAILTO=root

# For details see man 4 crontabs

# Example of job definition:
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  * user-name  command to be executed
0 3 * * * root /bin/sh /usr/local/mysql/backup/mysqlbak.sh
```

#### 启动crontab执行任务

```shell
# 启动cron执行任务
crontab /etc/crontab
```

#### crontab 常用命令

```shell
# 查看执行的任务
crontab -l
# 删除任务
crontab -r
# 查看执行日志
tail -f /var/log/cron
# 设为开机启动
systemctl enable crond
# 启动crond服务
systemctl start crond
# 查看状态
systemctl status crond
```

