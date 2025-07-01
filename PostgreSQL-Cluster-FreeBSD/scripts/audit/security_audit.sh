#!/bin/sh
# Script de auditoría de seguridad con logs JSON estructurados

TIMESTAMP=$(date '+%Y-%m-%dT%H:%M:%S%z')
HOSTNAME=$(hostname)
AUDIT_LOG="/var/log/security_audit.json"
ALERT_LOG="/var/log/security_alerts.json"
SCRIPT_VERSION="1.0"
AUDIT_SESSION_ID="audit_$(date +%s)_$$"

if [ "$HOSTNAME" = "pg-master-01" ]; then
    SERVER_ROLE="master"
else
    SERVER_ROLE="slave"
fi

log_json() {
    local event_type="$1"
    local severity="$2"
    local category="$3"
    local event_name="$4"
    local message="$5"
    local details="$6"
    
    if [ -z "$details" ]; then
        details="{}"
    fi
    
    cat << JSONEOF >> "$AUDIT_LOG"
{
  "timestamp": "$TIMESTAMP",
  "audit_session_id": "$AUDIT_SESSION_ID",
  "hostname": "$HOSTNAME",
  "server_role": "$SERVER_ROLE",
  "event_type": "$event_type",
  "severity": "$severity",
  "category": "$category",
  "event_name": "$event_name",
  "message": "$message",
  "script_version": "$SCRIPT_VERSION",
  "details": $details
},
JSONEOF
    
    if [ "$severity" = "CRITICAL" ] || [ "$severity" = "ERROR" ]; then
        cat << ALERTEOF >> "$ALERT_LOG"
{
  "timestamp": "$TIMESTAMP",
  "hostname": "$HOSTNAME",
  "severity": "$severity",
  "alert_type": "$event_type",
  "message": "$message",
  "requires_attention": true
},
ALERTEOF
    fi
}

audit_system_users() {
    log_json "SECURITY" "INFO" "users" "audit_start" "Iniciando auditoría de usuarios del sistema"
    
    ROOT_USERS=$(awk -F: '$3 == 0 {print $1}' /etc/passwd | tr '\n' ',' | sed 's/,$//')
    if [ $(echo "$ROOT_USERS" | tr ',' '\n' | wc -l) -gt 1 ]; then
        log_json "SECURITY" "WARNING" "users" "multiple_root_users" \
            "Múltiples usuarios con UID 0 detectados" \
            "{\"root_users\": \"$ROOT_USERS\", \"count\": $(echo "$ROOT_USERS" | tr ',' '\n' | wc -l)}"
    else
        log_json "SECURITY" "INFO" "users" "root_users_normal" \
            "Solo el usuario root tiene UID 0" \
            "{\"root_user\": \"$ROOT_USERS\"}"
    fi
    
    SHELL_USERS=$(awk -F: '$7 !~ /nologin|false/ && $7 != "" {print $1}' /etc/passwd | wc -l)
    log_json "SECURITY" "INFO" "users" "users_with_shell_access" \
        "Usuarios con acceso de shell" \
        "{\"shell_users_count\": $SHELL_USERS}"
}

audit_processes() {
    log_json "SECURITY" "INFO" "processes" "audit_start" "Iniciando auditoría de procesos"
    
    HIGH_CPU=$(ps aux | awk '$3 > 10.0' | wc -l)
    if [ "$HIGH_CPU" -gt 0 ]; then
        log_json "SECURITY" "WARNING" "processes" "high_cpu_usage" \
            "Procesos con alto uso de CPU detectados" \
            "{\"high_cpu_count\": $HIGH_CPU}"
    else
        log_json "SECURITY" "INFO" "processes" "normal_cpu_usage" \
            "Uso de CPU normal en todos los procesos" \
            "{\"cpu_status\": \"normal\"}"
    fi
    
    PG_PROCESSES=$(ps aux | grep -E "(postgres|pg_)" | grep -v grep | wc -l)
    log_json "DATABASE" "INFO" "processes" "postgresql_processes" \
        "Procesos de PostgreSQL activos" \
        "{\"pg_process_count\": $PG_PROCESSES}"
}

audit_critical_files() {
    log_json "SECURITY" "INFO" "files" "audit_start" "Iniciando auditoría de archivos críticos"
    
    CRITICAL_FILES="/etc/passwd /var/db/postgres/data15/postgresql.conf /var/db/postgres/data15/pg_hba.conf"
    
    for file in $CRITICAL_FILES; do
        if [ -f "$file" ]; then
            PERMS=$(ls -la "$file" | awk '{print $1}')
            OWNER=$(ls -la "$file" | awk '{print $3 ":" $4}')
            
            log_json "SECURITY" "INFO" "files" "critical_file_status" \
                "Estado de archivo crítico: $file" \
                "{\"file_path\": \"$file\", \"permissions\": \"$PERMS\", \"owner\": \"$OWNER\"}"
        else
            log_json "SECURITY" "ERROR" "files" "critical_file_missing" \
                "Archivo crítico no encontrado" \
                "{\"missing_file\": \"$file\"}"
        fi
    done
}

