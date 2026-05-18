# Logística Andina – Plataforma de Gestión de Despachos

Monorepo de la plataforma Logística Andina (Innovatech Chile), conteniendo el frontend React, dos microservicios Spring Boot y la base de datos MySQL, orquestados con Docker Compose en una arquitectura de tres capas.

## Arquitectura

```
┌──────────────────────────────────────────────────┐
│              TIER 1 · PUBLIC (frontend-net)       │
│  ┌────────────────────────────────────────────┐   │
│  │  Frontend (Nginx + React)  ← Puerto 80    │   │
│  └──────────────┬─────────────────────────────┘   │
├─────────────────┼────────────────────────────────┤
│              TIER 2 · PRIVATE (backend-net)       │
│  ┌──────────────▼──────┐  ┌────────────────────┐ │
│  │  Ventas :8080       │  │  Despachos :8081   │ │
│  │  (Spring Boot)      │  │  (Spring Boot)     │ │
│  └──────────┬──────────┘  └────────┬───────────┘ │
├─────────────┼──────────────────────┼─────────────┤
│         TIER 3 · DATA (data-net, internal)       │
│  ┌──────────▼──────────────────────▼───────────┐ │
│  │             MySQL 8.0  :3306                │ │
│  │         Volume: mysql-data                  │ │
│  └─────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────┘
```

## Estructura del Monorepo

```
proyecto-semestral/
├── docker-compose.yml                              # Orquestación completa (3 tiers)
├── README.md                                       # Este archivo
├── init-db/
│   └── 01-create-databases.sql                     # Crea las BDs al primer arranque
├── front_despacho/                                 # TIER 1 – Frontend
│   ├── Dockerfile                                  #   Multi-stage: Node → Nginx
│   ├── nginx.conf                                  #   Reverse proxy + security headers
│   ├── docker-entrypoint.sh                        #   Inyección de env en runtime
│   ├── .dockerignore
│   ├── package.json
│   └── src/...
├── back-Ventas_SpringBoot/                         # TIER 2 – Ventas
│   └── Springboot-API-REST/
│       ├── Dockerfile                              #   Multi-stage: JDK → JRE
│       ├── .dockerignore
│       ├── pom.xml
│       └── src/...
└── back-Despachos_SpringBoot/                      # TIER 2 – Despachos
    └── Springboot-API-REST-DESPACHO/
        ├── Dockerfile                              #   Multi-stage: JDK → JRE
        ├── .dockerignore
        ├── pom.xml
        └── src/...
```

## Ejecución Local

```bash
# Levantar todo el stack
docker compose up -d --build

# Verificar estado
docker compose ps

# Ver logs en tiempo real
docker compose logs -f

# Acceso
# Frontend:           http://localhost
# Ventas Swagger:     http://localhost:8080/swagger-ui.html
# Despachos Swagger:  http://localhost:8081/swagger-ui.html

# Detener (preserva datos)
docker compose down

# Detener y borrar todos los datos
docker compose down -v
```

## Contenedorización

### Dockerfiles (Multi-stage)

Cada servicio utiliza un Dockerfile multi-stage:

| Servicio | Etapa Build | Etapa Producción | Puerto |
|----------|-------------|------------------|--------|
| **Frontend** | `node:20-alpine` (npm build) | `nginx:1.27-alpine` (sirve estáticos) | 8080 |
| **Ventas** | `eclipse-temurin:17-jdk-alpine` (Maven) | `eclipse-temurin:17-jre-alpine` | 8080 |
| **Despachos** | `eclipse-temurin:17-jdk-alpine` (Maven) | `eclipse-temurin:17-jre-alpine` | 8081 |

**Seguridad aplicada en todos los Dockerfiles:**
- Usuario no-root (`appuser`) — principio de mínimo privilegio
- Imágenes base Alpine (superficie de ataque reducida)
- Separación build/runtime (JDK no presente en producción)
- Extracción de JAR en capas (optimiza caché de Docker)

### Redes Docker

| Red | Tipo | Servicios Conectados | Propósito |
|-----|------|----------------------|-----------|
| `frontend-net` | bridge | Frontend | Acceso público (puerto 80) |
| `backend-net` | bridge | Frontend, Ventas, Despachos | Comunicación Front → Back |
| `data-net` | bridge, **internal** | Ventas, Despachos, MySQL | Aísla la BD del acceso externo |

> `data-net` está configurada como `internal: true`. MySQL **no es accesible** desde el frontend ni desde fuera de Docker. Esto replica el aislamiento de Security Groups en la subred privada de datos de AWS.

### Volúmenes (Persistencia)

| Volumen | Montaje | Datos que persiste |
|---------|---------|-------------------|
| `mysql-data` | `/var/lib/mysql` | Registros de las bases de datos |
| `ventas-logs` | `/app/logs` | Logs operacionales del servicio Ventas |
| `despachos-logs` | `/app/logs` | Logs operacionales del servicio Despachos |
| `frontend-cache` | `/var/cache/nginx` | Caché de Nginx |

**¿Por qué named volumes y no bind mounts?**
- Gestionados por Docker, no dependen de rutas del host
- Portables entre entornos (máquina local ↔ EC2)
- Sobreviven a `docker compose down` (solo se eliminan con `-v`)
- Mejor rendimiento de I/O para bases de datos en Linux

### Variables de Entorno

| Variable | Servicio | Default |
|----------|----------|---------|
| `FRONTEND_PORT` | Frontend | `80` |
| `VITE_VENTAS_API_URL` | Frontend | `http://ventas-service:8080` |
| `VITE_DESPACHOS_API_URL` | Frontend | `http://despachos-service:8081` |
| `DB_ENDPOINT` | Ventas, Despachos | `mysql-db` |
| `DB_PORT` | Ventas, Despachos | `3306` |
| `DB_USERNAME` | Ventas, Despachos, MySQL | `logistica_user` |
| `DB_PASSWORD` | Ventas, Despachos, MySQL | `logistica_secret` |
| `VENTAS_DB_NAME` | Ventas | `ventas_db` |
| `DESPACHOS_DB_NAME` | Despachos | `despachos_db` |
| `MYSQL_ROOT_PASSWORD` | MySQL | `rootsecret_change_me` |

## Despliegue en AWS EC2

Las imágenes se publican en **AWS ECR** y se despliegan en instancias EC2 dentro de una VPC de tres capas:

| Tier | Instancia EC2 | Subred | Contenedor(es) |
|------|---------------|--------|-----------------|
| Público | Frontend | `10.0.1.0/24` | Nginx + React SPA |
| Privado | Backend | `10.0.2.0/24` | Ventas + Despachos |
| Datos | Base de datos | `10.0.3.0/24` | MySQL 8.0 |

## Pipeline CI/CD

El workflow de GitHub Actions se activa al hacer **push en la rama `deploy`**:

1. **Build** → Construye las imágenes Docker multi-stage
2. **Push** → Publica en AWS ECR
3. **Deploy** → Actualiza los contenedores en las instancias EC2

El pipeline se configura desde la pestaña **Actions** en GitHub, utilizando **Secrets** para credenciales de AWS.
