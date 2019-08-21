#!/bin/bash
set -e # terminate execution on command failure

mysqlconn="mysql -u root"
olddb=$1
newdb=$2
$mysqlconn -e "CREATE DATABASE $newdb"
params=$($mysqlconn -N -e "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES \
                           WHERE table_schema='$olddb'")
for name in $params; do
      $mysqlconn -e "RENAME TABLE $olddb.$name to $newdb.$name";
done;
$mysqlconn -e "DROP DATABASE $olddb"

