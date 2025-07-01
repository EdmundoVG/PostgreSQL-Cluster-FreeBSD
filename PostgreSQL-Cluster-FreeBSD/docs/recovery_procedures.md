# 🛠️ PROCEDIMIENTOS DE RECUPERACIÓN - CLUSTER POSTGRESQL

## 📊 INFORMACIÓN DEL CLUSTER

**Servidores:**
- 👑 **Master**: `10.0.1.16` (150.136.225.30)
- 🔄 **Slave-01**: `10.0.1.116` (150.136.208.220)
- 🔄 **Slave-02**: `10.0.1.25` (150.136.172.211)

**Load Balancer:** `141.148.83.27`
- Puerto 5433: Writes (solo master)
- Puerto 5434: Reads (solo slaves)

---

## 🚨 ESCENARIOS DE RECUPERACIÓN

### **ESCENARIO 1: Fallo del Master**

#### **Detección:**
```bash
# Verificar si master responde
PGPASSWORD=ulloa pg_isready -h 10.0.1.16 -p 5432 -U postgres -d proyecto_bd
```

#### **Promoción Manual de Slave:**
```bash
# 1. Conectar al slave con menor lag
ssh -i "/path/to/key" freebsd@[SLAVE_IP]

# 2. Promover a master
sudo -u postgres pg_ctl promote -D /var/db/postgres/data15

# 3. Verificar promoción
PGPASSWORD=ulloa psql -U postgres -d proyecto_bd -c "SELECT pg_is_in_recovery();"
```

#### **Tiempo de Recuperación:** 2-5 minutos

---

### **ESCENARIO 2: Fallo de Slave**

#### **Detección:**
```bash
# En master - verificar slaves conectados
PGPASSWORD=ulloa psql -d proyecto_bd -c "SELECT * FROM pg_stat_replication;"
```

#### **Recuperación:**
```bash
# 1. Reiniciar servicio en slave
ssh -i "/path/to/key" freebsd@[SLAVE_IP]
sudo service postgresql restart

# 2. Verificar reconexión
PGPASSWORD=ulloa psql -U postgres -d proyecto_bd -c "SELECT status FROM pg_stat_wal_receiver;"
```

#### **Tiempo de Recuperación:** 1-2 minutos

---

### **ESCENARIO 3: Corrupción de Datos**

#### **Restauración desde Backup:**
```bash
# 1. Detener PostgreSQL
sudo service postgresql stop

# 2. Restaurar desde backup más reciente
sudo -u postgres pg_restore -d proyecto_bd /var/backups/postgresql/backup_completo_[FECHA].sql

# 3. Aplicar WAL logs si es necesario
sudo -u postgres pg_resetwal /var/db/postgres/data15

# 4. Reiniciar servicio
sudo service postgresql start
```

#### **Tiempo de Recuperación:** 10-30 minutos

---

### **ESCENARIO 4: Pérdida Total del Cluster**

#### **Reconstrucción Completa:**
```bash
# 1. Restaurar master desde backup
sudo -u postgres pg_restore -C -d postgres /var/backups/postgresql/backup_completo_[FECHA].sql

# 2. Reconfigurar slaves (en cada slave)
sudo service postgresql stop
sudo rm -rf /var/db/postgres/data15/*
sudo -u postgres pg_basebackup -h [NEW_MASTER_IP] -D /var/db/postgres/data15 -U replicator -v -P
sudo service postgresql start
```

#### **Tiempo de Recuperación:** 30-60 minutos

---

## 🔍 SCRIPTS DE VERIFICACIÓN

### **Estado General del Cluster:**
```bash
#!/bin/sh
# /usr/local/scripts/recovery/check_cluster_status.sh

echo "=== ESTADO DEL CLUSTER POSTGRESQL ==="
echo "Fecha: $(date)"
echo

# Verificar Master
echo "🔍 MASTER (10.0.1.16):"
if PGPASSWORD=ulloa pg_isready -h 10.0.1.16 -p 5432 -U postgres -d proyecto_bd >/dev/null 2>&1; then
    echo "✅ ONLINE"
    PGPASSWORD=ulloa psql -h 10.0.1.16 -U postgres -d proyecto_bd -t -c "SELECT '   Slaves conectados: ' || count(*) FROM pg_stat_replication;"
else
    echo "❌ OFFLINE"
fi

# Verificar Slaves
echo
echo "🔍 SLAVES:"
for ip in "10.0.1.116" "10.0.1.25"; do
    echo "Slave ($ip):"
    if PGPASSWORD=ulloa pg_isready -h $ip -p 5432 -U postgres -d proyecto_bd >/dev/null 2>&1; then
        echo "✅ ONLINE"
        recovery_status=$(PGPASSWORD=ulloa psql -h $ip -U postgres -d proyecto_bd -t -c "SELECT pg_is_in_recovery();" 2>/dev/null | tr -d ' ')
        if [ "$recovery_status" = "t" ]; then
            echo "   📡 En modo replicación"
        else
            echo "   ⚠️ NO está en recovery mode"
        fi
    else
        echo "❌ OFFLINE"
    fi
done

# Verificar Load Balancer
echo
echo "🔍 LOAD BALANCER (141.148.83.27):"
if PGPASSWORD=ulloa pg_isready -h 141.148.83.27 -p 5433 -U postgres -d proyecto_bd >/dev/null 2>&1; then
    echo "✅ ONLINE"
else
    echo "❌ OFFLINE"
fi

echo
echo "=== FIN DEL REPORTE ==="
```

