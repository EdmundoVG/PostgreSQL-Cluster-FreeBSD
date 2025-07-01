#!/bin/sh

# ==========================================
# RECOLECTOR DE MÉTRICAS DE SLAVES
# ==========================================

MASTER_LOG="/var/log/postgres_metrics.log"

# Recolectar métricas del slave-01
sudo -u freebsd ssh -o StrictHostKeyChecking=no freebsd@10.0.1.116 "tail -1 /var/log/postgres_metrics.log" >> $MASTER_LOG 2>/dev/null

# Recolectar métricas del slave-02
sudo -u freebsd ssh -o StrictHostKeyChecking=no freebsd@10.0.1.25 "tail -1 /var/log/postgres_metrics.log" >> $MASTER_LOG 2>/dev/null

echo "Métricas de slaves recolectadas"
