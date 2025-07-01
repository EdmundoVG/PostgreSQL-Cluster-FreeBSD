#!/bin/sh
# Script de respaldo incremental de PostgreSQL (WAL archiving)
# Autor: Proyecto BD

# Variables
WAL_ARCHIVE_DIR="/var/backups/postgresql/wal_archive"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="/var/backups/postgresql/wal_backup_$DATE.log"

# Crear directorio si no existe
mkdir -p $WAL_ARCHIVE_DIR

# Copiar archivo WAL
cp "$1" "$WAL_ARCHIVE_DIR/$(basename $1)" 2>>$LOG_FILE

# Limpiar archivos WAL antiguos (más de 3 días)
find $WAL_ARCHIVE_DIR -name "0000*" -mtime +3 -delete

# Log del proceso
echo "$(date): WAL file $1 archived to $WAL_ARCHIVE_DIR" >> $LOG_FILE

exit 0
