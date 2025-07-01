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
