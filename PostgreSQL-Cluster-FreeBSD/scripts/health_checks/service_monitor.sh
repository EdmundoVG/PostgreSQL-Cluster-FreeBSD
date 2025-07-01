#!/bin/sh
# ==========================================
# SCRIPT DE HEALTH CHECKS Y AUTO-RECOVERY
# ==========================================

# Variables de configuración
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)
LOG_FILE="/var/log/health_checks.log"
ALERT_LOG="/var/log/health_alerts.log"
EMAIL_ALERTS=false  # Cambiar a true si quieres emails

# Función de logging
log_event() {
    local level="$1"
    local service="$2" 
    local message="$3"
    echo "$TIMESTAMP,[$level],$HOSTNAME,$service,$message" >> "$LOG_FILE"
    
    if [ "$level" = "CRITICAL" ] || [ "$level" = "ERROR" ]; then
        echo "$TIMESTAMP,[$level],$HOSTNAME,$service,$message" >> "$ALERT_LOG"
    fi
}

# Función para enviar alertas (opcional)
send_alert() {
    local subject="$1"
    local message="$2"
    
    if [ "$EMAIL_ALERTS" = "true" ]; then
        # Aquí puedes agregar comando de email si lo configuras
        echo "$TIMESTAMP: $subject - $message" >> /var/log/email_alerts.log
    fi
}

# ==========================================
# HEALTH CHECK: POSTGRESQL
# ==========================================
check_postgresql() {
    local service_name="postgresql"
    
    # Verificar si el proceso está corriendo
    if ! pgrep -f postgres > /dev/null; then
        log_event "ERROR" "$service_name" "PostgreSQL process not running"
        
        # Intentar reiniciar
        log_event "INFO" "$service_name" "Attempting to restart PostgreSQL"
        if sudo service postgresql start; then
            log_event "INFO" "$service_name" "PostgreSQL restarted successfully"
            send_alert "PostgreSQL Recovery" "PostgreSQL was down but has been restarted successfully"
        else
            log_event "CRITICAL" "$service_name" "Failed to restart PostgreSQL"
            send_alert "PostgreSQL CRITICAL" "PostgreSQL is down and restart failed"
            return 1
        fi
    fi
    
    # Verificar conectividad de base de datos
    if sudo -u postgres pg_isready -q; then
        log_event "OK" "$service_name" "PostgreSQL accepting connections"
    else
        log_event "WARNING" "$service_name" "PostgreSQL not accepting connections"
        
        # Intentar reiniciar
        log_event "INFO" "$service_name" "Restarting PostgreSQL due to connection issues"
        sudo service postgresql restart
        sleep 5
        
        if sudo -u postgres pg_isready -q; then
            log_event "INFO" "$service_name" "PostgreSQL connection restored after restart"
        else
            log_event "CRITICAL" "$service_name" "PostgreSQL connection still failing after restart"
            return 1
        fi
    fi
    
    # Verificar base de datos específica
    if sudo -u postgres psql -d proyecto_bd -c "SELECT 1;" > /dev/null 2>&1; then
        log_event "OK" "$service_name" "Database proyecto_bd accessible"
    else
        log_event "ERROR" "$service_name" "Database proyecto_bd not accessible"
        return 1
    fi
    
    return 0
}

# ==========================================
# HEALTH CHECK: NGINX (SOLO EN MASTER)
# ==========================================
check_nginx() {
    local service_name="nginx"
    
    # Verificar si estamos en el master (que tiene nginx)
    if [ "$HOSTNAME" != "pg-master-01" ]; then
        return 0  # Skip nginx check en slaves
    fi
    
    # Verificar proceso nginx
    if ! sockstat | grep -q ":8080"; then
        log_event "ERROR" "$service_name" "nginx process not running"
        
        # Intentar reiniciar
        log_event "INFO" "$service_name" "Attempting to start nginx"
        if sudo service nginx start; then
            log_event "INFO" "$service_name" "nginx started successfully"
            send_alert "nginx Recovery" "nginx was down but has been started successfully"
        else
            log_event "CRITICAL" "$service_name" "Failed to start nginx"
            send_alert "nginx CRITICAL" "nginx is down and start failed"
            return 1
        fi
    fi
    
    # Verificar puerto 8080 (dashboard)
    if sockstat | grep -q ":8080"; then
        log_event "OK" "$service_name" "nginx listening on port 8080"
    else
        log_event "WARNING" "$service_name" "nginx not listening on port 8080"
        
        # Intentar reiniciar
        sudo service nginx restart
        sleep 3
        
        if netstat -an | grep -q ":8080.*LISTEN"; then
            log_event "INFO" "$service_name" "nginx port 8080 restored after restart"
        else
            log_event "ERROR" "$service_name" "nginx port 8080 still not available"
            return 1
        fi
    fi
    
    # Verificar respuesta HTTP
    if curl -s http://localhost:8080 > /dev/null; then
        log_event "OK" "$service_name" "nginx responding to HTTP requests"
    else
        log_event "WARNING" "$service_name" "nginx not responding to HTTP requests"
    fi
    
    return 0
}

