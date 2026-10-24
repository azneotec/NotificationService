# Builds and runs only NotificationService. Kafka and Eureka are not included: point the container at them
# with environment variables (see README, "Run in Docker").
#
#   docker build -t notification-service .
#   docker run --rm -p 8006:8006 -e GMAIL_PASSWORD=... \
#       -e SPRING_KAFKA_BOOTSTRAP_SERVERS=host.docker.internal:9092 \
#       -e EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://host.docker.internal:8761/eureka/ notification-service

# --- build stage: compile the jar; dependencies are cached in their own layer, so a source-only change is fast
FROM eclipse-temurin:17-jdk AS build
WORKDIR /build
COPY .mvn .mvn
COPY mvnw pom.xml ./
RUN ./mvnw -q -B dependency:go-offline
COPY src src
RUN ./mvnw -q -B package -DskipTests

# --- runtime stage: JRE only, non-root
FROM eclipse-temurin:17-jre
RUN groupadd --system app && useradd --system --gid app --no-create-home app
WORKDIR /app
COPY --from=build /build/target/NotificationService-0.0.1-SNAPSHOT.jar app.jar
USER app

# Everything is configured through environment variables; localhost inside a container is the container itself,
# so the Kafka and Eureka addresses must be overridden. No .env is baked in (see .dockerignore).
#   GMAIL_PASSWORD (required to send)                  app password of the sender
#   SPRING_KAFKA_BOOTSTRAP_SERVERS                     default localhost:9092
#   EUREKA_CLIENT_SERVICEURL_DEFAULTZONE               default http://localhost:8761/eureka/
#   EUREKA_CLIENT_ENABLED=false                        run without a registry
#   SERVER_PORT                                        default 8006 (change EXPOSE and the port mapping with it)
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75"
EXPOSE 8006

HEALTHCHECK --interval=15s --timeout=3s --start-period=60s --retries=5 \
  CMD curl -fs http://localhost:${SERVER_PORT:-8006}/actuator/health | grep -q '"UP"' || exit 1

ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
