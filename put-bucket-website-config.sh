#!/usr/bin/env bash

# Uso: ./put-bucket-website-config.sh <nombre_bucket> <ruta_json>
if [ "$#" -ne 2 ]; then
  echo "Uso: $0 <nombre_bucket> <ruta_json>"
  exit 1
fi

BUCKET_NAME="$1"
JSON_PATH="$2"

aws s3api put-bucket-website \
  --bucket "$BUCKET_NAME" \
  --website-configuration file://"$JSON_PATH"