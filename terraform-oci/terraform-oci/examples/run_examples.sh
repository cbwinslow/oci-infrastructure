#!/bin/bash

# Script to run both Python and TypeScript examples
# Usage: ./run_examples.sh

echo "Running database examples..."

# Python Example
echo -e "\n=== Running Python Example ==="
cd python
python3 database_example.py

# TypeScript Example
echo -e "\n=== Running TypeScript Example ==="
cd ../typescript
npm install
npm run build
npm start

echo -e "\nExamples completed!"

