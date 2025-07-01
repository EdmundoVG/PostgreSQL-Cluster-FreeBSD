# 🚨 RESUMEN DE ACCIONES POR TIPO DE FALLO

## **CASO 1: FALLO DEL MASTER** ⚠️

### **¿Cómo detectar?**
```bash
PGPASSWORD=ulloa pg_isready -h 10.0.1.16 -p 5432 -U postgres -d proyecto_bd
# Si retorna error = Master caído
```

### **¿Qué hacer?**
1. **Elegir slave** con menor lag (generalmente 10.0.1.116)
2. **Conectarse al slave elegido:**
   ```bash
   ssh -i "/path/to/key" freebsd@10.0.1.116
   ```
3. **Promover a master:**
   ```bash
   sudo -u postgres pg_ctl promote -D /var/db/postgres/data15
   ```
4. **Verificar promoción:**
   ```bash
   PGPASSWORD=ulloa psql -U postgres -d proyecto_bd -c "SELECT pg_is_in_recovery();"
   # Debe retornar: f (false = ya es master)
   ```
5. **Reconfigurar aplicaciones** para apuntar al nuevo master

**⏱️ Tiempo:** 2-5 minutos | **📊 Pérdida:** < 1 minuto de datos

---

## **CASO 2: FALLO DE UN SLAVE** 🔄

### **¿Cómo detectar?**
```bash
PGPASSWORD=ulloa psql -h 10.0.1.16 -d proyecto_bd -c "SELECT * FROM pg_stat_replication;"
# Si muestra solo 1 slave en lugar de 2 = Hay un slave caído
```

### **¿Qué hacer?**
1. **Identificar cuál slave falló** (10.0.1.116 o 10.0.1.25)
2. **Conectarse al slave problemático:**
   ```bash
   ssh -i "/path/to/key" freebsd@[SLAVE_IP]
   ```
3. **Reiniciar PostgreSQL:**
   ```bash
   sudo service postgresql restart
   ```
4. **Verificar reconexión:**
   ```bash
   PGPASSWORD=ulloa psql -U postgres -d proyecto_bd -c "SELECT status FROM pg_stat_wal_receiver;"
   # Debe mostrar: streaming
   ```

**⏱️ Tiempo:** 1-2 minutos | **📊 Pérdida:** 0 segundos

---

## **CASO 3: CORRUPCIÓN DE DATOS** 💾

### **¿Cómo detectar?**
- Errores en consultas SQL
- PostgreSQL no inicia
- Mensajes de corrupción en logs

### **¿Qué hacer?**
1. **Detener PostgreSQL:**
   ```bash
   sudo service postgresql stop
   ```
2. **Restaurar desde backup:**
   ```bash
   sudo -u postgres pg_restore -d proyecto_bd /var/backups/postgresql/backup_completo_[FECHA].sql
   ```
3. **Resetear WAL logs:**
   ```bash
   sudo -u postgres pg_resetwal /var/db/postgres/data15
   ```
4. **Reiniciar servicio:**
   ```bash
   sudo service postgresql start
   ```

**⏱️ Tiempo:** 10-30 minutos | **📊 Pérdida:** < 1 hora de datos

---

## **CASO 4: PÉRDIDA TOTAL DEL CLUSTER** 🚨

### **¿Cuándo pasa?**
- Fallan todos los servidores
- Problema de infraestructura Oracle Cloud
- Corrupción masiva

### **¿Qué hacer?**
1. **Restaurar master desde backup:**
   ```bash
   sudo -u postgres pg_restore -C -d postgres /var/backups/postgresql/backup_completo_[FECHA].sql
   ```
2. **En cada slave, reconstruir desde cero:**
   ```bash
   sudo service postgresql stop
   sudo rm -rf /var/db/postgres/data15/*
   sudo -u postgres pg_basebackup -h [NEW_MASTER_IP] -D /var/db/postgres/data15 -U replicator -v -P
   sudo service postgresql start
   ```

**⏱️ Tiempo:** 30-60 minutos | **📊 Pérdida:** < 24 horas

---

## 🎯 **ORDEN DE PRIORIDAD DE ACCIONES**

### **INMEDIATO (0-5 minutos):**
1. 🔍 **Identificar** qué falló específicamente
2. 🚨 **Notificar** al equipo del problema
3. 🔧 **Aplicar** la solución del caso correspondiente

### **CORTO PLAZO (5-30 minutos):**
1. ✅ **Verificar** que la solución funciona
2. 📊 **Monitorear** el rendimiento del sistema
3. 📝 **Documentar** el incidente

### **MEDIANO PLAZO (30+ minutos):**
1. 🔍 **Investigar** la causa raíz del fallo
2. 🛠️ **Planificar** reparación del componente original
3. 🔄 **Restaurar** configuración completa si es necesario

---

## 🚀 **COMANDOS DE VERIFICACIÓN RÁPIDA**

### **Estado general:**
```bash
/usr/local/scripts/recovery/check_cluster_status.sh
```

### **Test básico:**
```bash
# Insertar dato
PGPASSWORD=ulloa psql -h 141.148.83.27 -p 5433 -U postgres -d proyecto_bd -c "INSERT INTO clientes (nombre, email) VALUES ('Test $(date +%H%M)', 'test@now.com');"

# Verificar en slaves
PGPASSWORD=ulloa psql -h 10.0.1.116 -U postgres -d proyecto_bd -c "SELECT * FROM clientes WHERE email LIKE 'test@%';"
```

## 📋 **REGLA DE ORO:**
**🔥 En caso de duda: Siempre ejecutar primero el script de verificación antes de tomar acciones drásticas**

```bash
/usr/local/scripts/recovery/check_cluster_status.sh
```

**Este resumen te permite actuar rápidamente en cualquier escenario de fallo.**
