docker compose down -v
rm -rf ./master/data/*
rm -rf ./slave/data/*
docker compose build
docker compose up -d

until docker exec MASTER sh -c 'mysql -uroot -pmaster-root123 -e ";"'
do
    echo "Waiting for MASTER database connection..."
    sleep 4
done

priv_stmt='CREATE USER "slave"@"%" IDENTIFIED WITH 'mysql_native_password' BY "slave123"; GRANT REPLICATION SLAVE ON *.* TO "slave"@"%"; FLUSH PRIVILEGES;'
docker exec MASTER sh -c "mysql -uroot -pmaster-root123 -e '$priv_stmt'"

until docker exec SLAVE sh -c 'mysql -uroot -pslave-root123 -e ";"'
do
    echo "Waiting for SLAVE database connection..."
    sleep 4
done

MS_STATUS=`docker exec MASTER sh -c 'mysql -uroot -pmaster-root123 -e "SHOW MASTER STATUS"'`
CURRENT_LOG=`echo $MS_STATUS | awk '{print $6}'`
CURRENT_POS=`echo $MS_STATUS | awk '{print $7}'`

start_slave_stmt="CHANGE MASTER TO MASTER_HOST='MASTER',MASTER_USER='slave',MASTER_PASSWORD='slave123',MASTER_LOG_FILE='$CURRENT_LOG',MASTER_LOG_POS=$CURRENT_POS; START SLAVE;"
start_slave_cmd="mysql -uroot -pslave-root123 -e \"$start_slave_stmt\""
docker exec SLAVE sh -c "$start_slave_cmd"
docker exec SLAVE sh -c "mysql -uroot -pslave-root123 -e 'SHOW SLAVE STATUS \G'"