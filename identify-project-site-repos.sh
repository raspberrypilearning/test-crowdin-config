ORG="raspberrypilearning"

echo "🔍 Finding project site repositories with meta.yml and step_1.md..."

# Function to check if repo has both meta.yml and step_1.md and extract title
check_project_repo() {
    local repo="$1"
    local has_meta=false
    local has_step1=false
    local title=""
    
    # Check for meta.yml in en/ directory and extract title
    if gh api "repos/$ORG/$repo/contents/en/meta.yml" &>/dev/null; then
        has_meta=true
        # Get the meta.yml content and extract title
        title=$(gh api "repos/$ORG/$repo/contents/en/meta.yml" --jq '.content' | base64 -d | grep '^title:' | sed 's/^title: *//' | sed 's/^"//' | sed 's/"$//')
    fi
    
    # Check for step_1.md in en/ directory
    if gh api "repos/$ORG/$repo/contents/en/step_1.md" &>/dev/null; then
        has_step1=true
    fi
    
    # Return success if both files exist, and output the title
    if [ "$has_meta" = true ] && [ "$has_step1" = true ]; then
        echo "$title"
        return 0
    else
        return 1
    fi
}

echo -e "\n📚 Project site repositories (with meta.yml and step_1.md):"

# Generate CSV with repository names and titles
{
    echo "repository_name,project_title,crowdin_project_id"
} > project_repos_new.csv

project_count=0

gh repo list "$ORG" --limit 1000 --json name | \
jq -r '.[].name' | \
while read repo; do
    title=$(check_project_repo "$repo")
    if [ $? -eq 0 ]; then
        echo "  ✅ $ORG/$repo (Title: $title)"
        # Add to CSV with title and empty crowdin_project_id field
        echo "$repo,\"$title\"," >> project_repos_new.csv
        ((project_count++))
    fi
done

echo -e "\n✅ CSV generated: project_repos_new.csv"
echo "📋 Found $(wc -l < project_repos_new.csv | xargs expr -1 +) project repositories"
echo "💡 Fill in the crowdin_project_id column before running bulk setup"