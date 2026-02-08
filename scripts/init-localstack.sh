#!/bin/bash
# =============================================================================
# LocalStack S3 Initialization Script
# =============================================================================
# This script runs when LocalStack starts and creates the S3 bucket for
# DuckDB Iceberg tables.
# =============================================================================

set -e

# Wait for LocalStack to be ready
echo "Waiting for LocalStack to be ready..."
sleep 5

# Create S3 bucket
echo "Creating S3 bucket for Iceberg tables..."
aws --endpoint-url=http://localhost:4566 s3 mb s3://schema-evolution-iceberg || echo "Bucket already exists"

echo "LocalStack S3 initialization complete ✓"
