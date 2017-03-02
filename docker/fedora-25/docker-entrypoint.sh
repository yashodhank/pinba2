#!/bin/bash -xe

# this process is mildly copy-pasted from here
# https://github.com/docker-library/mariadb/tree/b558f64b736650b94df9a90e68ff9e3bc03d4bdb/10.1

if [ $1 = "mysqld" ]; then

	# fedora mysqld is in special location
	ln -snf /usr/libexec/mysqld /usr/local/bin

	# disable gss auth as it's not installed in this container
	rm -rf /etc/my.cnf.d/auth_gssapi.cnf

	# create default databases
	# too expensive to perform on container startup really
	mysql_install_db --rpm
	chmod -R 777 /var/lib/mysql

	# start mysql server in background for init process
	"$@" --skip-networking -umysql &
	pid="$!"

	# legen.... wait for it
	for i in {10..0}; do
		if echo 'SELECT 1' | mysql &> /dev/null; then
			break
		fi
		echo 'MySQL init process in progress...'
		sleep 1
	done
	if [ "$i" = 0 ]; then
		echo >&2 'MySQL init process failed.'
		exit 1
	fi

	# ..dary
	# install plugin and create default db + tables
	echo "INSTALL PLUGIN pinba SONAME 'libpinba_engine2.so';" | TERM=dumb mysql --protocol=socket -uroot
	echo "CREATE DATABASE pinba;" | TERM=dumb mysql --protocol=socket -uroot


	# terminate mysql server to start it in foreground
	if ! kill -s TERM "$pid" || ! wait "$pid"; then
		echo >&2 'MySQL init process failed.'
		exit 1
	fi
fi

exec "$@" -umysql
