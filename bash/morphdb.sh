#! /bin/bash
export MYSQLCMD="/opt/morpheus/embedded/mysql/bin/mysql"
$MYSQLCMD --user morpheus --password=$(sudo jq ".mysql.morpheus_password" /etc/morpheus/morpheus-secrets.json -r) --host 127.0.0.1 morpheus
