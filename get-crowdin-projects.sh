#!/bin/bash

# Script to get all Crowdin projects and their ids and export to CSV
# Usage: ./get-crowdin-projects.sh

echo "🔍 Fetching all Crowdin projects..."

# Check if curl and jq are available
if ! command -v curl &> /dev/null; then
    echo "❌ curl is not installed. Please install it first."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ jq is not installed. Please install it first:"
    echo "   brew install jq"
    exit 1
fi

# Check if API token is set
if [ -z "$CROWDIN_PERSONAL_TOKEN" ]; then
    echo "❌ CROWDIN_PERSONAL_TOKEN environment variable is not set"
    echo "   Please set it with: export CROWDIN_PERSONAL_TOKEN=your_token_here"
    exit 1
fi

echo "📊 Generating CSV of all Crowdin projects..."

# Create CSV header
{
    echo "project_name,project_id"
} > crowdin_projects.csv

# Get projects with proper error handling and pagination
offset=0
limit=25
total_found=0

while true; do
    echo "📄 Fetching projects $offset to $((offset + limit))..."
    
    response=$(curl -s -H "Authorization: Bearer $CROWDIN_PERSONAL_TOKEN" \
        -H "Content-Type: application/json" \
        "https://api.crowdin.com/api/v2/projects?limit=$limit&offset=$offset")
    
    # Check if response is valid
    if [ -z "$response" ] || echo "$response" | jq -e '.data' >/dev/null 2>&1; then
        # Extract RPF projects from this batch
        batch_count=$(echo "$response" | jq -r '.data[]? | select(.data.name | contains("RPF - Project") or contains("RPF - Ingredient")) | "\(.data.name),\(.data.id)"' | tee -a crowdin_projects.csv | wc -l)
        total_found=$((total_found + batch_count))
        
        # Check if we got fewer results than requested (end of data)
        actual_count=$(echo "$response" | jq -r '.data | length')
        if [ "$actual_count" -lt "$limit" ]; then
            echo "📄 Reached end of results"
            break
        fi
        
        offset=$((offset + limit))
    else
        echo "❌ API error or invalid response"
        break
    fi
done

echo "🎯 Total RPF projects found: $total_found"

echo "✅ CSV generated: crowdin_projects.csv"
echo "📋 Found $total_found Crowdin projects"
echo ""
echo "💡 You can now:"
echo "   1. Cross-reference this with your GitHub repositories"
echo "   2. Create a mapping for the bulk setup script"