### **Test de Failover Manual:**
```bash
#!/bin/sh
# /usr/local/scripts/recovery/test_failover.sh

echo "🧪 INICIANDO TEST DE FAILOVER..."

# 1. Insertar dato de prueba
echo "1. Insertando dato de prueba..."
PGPASSWORD=ulloa psql -h 141.148.83.27 -p 5433 -U postgres -d proyecto_bd -c "
INSERT INTO clientes (nombre, email) 
VALUES ('Test Failover', 'test@failover.com');"

# 2. Simular fallo del master (solo mostrar comando)
echo "2. Para simular fallo del master, ejecutar:"
echo "   ssh freebsd@150.136.225.30 'sudo service postgresql stop'"

# 3. Verificar que slaves detectan el fallo
echo "3. Verificando slaves..."
for ip in "10.0.1.116" "10.0.1.25"; do
    echo "Verificando slave $ip..."
    PGPASSWORD=ulloa psql -h $ip -U postgres -d proyecto_bd -c "SELECT COUNT(*) FROM clientes WHERE email='test@failover.com';"
done

echo "✅ Test completado"
```

---

## 📋 CHECKLIST DE RECUPERACIÓN

### **Pre-Failover:**
- [ ] Identificar causa del fallo
- [ ] Verificar estado de slaves
- [ ] Seleccionar slave con menor lag
- [ ] Notificar al equipo

### **Durante Failover:**
- [ ] Promover slave seleccionado
- [ ] Verificar que acepta conexiones
- [ ] Reconfigurar aplicaciones
- [ ] Actualizar DNS/Load Balancer

### **Post-Failover:**
- [ ] Verificar integridad de datos
- [ ] Monitorear rendimiento
- [ ] Documentar incidente
- [ ] Planificar recuperación del master original

---

## 📊 TIEMPOS DE RECUPERACIÓN (RTO/RPO)

| Escenario | RTO (Recovery Time) | RPO (Data Loss) |
|-----------|--------------------|-----------------|
| Fallo Master | 2-5 minutos | < 1 minuto |
| Fallo Slave | 1-2 minutos | 0 segundos |
| Corrupción | 10-30 minutos | < 1 hora |
| Pérdida Total | 30-60 minutos | < 24 horas |

---

## 🎯 CONTACTOS DE EMERGENCIA

- **Administrador Principal:** [Tu nombre]
- **Respaldo:** [Nombre del respaldo]
- **Escalamiento:** [Manager/Supervisor]

---

## 📝 REGISTRO DE INCIDENTES

| Fecha | Tipo | Duración | Causa | Solución |
|-------|------|----------|-------|----------|
| | | | | |

---

## 🔧 COMANDOS ÚTILES DE DIAGNÓSTICO

### **Verificar Replicación:**
```bash
# En master - ver lag de slaves
SELECT application_name, client_addr, state, 
       pg_wal_lsn_diff(pg_current_wal_lsn(), flush_lsn) AS lag_bytes
FROM pg_stat_replication;

# En slave - ver última transacción replicada
SELECT pg_last_wal_receive_lsn(), pg_last_wal_replay_lsn(), 
       pg_last_xact_replay_timestamp();
```

### **Verificar Conectividad:**
```bash
# Test de conexión básica
pg_isready -h [IP] -p 5432 -U postgres

# Test con timeout
timeout 5 pg_isready -h [IP] -p 5432 -U postgres
```

### **Verificar Load Balancer:**
```bash
# Puerto writes (solo master)
PGPASSWORD=ulloa psql -h 141.148.83.27 -p 5433 -U postgres -d proyecto_bd -c "SELECT inet_server_addr();"

# Puerto reads (solo slaves)
PGPASSWORD=ulloa psql -h 141.148.83.27 -p 5434 -U postgres -d proyecto_bd -c "SELECT inet_server_addr();"
```

---

## 🚨 PROCEDIMIENTOS DE EMERGENCIA

### **Si todos los servidores fallan:**
1. **No entrar en pánico**
2. **Verificar infraestructura de red**
3. **Revisar Oracle Cloud Console**
4. **Contactar soporte de Oracle Cloud**
5. **Activar plan de recuperación total**

### **Si la replicación se rompe:**
1. **Verificar conectividad de red**
2. **Revisar logs de PostgreSQL**
3. **Reiniciar replicación desde pg_basebackup**
4. **Monitorear lag después de reconexión**

### **Si Load Balancer falla:**
1. **Conectar aplicaciones directamente al master**
2. **Verificar Security Lists en Oracle Cloud**
3. **Revisar configuración de backend sets**
4. **Contactar soporte si es necesario**

---

**Última actualización:** $(date)  
**Versión:** 1.0  
**Estado:** ACTIVO