audit_network_connections() {
    log_json "SECURITY" "INFO" "network" "audit_start" "Iniciando auditoría de conexiones de red"
    
    SSH_CONNECTIONS=$(who | grep -v console | wc -l)
    log_json "SECURITY" "INFO" "network" "ssh_connections" \
        "Conexiones SSH activas" \
        "{\"connection_count\": $SSH_CONNECTIONS}"
    
    if command -v sudo >/dev/null && id postgres >/dev/null 2>&1; then
        PG_CONNECTIONS=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_stat_activity WHERE state = 'active';" 2>/dev/null | tr -d ' ' || echo "0")
        log_json "DATABASE" "INFO" "network" "postgresql_active_connections" \
            "Conexiones PostgreSQL activas" \
            "{\"active_connections\": $PG_CONNECTIONS}"
    fi
    
    OPEN_PORTS=$(sockstat -l | awk 'NR>1 {print $6}' | cut -d: -f2 | sort -n | uniq | wc -l)
    log_json "SECURITY" "INFO" "network" "open_ports" \
        "Puertos abiertos en el sistema" \
        "{\"open_ports_count\": $OPEN_PORTS}"
}

audit_postgresql_security() {
    log_json "DATABASE" "INFO" "postgresql" "audit_start" "Iniciando auditoría de seguridad PostgreSQL"
    
    if command -v sudo >/dev/null && id postgres >/dev/null 2>&1; then
        if [ -f "/var/db/postgres/data15/postgresql.conf" ]; then
            LOG_STMT=$(grep "^log_statement" /var/db/postgres/data15/postgresql.conf | head -1 || echo "not_configured")
            log_json "DATABASE" "INFO" "postgresql" "logging_configuration" \
                "Configuración de logging de statements" \
                "{\"log_statement_config\": \"$LOG_STMT\"}"
        fi
        
        PG_USERS=$(sudo -u postgres psql -t -c "SELECT count(*) FROM pg_roles;" 2>/dev/null | tr -d ' ' || echo "0")
        log_json "DATABASE" "INFO" "postgresql" "database_users" \
            "Usuarios de PostgreSQL" \
            "{\"users_count\": $PG_USERS}"
    else
        log_json "DATABASE" "WARNING" "postgresql" "cannot_audit_postgresql" \
            "No se puede auditar PostgreSQL (usuario postgres no disponible)" \
            "{\"reason\": \"postgres_user_unavailable\"}"
    fi
}

analyze_suspicious_patterns() {
    log_json "SECURITY" "INFO" "analysis" "pattern_analysis_start" "Iniciando análisis de patrones sospechosos"
    
    DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt 80 ]; then
        log_json "SYSTEM" "WARNING" "analysis" "high_disk_usage" \
            "Uso de disco alto detectado" \
            "{\"disk_usage_percent\": $DISK_USAGE}"
    else
        log_json "SYSTEM" "INFO" "analysis" "normal_disk_usage" \
            "Uso de disco normal" \
            "{\"disk_usage_percent\": $DISK_USAGE}"
    fi
    
    MEMORY_FREE=$(vmstat | tail -1 | awk '{print $5}')
    MEMORY_FREE_MB=$((MEMORY_FREE / 1024))
    if [ "$MEMORY_FREE_MB" -lt 500 ]; then
        log_json "SYSTEM" "WARNING" "analysis" "low_memory" \
            "Memoria disponible baja" \
            "{\"memory_free_mb\": $MEMORY_FREE_MB}"
    else
        log_json "SYSTEM" "INFO" "analysis" "normal_memory" \
            "Memoria disponible normal" \
            "{\"memory_free_mb\": $MEMORY_FREE_MB}"
    fi
}

main() {
    echo "# Security Audit Session Started: $TIMESTAMP" >> "$AUDIT_LOG"
    echo "# Audit Session ID: $AUDIT_SESSION_ID" >> "$AUDIT_LOG"
    
    log_json "SECURITY" "INFO" "system" "audit_session_start" \
        "Iniciando sesión de auditoría de seguridad completa" \
        "{\"session_id\": \"$AUDIT_SESSION_ID\", \"script_version\": \"$SCRIPT_VERSION\"}"
    
    audit_system_users
    audit_processes
    audit_critical_files
    audit_network_connections
    audit_postgresql_security
    analyze_suspicious_patterns
    
    log_json "SECURITY" "INFO" "system" "audit_session_complete" \
        "Sesión de auditoría de seguridad completada exitosamente" \
        "{\"session_id\": \"$AUDIT_SESSION_ID\", \"duration\": \"$(date +%s)\"}"
    
    echo "# Security Audit Session Completed: $(date '+%Y-%m-%dT%H:%M:%S%z')" >> "$AUDIT_LOG"
    echo "" >> "$AUDIT_LOG"
    
    # Rotación de logs
    if [ -f "$AUDIT_LOG" ]; then
        LOG_SIZE=$(stat -f%z "$AUDIT_LOG" 2>/dev/null || echo 0)
        if [ "$LOG_SIZE" -gt 10485760 ]; then
            mv "$AUDIT_LOG" "${AUDIT_LOG}.$(date +%Y%m%d_%H%M%S)"
            touch "$AUDIT_LOG"
            chmod 640 "$AUDIT_LOG"
        fi
    fi
}

main
