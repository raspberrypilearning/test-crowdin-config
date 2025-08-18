#!/bin/bash

# Script to merge matched results and create final CSV for bulk setup

echo "🔗 Creating final repository-to-Crowdin mapping..."

# Create final CSV in the format expected by bulk setup script
{
    echo "repository_name,crowdin_project_id"
} > two_only_final_repo_mapping.csv

# Add high confidence matches
echo "📋 Adding high confidence matches..."
tail -n +2 two_only_matched_repos.csv | while IFS=',' read -r repository_name project_title crowdin_project_id crowdin_project_name match_confidence; do
    echo "$repository_name,$crowdin_project_id" >> two_only_final_repo_mapping.csv
done

final_count=$(wc -l < two_only_final_repo_mapping.csv | xargs expr -1 +)

echo ""
echo "✅ Final mapping created: two_only_final_repo_mapping.csv"
echo "📊 Total mappings: $final_count"
echo ""
echo "🚀 Ready for bulk setup!"
echo "   Run: ./two_only_bulk-setup-crowdin.sh two_only_final_repo_mapping.csv"
