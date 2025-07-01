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
        
        $stmt = $conn->query("SELECT producto_id as id, nombre, precio FROM productos ORDER BY producto_id");
        $productos = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        echo json_encode([
            'status' => 'success',
            'data' => $productos,
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
        
        if ($action === 'update') {
            // ACTUALIZAR PRECIO DE PRODUCTO
            $producto_id = $input['id'] ?? '';
            $nuevo_precio = $input['precio'] ?? '';
            
            if (empty($producto_id) || empty($nuevo_precio)) {
                throw new Exception('ID de producto y nuevo precio son requeridos');
            }
            
            $stmt = $conn->prepare("UPDATE productos SET precio = ? WHERE producto_id = ? RETURNING producto_id, nombre, precio");
            $stmt->execute([$nuevo_precio, $producto_id]);
            $producto = $stmt->fetch(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'status' => 'success',
                'message' => 'Precio actualizado exitosamente',
                'data' => $producto,
                'server_info' => [
                    'port' => $write_port,
                    'operation' => 'UPDATE to master'
                ]
            ]);
            
        } elseif ($action === 'delete') {
            // ELIMINAR PRODUCTO
            $producto_id = $input['id'] ?? '';
            if (empty($producto_id)) {
                throw new Exception('ID de producto requerido');
            }
            
            $stmt = $conn->prepare("DELETE FROM productos WHERE producto_id = ?");
            $stmt->execute([$producto_id]);
            
            echo json_encode([
                'status' => 'success',
                'message' => 'Producto eliminado exitosamente',
                'server_info' => [
                    'port' => $write_port,
                    'operation' => 'DELETE from master'
                ]
            ]);
            
        } else {
            // CREAR PRODUCTO (action = 'create' o por defecto)
            $nombre = $input['nombre'] ?? '';
            $precio = $input['precio'] ?? '';
            
            if (empty($nombre) || empty($precio)) {
                throw new Exception('Nombre y precio son requeridos');
            }
            
            $stmt = $conn->prepare("INSERT INTO productos (nombre, precio) VALUES (?, ?) RETURNING producto_id, nombre, precio");
            $stmt->execute([$nombre, $precio]);
            $producto = $stmt->fetch(PDO::FETCH_ASSOC);
            
            echo json_encode([
                'status' => 'success',
                'data' => $producto,
                'message' => 'Producto creado exitosamente',
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
        
        $producto_id = $_GET['id'] ?? '';
        if (empty($producto_id)) {
            throw new Exception('ID de producto requerido');
        }
        
        $stmt = $conn->prepare("DELETE FROM productos WHERE producto_id = ?");
        $stmt->execute([$producto_id]);
        
        echo json_encode([
            'status' => 'success',
            'message' => 'Producto eliminado exitosamente',
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
