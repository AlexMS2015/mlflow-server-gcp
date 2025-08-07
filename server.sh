#!/bin/bash 

mlflow db upgrade $SQL_URL
mlflow server \
  --host 0.0.0.0 \
  --port 8080 \
  --backend-store-uri $DB_URL \
  --artifacts-destination $BUCKET_URL