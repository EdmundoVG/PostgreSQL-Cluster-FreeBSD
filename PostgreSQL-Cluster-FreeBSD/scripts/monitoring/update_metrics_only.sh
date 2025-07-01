#!/bin/sh

# Script para actualizar solo las métricas sin regenerar todo el dashboard
DASHBOARD_FILE="/usr/local/www/monitoring/index.html"
METRICS_LOG="/var/log/postgres_metrics.log"

# Recolectar métricas nuevas
echo "$(date): Recolectando métricas..."
/usr/local/scripts/monitoring/collect_from_slaves.sh > /dev/null 2>&1

# Obtener las métricas más recientes
SLAVE1_METRICS=$(grep "pg-slave-01" "$METRICS_LOG" 2>/dev/null | tail -1)
SLAVE2_METRICS=$(grep "pg-slave-02" "$METRICS_LOG" 2>/dev/null | tail -1)

# Verificar que tenemos métricas
if [ -z "$SLAVE1_METRICS" ] || [ -z "$SLAVE2_METRICS" ]; then
    echo "$(date): Error - No se pudieron obtener métricas"
    exit 1
fi

# Verificar estado de replicación y determinar status
SLAVE1_STATUS="streaming"
SLAVE2_STATUS="streaming"

# Si las métricas contienen 'N/A' en la columna de replicación, verificar directamente
if echo "$SLAVE1_METRICS" | grep -q "N/A"; then
    # Verificar directamente el estado de replicación del slave1
    REPL_CHECK=$(PGPASSWORD=ulloa psql -h 10.0.1.116 -p 5432 -U postgres -d proyecto_bd -t -c "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d ' \n')
    if [ "$REPL_CHECK" = "t" ]; then
        SLAVE1_STATUS="streaming"
        # Actualizar la métrica con el estado correcto
        SLAVE1_METRICS=$(echo "$SLAVE1_METRICS" | sed 's/N\/A$/streaming/')
    fi
fi

if echo "$SLAVE2_METRICS" | grep -q "N/A"; then
    # Verificar directamente el estado de replicación del slave2
    REPL_CHECK=$(PGPASSWORD=ulloa psql -h 10.0.1.25 -p 5432 -U postgres -d proyecto_bd -t -c "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d ' \n')
    if [ "$REPL_CHECK" = "t" ]; then
        SLAVE2_STATUS="streaming"
        # Actualizar la métrica con el estado correcto
        SLAVE2_METRICS=$(echo "$SLAVE2_METRICS" | sed 's/N\/A$/streaming/')
    fi
fi

# Crear archivo temporal con el dashboard actualizado
cp "$DASHBOARD_FILE" "$DASHBOARD_FILE.tmp"

# Usar awk para actualizar las líneas específicas de manera más segura
awk -v line1="$SLAVE1_METRICS" -v line2="$SLAVE2_METRICS" '
NR == 333 { print "            const slave1Metrics = parseMetrics(`" line1 "`);"; next }
NR == 334 { print "            const slave2Metrics = parseMetrics(`" line2 "`);"; next }
{ print }
' "$DASHBOARD_FILE.tmp" > "$DASHBOARD_FILE"

# Limpiar archivo temporal
rm "$DASHBOARD_FILE.tmp"

echo "$(date): Dashboard actualizado con métricas frescas"
echo "Slave1: $SLAVE1_METRICS (Status: $SLAVE1_STATUS)"
echo "Slave2: $SLAVE2_METRICS (Status: $SLAVE2_STATUS)"
