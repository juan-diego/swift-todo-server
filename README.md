# Todo Server

A Swift 6 REST API for managing todos, built with Hummingbird 2. This project explores what it takes to build and run a Swift backend on Google Cloud with a production-ready, cloud-native approach.

## Overview

- Motivation: learn Swift in depth and validate Swift as a practical backend language on Google Cloud. The project began as the Hummingbird Todos tutorial and evolved into a real deployment experiment with Cloud Run and Firestore.
- Swift 6 concurrency with `async`/`await` and actors.
- Pluggable persistence backends (in-memory, Firestore, Firestore emulator).
- JWT-based authentication for protected routes.
- Typed error handling and documented APIs.
- Container-first deployment targets (Google Cloud Run).

## Motivation

This project started as the official Hummingbird Todos tutorial and kept the name `todo-server` as a small nod to its origin and a practical choice. The original goal was simple: learn Swift by building something real, then see how far it could go in production-like infrastructure.

I have been deploying Java applications to Google App Engine since its early days because it is simple, inexpensive, and frees you from managing infrastructure. App Engine does not support Swift natively, so Cloud Run was the obvious alternative. It turned out to be just as straightforward and cost-effective. From there, I replaced the tutorial’s in-memory persistence with Google Firestore to test a managed database in a Swift backend.

The result is this project: a focused, open-source experiment that connects Swift, Cloud Run, and Firestore in a practical service.

## AI Disclosure

AI tooling was used to help draft documentation and SwiftDoc comments, and it assisted with some coding tasks. The project structure is my own, I wrote most of the code, and I reviewed every line of code.

## Architecture

### Repository Pattern

The application exposes a common `TodoRepository` interface with three implementations.

- Volatile (in-memory) for development and tests.
- Persistent Firestore for production.
- Firestore emulator for local development.

### Authentication

Authentication is a two-step flow.

1. `POST /user` with Basic Auth to obtain a JWT.
2. Use `Authorization: Bearer <token>` for `/todos` routes.

### Concurrency

- Actor-backed repositories for thread safety.
- `@Sendable` route handlers.
- `async`/`await` for I/O and network calls.

## API Documentation

The OpenAPI specification is in `openapi.yaml`.

## Firestore Configuration

### Collection Structure

- Collection: `todos`
- Document fields: `ownerId`, `order`, and todo fields.

### Required Composite Index

For ordered, owner-scoped queries, create this composite index.

- Collection ID: `todos`
- Fields (in order): `ownerId` (Ascending), `order` (Ascending), `__name__` (Ascending)
- Query scope: Collection

### Create the Index

Use one of the options below.

#### Firebase Console

1. Open the Firebase Console and select your project.
2. Firestore Database → Indexes → Composite Indexes.
3. Create an index with fields: `ownerId` (Ascending), `order` (Ascending), `__name__` (Ascending).

#### `firestore.indexes.json`

```json
{
  "indexes": [
    {
      "collectionGroup": "todos",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "ownerId", "order": "ASCENDING" },
        { "fieldPath": "order", "order": "ASCENDING" },
        { "fieldPath": "__name__", "order": "ASCENDING" }
      ]
    }
  ]
}
```

```bash
firebase deploy --only firestore:indexes
```

#### gcloud CLI

```bash
gcloud firestore indexes composite create \
  --collection-group=todos \
  --query-scope=COLLECTION \
  --field-config=field-path=ownerId,order=ascending \
  --field-config=field-path=order,order=ascending \
  --field-config=field-path=__name__,order=ascending
```

### Index Build Time

Index creation is asynchronous. Monitor progress in the Firebase Console under Indexes.

## Deploying to Google Cloud Run

### Deploy a Service

```bash
SERVICE="YOUR_CLOUD_RUN_SERVICE"
DOCKER_IMAGE="YOUR_TODO_SERVER_IMAGE"
REGION="europe-west1"

gcloud run deploy "$SERVICE" \
  --image "$DOCKER_IMAGE" \
  --region "$REGION" \
  --platform managed \
  --allow-unauthenticated \
  --memory 128Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 1
```

