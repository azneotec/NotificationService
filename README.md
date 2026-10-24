# NotificationService

Sends the emails other services ask for. It has no REST API: it consumes Kafka messages and delivers each one as an email.

## Kafka

| Topic | Producer | Email |
|---|---|---|
| `signup` | UserAuthService | welcome |
| `password-reset` | UserAuthService | reset link |
| `order-notification` | OrderManagementService, PaymentService | order confirmation, delivery updates, payment receipt |

The producer decides the recipient, subject and body (`{"to","from","subject","body"}`); this service only delivers it, through Gmail SMTP using `from` as the login. The topics are created by the root `docker-compose.yml`. Both instances share the consumer group `emailService`; the topics have one partition each, so one instance does the work and the other takes over if it stops.

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `GMAIL_PASSWORD` | empty | App password of the sender; sending fails without it |
| `SERVER_PORT` | `8006` | Use `9006` for the second instance |
| `SPRING_KAFKA_BOOTSTRAP_SERVERS` | `localhost:9092` | Kafka broker |
| `EUREKA_CLIENT_ENABLED` | `true` | `false` runs without a registry |
| `EUREKA_CLIENT_SERVICEURL_DEFAULTZONE` | `http://localhost:8761/eureka/` | Eureka server |

For `./mvnw spring-boot:run` or `java -jar`, copy `.env.example` to `.env` (gitignored); real environment variables win over it.

## Running

From the repository root, with `make infra-up` and `make eureka` done:

```bash
make notification GMAIL_PASSWORD=...   # :8006 and :9006, both registered as notification-service
make notification-1 GMAIL_PASSWORD=... # just one instance (notification-2 for :9006)
```

### Standalone

This directory's `Makefile` runs the service on its own (`make help` lists the targets): `make up` starts Kafka from `docker-compose.yml` and runs the app on :8006 with `.env` loaded, `SERVER_PORT=9006 make run` starts a second instance, and `make docker-run` builds and runs the image. Don't use `make infra-up` while the root stack is up: both bind Kafka's 9092.

### Bruno collection

`bruno/` holds a [Bruno](https://www.usebruno.com) collection (open the folder in Bruno; environments `Local` for :8006 and `Local-9006` for :9006). The service has no API beyond `/actuator/health`, so besides **Health** and the **Eureka** registration check, the **Emails** requests publish `signup`, `password-reset` and `order-notification` messages through Kafka UI (`http://localhost:8090`) and the service emails them. Set `recipient` in the environment to a mailbox you own: those requests send real mail.

### Run in Docker

The `Dockerfile` builds and runs only this service; Kafka and Eureka stay outside. `localhost` inside the container is the container itself, so override the addresses (`host.docker.internal` reaches services published on the host):

```bash
docker build -t notification-service .
docker run --rm -p 8006:8006 -e GMAIL_PASSWORD=... \
  -e SPRING_KAFKA_BOOTSTRAP_SERVERS=host.docker.internal:9092 \
  -e EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://host.docker.internal:8761/eureka/ notification-service
```

The broker advertises itself as `localhost:9092`, which a container cannot reach, so the container needs a broker that also advertises a name it can use. The image carries no `.env`, runs as a non-root user and has a health check on `/actuator/health`.
