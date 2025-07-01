#!/bin/sh

# ==========================================
# SCRIPT DE RECOLECCIÓN DE MÉTRICAS
# ==========================================

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)

# ==========================================
# MÉTRICAS DEL SISTEMA
# ==========================================

# CPU Usage
CPU_USAGE=$(top -n 1 | grep "CPU:" | awk '{print $2}' | sed 's/%//')

# Memory Usage
MEMORY_INFO=$(vmstat | tail -1)
MEMORY_FREE=$(echo $MEMORY_INFO | awk '{print $5}')
MEMORY_ACTIVE=$(echo $MEMORY_INFO | awk '{print $4}')

# Disk Usage
DISK_USAGE=$(df -h /var/db/postgres | tail -1 | awk '{print $5}' | sed 's/%//')

# ==========================================
# MÉTRICAS DE POSTGRESQL
# ==========================================

# Conexiones activas
PG_CONNECTIONS=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null || echo "0")

# Base de datos size
PG_DB_SIZE=$(sudo -u postgres psql -t -c "SELECT pg_size_pretty(pg_database_size('proyecto_bd'));" 2>/dev/null || echo "N/A")

# Estado de replicación
if [ "$HOSTNAME" = "pg-master-01" ]; then
    PG_REPLICATION=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_replication;" 2>/dev/null || echo "0")
else
    PG_REPLICATION="N/A"
fi

# ==========================================
# GUARDAR MÉTRICAS EN LOG
# ==========================================

LOG_FILE="/var/log/postgres_metrics.log"

echo "$TIMESTAMP,$HOSTNAME,$CPU_USAGE,$MEMORY_FREE,$MEMORY_ACTIVE,$DISK_USAGE,$PG_CONNECTIONS,$PG_DB_SIZE,$PG_REPLICATION" >> $LOG_FILE

# ==========================================
# GENERAR DASHBOARD HTML
# ==========================================
/usr/local/scripts/monitoring/generate_dashboard.sh