### Configuration File and Secrets

By default the container uses the `volatile` configuration from `/app/config.json`. Override it with a Secret Manager file and set `CONFIGURATION_FILE`.

#### Create the Secret

```bash
PROJECT_ID="YOUR_PROJECT_ID"
SECRET_NAME="secret-config"

gcloud config set project "$PROJECT_ID"

gcloud secrets create "$SECRET_NAME" \
  --replication-policy="automatic"

gcloud secrets versions add "$SECRET_NAME" \
  --data-file="my-secret-config.json"
```

#### Grant Access to the Runtime Service Account

```bash
SERVICE_ACCOUNT="YOUR_CLOUD_RUN_SA@YOUR_PROJECT.iam.gserviceaccount.com"

gcloud secrets add-iam-policy-binding "$SECRET_NAME" \
  --member="serviceAccount:$SERVICE_ACCOUNT" \
  --role="roles/secretmanager.secretAccessor"
```

To verify the service account in use:

```bash
SERVICE="YOUR_CLOUD_RUN_SERVICE"
REGION="europe-west1"

gcloud run services describe "$SERVICE" --region "$REGION" \
  --format="value(spec.template.spec.serviceAccountName)"
```

#### Mount the Secret as a File

```bash
SERVICE="YOUR_CLOUD_RUN_SERVICE"
DOCKER_IMAGE="YOUR_TODO_SERVER_IMAGE"
REGION="europe-west1"
SECRET_NAME="secret-config"

gcloud run deploy "$SERVICE" \
  --image "$DOCKER_IMAGE" \
  --region "$REGION" \
  --platform managed \
  --allow-unauthenticated \
  --memory 128Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 1 \
  --set-env-vars "CONFIGURATION_FILE=/etc/secrets/config.json" \
  --update-secrets "/etc/secrets/config.json=$SECRET_NAME:latest"
```

## Prerequisites

- Swift 6.0 or later.
- macOS or Linux.
- Docker (optional).
- Google Cloud CLI (optional).

### macOS Setup

```bash
swift --version
brew install --cask google-cloud-sdk
gcloud init
```

## Local Development

### Run the Server

```bash
swift run ToDoApp --configuration-file Resources/volatile-config.json
```

By default, the server binds to `127.0.0.1:8080`. Override with `--hostname` and `--port` or set `HOSTNAME` and `PORT` in the environment.

### Login and Call the API

```bash
# Obtain a JWT
curl -u admin:my-secret-password! http://127.0.0.1:8080/user

# Use the token for protected routes
curl -H "Authorization: Bearer <token>" http://127.0.0.1:8080/todos
```

## Tests

```bash
swift test
```

If SwiftPM cannot write to its cache, use a writable scratch path:

```bash
SWIFT_MODULECACHE_PATH=/tmp/swift-modulecache \
  swift test --scratch-path /tmp/swiftpm
```

## Configuration Schema

The configuration file is JSON and matches these top-level keys.

```json
{
  "logLevel": "info",
  "security": {
    "jwtSecretKey": "<secret>",
    "cors": {
      "allowOrigin": "http://localhost:4200"
    }
  },
  "repository": {
    "type": "volatile",
    "firestore": {
      "projectId": "<gcp-project-id>",
      "tokenRetriever": "MetadataServer"
    }
  },
  "users": [
    {
      "id": "<uuid>",
      "name": "admin",
      "password": "<plaintext>"
    }
  ]
}
```

### Notes

- `repository.type` accepts `volatile`, `persistent`, or `emulated`.
- `firestore` is required for `persistent` and `emulated`.
- `tokenRetriever` accepts `MetadataServer`, `AppDefaultCredentials`, or `None`.
- `users.password` is hashed at startup and should not be logged.
- `security.cors.allowOrigin` is optional; when set, the server enables CORS and echoes this origin in `Access-Control-Allow-Origin`.
