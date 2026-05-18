-- ================================================================
-- Database initialization script
-- Creates both databases on first container start
-- ================================================================

CREATE DATABASE IF NOT EXISTS ventas_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS despachos_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Grant privileges to the application user
GRANT ALL PRIVILEGES ON ventas_db.* TO 'logistica_user'@'%';
GRANT ALL PRIVILEGES ON despachos_db.* TO 'logistica_user'@'%';
FLUSH PRIVILEGES;
