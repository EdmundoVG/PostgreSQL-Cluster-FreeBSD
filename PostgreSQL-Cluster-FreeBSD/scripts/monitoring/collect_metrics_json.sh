#!/bin/sh
# Script que combina métricas CSV tradicionales + JSON estructurado

TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S%z')
HOSTNAME=$(hostname)
METRICS_LOG="/var/log/postgres_metrics.log"
AUDIT_LOG="/var/log/security_audit.json"

# Recolectar métricas del sistema
CPU_USAGE=$(top -n 1 | grep "CPU:" | awk '{print $2}' | sed 's/%//' || echo "0")
MEMORY_INFO=$(vmstat | tail -1)
MEMORY_FREE=$(echo $MEMORY_INFO | awk '{print $5}')
MEMORY_ACTIVE=$(echo $MEMORY_INFO | awk '{print $4}')
DISK_USAGE=$(df -h /var/db/postgres | tail -1 | awk '{print $5}' | sed 's/%//')

# Métricas PostgreSQL
if sudo -u postgres pg_isready -q > /dev/null 2>&1; then
    PG_CONNECTIONS=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | tr -d ' ' || echo "0")
    PG_DB_SIZE=$(sudo -u postgres psql -t -c "SELECT pg_size_pretty(pg_database_size('proyecto_bd'));" 2>/dev/null | tr -d ' ' || echo "N/A")
    
    if [ "$HOSTNAME" = "pg-master-01" ]; then
        SLAVE_COUNT=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_replication;" 2>/dev/null | tr -d ' ' || echo "0")
        EXTRA_METRIC="$SLAVE_COUNT"
    else
        WAL_STATUS=$(sudo -u postgres psql -t -c "SELECT status FROM pg_stat_wal_receiver;" 2>/dev/null | tr -d ' ' || echo "N/A")
        EXTRA_METRIC="$WAL_STATUS"
    fi
else
    PG_CONNECTIONS="0"
    PG_DB_SIZE="N/A"
    EXTRA_METRIC="N/A"
fi

# Escribir métricas CSV (mantener compatibilidad)
echo "$TIMESTAMP,$HOSTNAME,$CPU_USAGE,$MEMORY_FREE,$MEMORY_ACTIVE,$DISK_USAGE,$PG_CONNECTIONS,$PG_DB_SIZE,$EXTRA_METRIC" >> "$METRICS_LOG"

# Escribir métricas JSON
cat << METRICSEOF >> "$AUDIT_LOG"
{
  "timestamp": "$TIMESTAMP",
  "hostname": "$HOSTNAME",
  "event_type": "METRICS",
  "severity": "INFO",
  "category": "system",
  "event_name": "metrics_collection",
  "message": "System metrics collected",
  "script_version": "1.0",
  "details": {
    "cpu_usage": $CPU_USAGE,
    "memory_free": $MEMORY_FREE,
    "memory_active": $MEMORY_ACTIVE,
    "disk_usage": $DISK_USAGE,
    "pg_connections": $PG_CONNECTIONS,
    "pg_db_size": "$PG_DB_SIZE",
    "extra_metric": "$EXTRA_METRIC"
  }
},
METRICSEOF

# Generar dashboard si es master
if [ "$HOSTNAME" = "pg-master-01" ]; then
    /usr/local/scripts/monitoring/generate_audit_dashboard.sh > /dev/null 2>&1
fi