# ==========================================
# HEALTH CHECK: WEBMIN
# ==========================================
check_webmin() {
    local service_name="webmin"
    
    # Verificar proceso webmin
    if netstat -an | grep -q ":10000.*LISTEN"; then
        log_event "ERROR" "$service_name" "webmin process not running"
        
        # Intentar reiniciar
        log_event "INFO" "$service_name" "Attempting to start webmin"
        if sudo service webmin start; then
            log_event "INFO" "$service_name" "webmin started successfully"
            send_alert "webmin Recovery" "webmin was down but has been started successfully"
        else
            log_event "CRITICAL" "$service_name" "Failed to start webmin"
            send_alert "webmin CRITICAL" "webmin is down and start failed"
            return 1
        fi
    fi
    
    # Verificar puerto 10000
    if sockstat | grep -q ":10000"; then
        log_event "OK" "$service_name" "webmin listening on port 10000"
    else
        log_event "WARNING" "$service_name" "webmin not listening on port 10000"
        
        # Intentar reiniciar
        sudo service webmin restart
        sleep 5
        
        if netstat -an | grep -q ":10000.*LISTEN"; then
            log_event "INFO" "$service_name" "webmin port 10000 restored after restart"
        else
            log_event "ERROR" "$service_name" "webmin port 10000 still not available"
            return 1
        fi
    fi
    
    return 0
}

# ==========================================
# HEALTH CHECK: REPLICACIÓN (SOLO SLAVES)
# ==========================================
check_replication() {
    local service_name="replication"
    
    # Solo verificar en slaves
    if [ "$HOSTNAME" = "pg-master-01" ]; then
        return 0  # Skip replication check en master
    fi
    
    # Verificar si está en recovery mode (es slave)
    if sudo -u postgres psql -t -c "SELECT pg_is_in_recovery();" | grep -q "t"; then
        log_event "OK" "$service_name" "Server is in recovery mode (slave)"
    else
        log_event "CRITICAL" "$service_name" "Server not in recovery mode - may have been promoted"
        send_alert "Replication CRITICAL" "Slave server $HOSTNAME is not in recovery mode"
        return 1
    fi
    
    # Verificar conexión con master
    if sudo -u postgres psql -t -c "SELECT status FROM pg_stat_wal_receiver;" | grep -q "streaming"; then
        log_event "OK" "$service_name" "Receiving WAL stream from master"
    else
        log_event "ERROR" "$service_name" "Not receiving WAL stream from master"
        
        # Intentar reiniciar PostgreSQL para reconectar
        log_event "INFO" "$service_name" "Restarting PostgreSQL to restore replication"
        sudo service postgresql restart
        sleep 10
        
        if sudo -u postgres psql -t -c "SELECT status FROM pg_stat_wal_receiver;" | grep -q "streaming"; then
            log_event "INFO" "$service_name" "Replication restored after restart"
        else
            log_event "CRITICAL" "$service_name" "Replication still not working after restart"
            return 1
        fi
    fi
    
    return 0
}

# ==========================================
# HEALTH CHECK: SISTEMA (RECURSOS)
# ==========================================
check_system_resources() {
    local service_name="system"
    
    # Verificar uso de disco
    DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt 90 ]; then
        log_event "CRITICAL" "$service_name" "Disk usage critical: ${DISK_USAGE}%"
        send_alert "Disk Space CRITICAL" "Disk usage is ${DISK_USAGE}% on $HOSTNAME"
    elif [ "$DISK_USAGE" -gt 80 ]; then
        log_event "WARNING" "$service_name" "Disk usage high: ${DISK_USAGE}%"
    else
        log_event "OK" "$service_name" "Disk usage normal: ${DISK_USAGE}%"
    fi
    
    # Verificar memoria disponible
    MEMORY_FREE=$(vmstat | tail -1 | awk '{print $5}')
    MEMORY_FREE_MB=$((MEMORY_FREE / 1024))
    
    if [ "$MEMORY_FREE_MB" -lt 100 ]; then
        log_event "WARNING" "$service_name" "Low memory: ${MEMORY_FREE_MB}MB free"
    else
        log_event "OK" "$service_name" "Memory available: ${MEMORY_FREE_MB}MB free"
    fi
    
    # Verificar conectividad de red interna
    # Verificar conectividad de red interna (usando PostgreSQL en lugar de ping)
 if [ "$HOSTNAME" = "pg-master-01" ]; then
    # En master, verificar conectividad a slaves
     if sudo -u postgres psql -h 10.0.1.116 -p 5432 -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
         log_event "OK" "$service_name" "Network connectivity to slaves OK"
     else
         log_event "WARNING" "$service_name" "Network connectivity to slave-01 issues"
     fi
 else
     # En slaves, verificar conectividad al master via PostgreSQL
     if sudo -u postgres psql -h 10.0.1.16 -p 5432 -d postgres -c "SELECT 1;" > /dev/null 2>&1; then
         log_event "OK" "$service_name" "Network connectivity to master OK"
     else
         log_event "WARNING" "$service_name" "Network connectivity to master issues"
     fi
    fi
    
    return 0
}

# ==========================================
# FUNCIÓN PRINCIPAL
# ==========================================
main() {
    log_event "INFO" "health_check" "Starting health check scan"
    
    local overall_status=0
    
    # Ejecutar todos los health checks
    check_postgresql || overall_status=1
    check_nginx || overall_status=1
    check_webmin || overall_status=1
    check_replication || overall_status=1
    check_system_resources || overall_status=1
    
    # Log resultado general
    if [ $overall_status -eq 0 ]; then
        log_event "INFO" "health_check" "All health checks passed"
    else
        log_event "WARNING" "health_check" "Some health checks failed"
    fi
    
    # Rotar logs si son muy grandes (>5MB)
    if [ -f "$LOG_FILE" ]; then
        LOG_SIZE=$(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0)
        if [ "$LOG_SIZE" -gt 5242880 ]; then
            mv "$LOG_FILE" "${LOG_FILE}.old"
            log_event "INFO" "health_check" "Log file rotated due to size"
        fi
    fi
    
    log_event "INFO" "health_check" "Health check scan completed"
}

# Ejecutar función principal
main "$@"
