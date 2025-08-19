#!/bin/bash

# Script to match GitHub repos with Crowdin projects and fill in project IDs

echo "🔗 Matching GitHub repositories with Crowdin projects..."

# Function to normalize names for comparison
normalize_name() {
    local name="$1"
    # Convert to lowercase, replace spaces/underscores with hyphens, remove special chars
    echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[_ ]/-/g' | sed 's/[^a-z0-9-]//g' | sed 's/--*/-/g' | sed 's/^-\|-$//g'
}

# Function to extract project title from RPF project name
extract_project_title() {
    local project_name="$1"
    # Remove RPF prefix and extract the actual project title
    # Patterns: "RPF - Project (Platform) - Title", "RPF - Project - Title"
    #           "RPF - Ingredient (Platform) - Title", "RPF - Ingredient - Title"
    echo "$project_name" | sed -E 's/RPF - (Project|Ingredient)(\s*\([^)]+\))?\s*-\s*//' | sed 's/:.*$//'
}

echo "🔍 Processing repository matches..."

# Load all Crowdin projects into arrays for faster processing
echo "📥 Loading Crowdin projects into memory..."
declare -a crowdin_names=()
declare -a crowdin_ids=()

while IFS=',' read -r project_name project_id; do
    # Skip header
    if [ "$project_name" = "project_name" ]; then
        continue
    fi
    crowdin_names+=("$project_name")
    crowdin_ids+=("$project_id")
done < two_only_crowdin_projects.csv

total_crowdin_projects=${#crowdin_names[@]}
echo "📊 Loaded $total_crowdin_projects Crowdin projects"

# Function to find best match for a project title (optimized)
find_crowdin_match_fast() {
    local project_title="$1"
    local normalized_title=$(normalize_name "$project_title")
    local best_match=""
    local best_score=0
    local best_id=""
    
    # Iterate through pre-loaded arrays instead of reading file
    for ((i=0; i<${#crowdin_names[@]}; i++)); do
        local crowdin_project_name="${crowdin_names[i]}"
        local project_id="${crowdin_ids[i]}"
        
        # Extract the actual project title from RPF project name
        local crowdin_project_title=$(extract_project_title "$crowdin_project_name")
        local normalized_crowdin=$(normalize_name "$crowdin_project_title")
        
        # Calculate similarity score
        local score=0
        
        # Exact match gets highest score
        if [ "$normalized_title" = "$normalized_crowdin" ]; then
            score=100
        # Check if project title is contained in crowdin project title
        elif [[ "$normalized_crowdin" == *"$normalized_title"* ]]; then
            score=90
        # Check if crowdin project title is contained in project title
        elif [[ "$normalized_title" == *"$normalized_crowdin"* ]]; then
            score=85
        # Check for very close matches (allowing for small differences)
        else
            # Split into words and check for word matches
            local title_words=($(echo "$normalized_title" | tr '-' ' '))
            local crowdin_words=($(echo "$normalized_crowdin" | tr '-' ' '))
            local total_title_words=${#title_words[@]}
            local matches=0
            
            for title_word in "${title_words[@]}"; do
                for crowdin_word in "${crowdin_words[@]}"; do
                    if [ "$title_word" = "$crowdin_word" ] && [ ${#title_word} -gt 2 ]; then
                        ((matches++))
                        break
                    fi
                done
            done
            
            # Calculate score based on percentage of matching words
            if [ $total_title_words -gt 0 ] && [ $matches -gt 0 ]; then
                score=$((matches * 100 / total_title_words))
                # Bonus for high match ratio
                if [ $score -ge 80 ]; then
                    score=$((score + 10))
                fi
            fi
        fi
        
        # Update best match if this score is higher
        if [ $score -gt $best_score ]; then
            best_score=$score
            best_match="$crowdin_project_name"
            best_id="$project_id"
        fi
        
        # Early exit for perfect matches
        if [ $score -eq 100 ]; then
            break
        fi
    done
    
    # Return the best match info
    echo "$best_id,$best_match,$best_score"
}

# Create output CSV with matches
{
    echo "repository_name,project_title,crowdin_project_id,crowdin_project_name,match_confidence"
} > two_only_matched_repos.csv

# Create a manual review CSV for low confidence matches
{
    echo "repository_name,project_title,suggested_crowdin_id,suggested_crowdin_name,match_confidence,manual_crowdin_id"
} > two_only_manual_review.csv

total_repos=0
high_confidence=0
low_confidence=0

# Process each repository
while IFS=',' read -r repo_name project_title crowdin_id; do
    # Skip header
    if [ "$repo_name" = "repository_name" ]; then
        continue
    fi
    
    ((total_repos++))
    
    # Clean up project title (remove quotes if present)
    project_title=$(echo "$project_title" | sed 's/^["'\'']*//;s/["'\'']*$//')
    
    # Find best Crowdin match using project title
    match_result=$(find_crowdin_match_fast "$project_title")
    IFS=',' read -r matched_id matched_name confidence <<< "$match_result"
    
    echo "📝 $repo_name ($project_title) -> $matched_name (confidence: $confidence%)"
    
    if [ $confidence -ge 70 ]; then
        # High confidence match - add to final CSV
        echo "$repo_name,\"$project_title\",$matched_id,\"$matched_name\",$confidence%" >> two_only_matched_repos.csv
        ((high_confidence++))
    else
        # Low confidence match - add to manual review
        echo "$repo_name,\"$project_title\",$matched_id,\"$matched_name\",$confidence%," >> two_only_manual_review.csv
        ((low_confidence++))
    fi

done < two_only_project_repos_new.csv

echo ""
echo "✅ Matching completed!"
echo "📊 Results:"
echo "   Total repositories: $total_repos"
echo "   High confidence matches (≥70%): $high_confidence"
echo "   Low confidence matches (<70%): $low_confidence"
echo ""
echo "📁 Output files:"
echo "   two_only_matched_repos.csv - High confidence matches ready to use"
echo "   two_only_manual_review.csv - Low confidence matches for manual review"
echo ""
echo "💡 Next steps:"
echo "   1. Review two_only_manual_review.csv and fill in correct IDs"
echo "   2. Merge both files for complete mapping"
echo "   3. Use with bulk setup script"
