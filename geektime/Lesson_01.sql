-- 连接命令
mysql -h$ip -P$port -u$user -p
-- 查看连接信息
show processlist;
-- 缓存参数
query_cache_type
-- 显示指定查询缓存
select SQL_CACHE * from T where ID=10；