<?php
header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

// Configuración del Load Balancer
$loadbalancer_ip = '141.148.83.27';
$write_port = '5433';  // Escrituras al Master
$read_port = '5434';   // Lecturas de Slaves
$db_name = 'proyecto_bd';
$username = 'postgres';
$password = 'ulloa';

$method = $_SERVER['REQUEST_METHOD'];

try {
    if ($method === 'GET') {
        // LECTURA - Usar slaves (puerto 5434)
        $dsn = "pgsql:host=$loadbalancer_ip;port=$read_port;dbname=$db_name";
        $conn = new PDO($dsn, $username, $password);
        
        $stmt = $conn->query("SELECT cliente_id as id, nombre, email FROM clientes ORDER BY cliente_id");
        $clientes = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo json_encode([
            'status' => 'success',
            'data' => $clientes,
            'server_info' => [
                'port' => $read_port,
                'operation' => 'READ from slaves'
            ]
        ]);
        
    } elseif ($method === 'POST') {
        // ESCRITURA - Usar master (puerto 5433)
        $dsn = "pgsql:host=$loadbalancer_ip;port=$write_port;dbname=$db_name";
        $conn = new PDO($dsn, $username, $password);
        
        $input = json_decode(file_get_contents('php://input'), true);
        $action = $input['action'] ?? 'create';
        
        if ($action === 'delete') {
            // ELIMINAR CLIENTE
            $cliente_id = $input['id'] ?? '';
            if (empty($cliente_id)) {
                throw new Exception('ID de cliente requerido');
            }
            
            $stmt = $conn->prepare("DELETE FROM clientes WHERE cliente_id = ?");
            $stmt->execute([$cliente_id]);
            
            echo json_encode([
                'status' => 'success',
                'message' => 'Cliente eliminado exitosamente',
                'server_info' => [
                    'port' => $write_port,
                    'operation' => 'DELETE from master'
                ]
            ]);
            
        } else {
            // CREAR CLIENTE (action = 'create' o por defecto)
            $nombre = $input['nombre'] ?? '';
            $email = $input['email'] ?? '';
            
            if (empty($nombre) || empty($email)) {
                throw new Exception('Nombre y email son requeridos');
            }
            
            $stmt = $conn->prepare("INSERT INTO clientes (nombre, email) VALUES (?, ?) RETURNING cliente_id, nombre, email");
            $stmt->execute([$nombre, $email]);
            $cliente = $stmt->fetch(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'status' => 'success',
                'data' => $cliente,
                'message' => 'Cliente creado exitosamente',
                'server_info' => [
                    'port' => $write_port,
                    'operation' => 'WRITE to master'
                ]
            ]);
        }
        
    } elseif ($method === 'DELETE') {
        // ESCRITURA - Usar master (puerto 5433)
        $dsn = "pgsql:host=$loadbalancer_ip;port=$write_port;dbname=$db_name";
        $conn = new PDO($dsn, $username, $password);
        
        $cliente_id = $_GET['id'] ?? '';
        if (empty($cliente_id)) {
            throw new Exception('ID de cliente requerido');
        }
        
        $stmt = $conn->prepare("DELETE FROM clientes WHERE cliente_id = ?");
        $stmt->execute([$cliente_id]);
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Cliente eliminado exitosamente',
            'server_info' => [
                'port' => $write_port,
                'operation' => 'DELETE from master'
            ]
        ]);
    }
    
} catch (Exception $e) {
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
