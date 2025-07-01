#!/bin/sh
# Script de respaldo completo de PostgreSQL
# Autor: Proyecto BD
# Fecha: $(date)

# Variables
BACKUP_DIR="/var/db/postgres/backups"
DATE=$(date +%Y%m%d_%H%M%S)
LOG_FILE="$BACKUP_DIR/backup_$DATE.log"

# Crear respaldo de todas las bases de datos
echo "Iniciando respaldo completo: $DATE" > $LOG_FILE

# Respaldo con pg_dumpall (esquema global + datos)
/usr/local/bin/pg_dumpall -U postgres > $BACKUP_DIR/backup_completo_$DATE.sql 2>>$LOG_FILE

# Comprimir respaldo
gzip $BACKUP_DIR/backup_completo_$DATE.sql

# Respaldo específico de la base del proyecto
/usr/local/bin/pg_dump -U postgres -d proyecto_bd > $BACKUP_DIR/proyecto_bd_$DATE.sql 2>>$LOG_FILE
gzip $BACKUP_DIR/proyecto_bd_$DATE.sql

# Limpiar respaldos antiguos (más de 7 días)
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete

echo "Respaldo completado: $DATE" >> $LOG_FILE
echo "Archivos generados:" >> $LOG_FILE
ls -lh $BACKUP_DIR/*$DATE* >> $LOG_FILE
