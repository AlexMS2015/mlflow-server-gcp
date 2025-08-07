#!/bin/bash

echo "Starting MLflow server..."
echo "DB_URL: $DB_URL"
echo "BUCKET_URL: $BUCKET_URL"
echo "PORT: ${PORT:-8080}"

mlflow db upgrade $DB_URL
mlflow server \
  --host 0.0.0.0 \
  --port ${PORT:-8080} \
  --backend-store-uri $DB_URL \
  --artifacts-destination $BUCKET_URL