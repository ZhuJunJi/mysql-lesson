BASE_NAME=$(basename `pwd`)

echo "将master目录下的配置文件复制到 docker volume /var/lib/docker/volumes/${BASE_NAME}_master-conf/_data"
cp -f ./master/mysql.cnf /var/lib/docker/volumes/${BASE_NAME}_master-conf/_data

echo "将slave1目录下的配置文件复制到 docker volume /var/lib/docker/volumes/${BASE_NAME}_slave1-conf/_data"
cp -f ./slave1/mysql.cnf /var/lib/docker/volumes/${BASE_NAME}_master-conf/_data

echo "将slave2目录下的配置文件复制到 docker volume /var/lib/docker/volumes/${BASE_NAME}_slave2-conf/_data"
cp -f ./slave2/mysql.cnf /var/lib/docker/volumes/${BASE_NAME}_master-conf/_data

echo "重启docker-compose"

docker-compose restart
