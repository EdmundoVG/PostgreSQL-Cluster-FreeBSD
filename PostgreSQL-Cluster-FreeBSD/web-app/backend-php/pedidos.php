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
        
        $stmt = $conn->query("
            SELECT 
                p.pedido_id as id,
                c.nombre as cliente,
                pr.nombre as producto,
                pr.precio,
                p.fecha_pedido as fecha
            FROM pedidos p
            JOIN clientes c ON p.cliente_id = c.cliente_id
            JOIN productos pr ON p.producto_id = pr.producto_id
            ORDER BY p.pedido_id
        ");
        $pedidos = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo json_encode([
            'status' => 'success',
            'data' => $pedidos,
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
            // ELIMINAR PEDIDO
            $pedido_id = $input['id'] ?? '';
            if (empty($pedido_id)) {
                throw new Exception('ID de pedido requerido');
            }
            
            $stmt = $conn->prepare("DELETE FROM pedidos WHERE pedido_id = ?");
            $stmt->execute([$pedido_id]);
            
            echo json_encode([
                'status' => 'success',
                'message' => 'Pedido eliminado exitosamente',
                'server_info' => [
                    'port' => $write_port,
                    'operation' => 'DELETE from master'
                ]
            ]);
            
        } else {
            // CREAR PEDIDO (action = 'create' o por defecto)
            $cliente_id = $input['cliente_id'] ?? '';
            $producto_id = $input['producto_id'] ?? '';
            
            if (empty($cliente_id) || empty($producto_id)) {
                throw new Exception('Cliente ID y Producto ID son requeridos');
            }
            
            $stmt = $conn->prepare("INSERT INTO pedidos (cliente_id, producto_id, fecha_pedido) VALUES (?, ?, NOW()) RETURNING pedido_id, cliente_id, producto_id, fecha_pedido");
            $stmt->execute([$cliente_id, $producto_id]);
            $pedido = $stmt->fetch(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'status' => 'success',
                'data' => $pedido,
                'message' => 'Pedido creado exitosamente',
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
        
        $pedido_id = $_GET['id'] ?? '';
        if (empty($pedido_id)) {
            throw new Exception('ID de pedido requerido');
        }
        
        $stmt = $conn->prepare("DELETE FROM pedidos WHERE pedido_id = ?");
        $stmt->execute([$pedido_id]);
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Pedido eliminado exitosamente',
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
