#!/bin/bash
set -euo pipefail

function step() {
	echo "[$(date +"%Y-%m-%d %H:%M:%S")] $@"
}

[ -z "${MYSQL_PASSWORD:-}" ] && {
	echo 'No $MYSQL_PASSWORD was set, aborting.'
	exit 1
}

while [ 1 ]; do

	# Remove old backups older than N days (default 2d)
	DELETE_OLDER_THAN=${DELETE_OLDER_THAN:-2}

	# This directory is exposed by the postgres image
	TARGET_DIR=/data

	BACKUP_DATE=$(date +%Y-%m-%d_%H-%M-%S)

	# Collect databases
	step "Starting backup..."
	DATABASES=$(mysql \
		-h "${MYSQL_HOST:-mariadb}" -u "${MYSQL_USER:-root}" -p${MYSQL_PASSWORD} \
		-B --disable-column-names -e 'SHOW DATABASES' |
		grep -vE '(information_schema|performance_schema|mysql|tmp)')

	# Create backup
	for db_name in ${DATABASES}; do
		TARGET_FILE="${TARGET_DIR}/${BACKUP_DATE}_${db_name}.sql"
		step "Creating backup of ${db_name} in ${TARGET_FILE}..."
		mysqldump \
			-h "${MYSQL_HOST:-mariadb}" -u "${MYSQL_USER:-root}" -p${MYSQL_PASSWORD} \
			-a --databases "${db_name}" | gzip >"${TARGET_FILE}"
	done

	# Dump grants
	GRANTS_FILE="${TARGET_DIR}/${BACKUP_DATE}_grants.sql"
	step "Creating grants backuo in ${GRANTS_FILE}..."
	pt-show-grants -h "${MYSQL_HOST:-mariadb}" -u "${MYSQL_USER:-root}" -p "${MYSQL_PASSWORD}" >"${GRANTS_FILE}"

	# Cleanup old backups
	step "Removing old backups..."
	find "${TARGET_DIR}" -name '*.sql.gz' -mtime "${DELETE_OLDER_THAN}" -delete

	# Sleep until next full hour
	step "I'm done, see ya next hour!"
	sleep $((3600 - $(date +%s) % 3600))

done
