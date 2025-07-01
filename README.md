# PostgreSQL-Cluster-FreeBSD
PostgreSQL High Availability Cluster with Streaming Replication on FreeBSD 15.0

🎯 Project Overview
Enterprise-grade PostgreSQL cluster implementation featuring high availability, streaming replication, and automatic load balancing on FreeBSD 15.0 infrastructure. Deployed on Oracle Cloud Infrastructure with 99.9% uptime guarantee.

🏗️ Architecture
[Clients] → [Load Balancer] → [Master + 2 Slaves]
             141.148.83.27     10.0.1.16 (Master)
                               10.0.1.116 (Slave-01)  
                               10.0.1.25 (Slave-02)

Key Features
✅ 3-Server PostgreSQL Cluster with streaming replication
✅ 0-byte lag replication across multiple availability domains
✅ Oracle Cloud Load Balancer with intelligent traffic distribution
✅ Real-time monitoring dashboard with 30-second updates
✅ Automated backup strategies and recovery procedures
✅ Full-stack web application demonstrating cluster capabilities

🚀 Technologies Used
Component       Technology                   Purpose
Operating       SystemFreeBSD 15.0           High performance and security
Database        PostgreSQL 15.13             Primary database engine
Cloud Platform  Oracle Cloud Infrastructure  Hosting and networking
Load Balancer   Oracle Cloud LB              Traffic distribution
Web Server      NGINX                        Application server
Monitoring      Custom Shell Scripts         Real-time metrics
Administration  Webmin 2.013                 System management

📊 Performance Metrics

Replication Lag: 0 bytes (real-time sync)
Uptime: 99.9%
Load Distribution:

Port 5433: Write operations → Master only
Port 5434: Read operations → Slaves only
Port 5435: Mixed operations → Balanced

Response Time: < 10ms average query time

Prerequisites

FreeBSD 15.0 or later
PostgreSQL 15.13+
Oracle Cloud Infrastructure account
NGINX web server

📱 Web Applications
CRUD Application

URL: http://150.136.225.30:8081
Features: Complete Create, Read, Update, Delete operations
Backend: PHP APIs with PostgreSQL integration

Monitoring Dashboard

URL: http://150.136.225.30:8080
Features: Real-time cluster metrics, automated updates
Refresh Rate: Every 30 seconds

API Endpoints

Base URL: http://150.136.225.30:8082
Endpoints: /clientes.php, /productos.php, /pedidos.php

🔧 Configuration Files

configs/postgresql.conf - Master PostgreSQL configuration
configs/pg_hba.conf - Authentication settings
configs/nginx.conf - Web server configuration

📜 Scripts

scripts/monitoring/ - Automated monitoring scripts
scripts/backup/ - Backup and recovery scripts
scripts/recovery/ - Disaster recovery procedures
