#!/bin/sh
# /usr/local/scripts/recovery/test_failover.sh

echo "🧪 INICIANDO TEST DE FAILOVER..."

# 1. Insertar dato de prueba
echo "1. Insertando dato de prueba..."
PGPASSWORD=ulloa psql -h 141.148.83.27 -p 5433 -U postgres -d proyecto_bd -c "
INSERT INTO clientes (nombre, email, telefono) 
VALUES ('Test Failover', 'test@failover.com', '123-456-7890');"

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
