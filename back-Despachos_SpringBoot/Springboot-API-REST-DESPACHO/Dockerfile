# ============================================================
# Stage 1 – Build the Spring Boot application with Maven
# ============================================================
FROM eclipse-temurin:17-jdk-alpine AS builder

WORKDIR /build

# Copy Maven wrapper and POM first for dependency caching
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw

# Download dependencies (cached layer)
RUN ./mvnw dependency:go-offline -B

# Copy source code and build
COPY src/ src/
RUN ./mvnw clean package -DskipTests -B && \
    # Extract layered JAR for optimized Docker layers
    java -Djarmode=layertools -jar target/*.jar extract --destination /extracted

# ============================================================
# Stage 2 – Minimal runtime image (non-root)
# ============================================================
FROM eclipse-temurin:17-jre-alpine AS production

# Security: create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy extracted layers for better caching
COPY --from=builder /extracted/dependencies/ ./
COPY --from=builder /extracted/spring-boot-loader/ ./
COPY --from=builder /extracted/snapshot-dependencies/ ./
COPY --from=builder /extracted/application/ ./

# Security: ensure non-root ownership
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose service port
EXPOSE 8081

# JVM tuning for containers
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Djava.security.egd=file:/dev/./urandom"

# Healthcheck via Spring Boot Actuator (or basic TCP)
HEALTHCHECK --interval=30s --timeout=5s --start-period=40s --retries=3 \
  CMD wget -qO- http://localhost:8081/swagger-ui.html || exit 1

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS org.springframework.boot.loader.launch.JarLauncher"]
