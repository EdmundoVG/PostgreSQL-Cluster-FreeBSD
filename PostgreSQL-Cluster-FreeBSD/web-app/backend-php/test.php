<?php
header('Content-Type: application/json');

// Configuración del Load Balancer
$loadbalancer_ip = '141.148.83.27';
$write_port = '5433';  // Escrituras al Master
$read_port = '5434';   // Lecturas de Slaves
$mixed_port = '5435';  // Mixto con balanceo

// Información de conexión
$db_name = 'proyecto_bd';
$username = 'postgres';
$password = 'ulloa';

try {
    // Test conexión WRITE (Master)
    $write_dsn = "pgsql:host=$loadbalancer_ip;port=$write_port;dbname=$db_name";
    $write_conn = new PDO($write_dsn, $username, $password);
    $write_result = $write_conn->query("SELECT 'WRITE OK', inet_server_addr(), pg_is_in_recovery()")->fetch();
    
    // Test conexión READ (Slaves)
    $read_dsn = "pgsql:host=$loadbalancer_ip;port=$read_port;dbname=$db_name";
    $read_conn = new PDO($read_dsn, $username, $password);
    $read_result = $read_conn->query("SELECT 'READ OK', inet_server_addr(), pg_is_in_recovery()")->fetch();
    
    echo json_encode([
        'status' => 'success',
        'message' => 'Conexión al cluster PostgreSQL exitosa',
        'load_balancer' => $loadbalancer_ip,
        'write_test' => [
            'port' => $write_port,
            'server' => $write_result[1],
            'is_slave' => $write_result[2] === 't' ? true : false
        ],
        'read_test' => [
            'port' => $read_port, 
            'server' => $read_result[1],
            'is_slave' => $read_result[2] === 't' ? true : false
        ],
        'timestamp' => date('Y-m-d H:i:s')
    ]);

} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s')
    ]);
}
?>
