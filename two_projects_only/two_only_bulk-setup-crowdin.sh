#!/bin/bash

# Bulk GitHub Actions and Crowdin Setup Script
# Usage: ./bulk-setup-crowdin.sh <csv_file>
# The script will pull template files from a designated repository

set -e

CSV_FILE="$1"
WORKFLOW_DIR=".github/workflows"
TEMP_DIR="temp-repo"
TEMPLATE_DIR="template-files" # Directory to hold template files
ORG="raspberrypilearning"

# Get absolute path for template directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR_FULL="$SCRIPT_DIR/$TEMPLATE_DIR"

# Repository containing the template files
TEMPLATE_REPO="raspberrypilearning/test-crowdin-config"
TEMPLATE_BRANCH="draft"  # or "main" depending on where your files are

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to setup template files from the designated repository
setup_template_files() {
    echo -e "${BLUE}📥 Cloning template repository: $TEMPLATE_REPO (branch: $TEMPLATE_BRANCH)${NC}"
    
    if gh repo clone "$TEMPLATE_REPO" "$TEMPLATE_DIR_FULL" -- --branch "$TEMPLATE_BRANCH" 2>/dev/null; then
        echo -e "${GREEN}✅ Successfully cloned template repository${NC}"
    else
        echo -e "${RED}❌ Failed to clone template repository: $TEMPLATE_REPO${NC}"
        echo "Make sure you have access to the repository and the branch exists"
        exit 1
    fi
}

# Check if workflow files exist in the template repository
check_workflow_files() {
    local files_found=0
    local missing_files=()
    
    if [ -f "$TEMPLATE_DIR_FULL/.github/workflows/upload-sources.yml" ]; then
        ((files_found++))
    else
        missing_files+=(".github/workflows/upload-sources.yml")
    fi
    
    if [ -f "$TEMPLATE_DIR_FULL/.github/workflows/download-translations.yml" ]; then
        ((files_found++))
    else
        missing_files+=(".github/workflows/download-translations.yml")
    fi
    
    if [ -f "$TEMPLATE_DIR_FULL/crowdin.yml" ]; then
        ((files_found++))
    else
        missing_files+=("crowdin.yml")
    fi
    
    if [ $files_found -ne 3 ]; then
        echo -e "${RED}Error: Required workflow files not found in template repository${NC}"
        echo "Repository: $TEMPLATE_REPO"
        echo "Branch: $TEMPLATE_BRANCH"
        echo "Missing files: ${missing_files[*]}"
        echo ""
        echo "Please ensure these files exist in the template repository:"
        echo "  - .github/workflows/upload-sources.yml"
        echo "  - .github/workflows/download-translations.yml" 
        echo "  - crowdin.yml (in root directory)"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Found all required template files in: $TEMPLATE_REPO${NC}"
}

# Function to process repos from CSV
process_csv_repos() {
    while IFS=',' read -r repo_name crowdin_project_id; do
        # Skip header line
        if [ "$repo_name" = "repository_name" ]; then
            continue
        fi
        # Add organization prefix if not already present
        if [[ "$repo_name" != *"/"* ]]; then
            repo_name="$ORG/$repo_name"
        fi
        process_single_repo "$repo_name" "$crowdin_project_id"
    done < "$CSV_FILE"
}

# Function to process a single repository
process_single_repo() {
    local repo_name="$1"
    local crowdin_project_id="$2"
    
    echo -e "\n${YELLOW}Processing: $repo_name (Crowdin ID: $crowdin_project_id)${NC}"
    
    # Clone repository
    echo "  📥 Cloning repository..."
    if gh repo clone "$repo_name" "$TEMP_DIR" 2>/dev/null; then
        cd "$TEMP_DIR"
        
        # Create .github/workflows directory
        echo "  📁 Creating workflows directory..."
        mkdir -p "$WORKFLOW_DIR"
        
        # Copy workflow files from template repository
        echo "  📋 Copying workflow files from template repo..."
        cp "$TEMPLATE_DIR_FULL/.github/workflows/upload-sources.yml" "$WORKFLOW_DIR/"
        cp "$TEMPLATE_DIR_FULL/.github/workflows/download-translations.yml" "$WORKFLOW_DIR/"
        
        # Copy crowdin.yml to root directory (will overwrite existing file)
        echo "  📋 Copying crowdin.yml (overwriting existing)..."
        echo "  🔍 Debug: Template file exists? $([ -f "$TEMPLATE_DIR_FULL/crowdin.yml" ] && echo "YES" || echo "NO")"
        echo "  🔍 Debug: Current directory: $(pwd)"
        echo "  🔍 Debug: Existing crowdin.yml? $([ -f "crowdin.yml" ] && echo "YES" || echo "NO")"
        
        # Force remove existing crowdin.yml and copy new one
        rm -f "crowdin.yml"
        cp "$TEMPLATE_DIR_FULL/crowdin.yml" "./"
        
        # Verify the file was copied
        if [ -f "crowdin.yml" ]; then
            echo "  ✅ crowdin.yml successfully copied"
            echo "  🔍 Debug: New file size: $(wc -c < crowdin.yml) bytes"
        else
            echo "  ❌ Failed to copy crowdin.yml"
            exit 1
        fi
        
        # Commit and push changes
        echo "  💾 Committing changes..."
        git add .
        if git diff --staged --quiet; then
            echo "  ⚠️  No changes to commit (files may already exist)"
        else
            git commit -m "Add Crowdin integration workflows and configuration"
            git push
            echo "  ✅ Pushed workflow files"
        fi
        
        cd ..
        
        # Set GitHub secrets
        echo "  🔐 Setting GitHub secrets..."
        gh secret set CROWDIN_PROJECT_ID --body "$crowdin_project_id" --repo "$repo_name"
        
        # Clean up repository clone
        cd "$SCRIPT_DIR"
        rm -rf "$TEMP_DIR"
        
        echo -e "  ${GREEN}✅ Completed: $repo_name${NC}"
        
    else
        echo -e "  ${RED}❌ Failed to clone: $repo_name${NC}"
    fi
    
    # Small delay to avoid rate limiting
    sleep 1
}

echo -e "${YELLOW}Starting bulk setup for Crowdin integration...${NC}"

# Setup template files from the designated repository
setup_template_files

# Check for required workflow files
check_workflow_files

# Main execution logic
if [ -z "$CSV_FILE" ]; then
    echo -e "${RED}Error: No CSV file provided${NC}"
    echo "Usage: $0 <csv_file>"
    echo "CSV format: repo_name,crowdin_project_id"
    echo ""
    echo "Template files will be pulled from: $TEMPLATE_REPO"
    exit 1
fi

if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}Error: CSV file '$CSV_FILE' not found${NC}"
    exit 1
fi

echo -e "${BLUE}📋 Using CSV file: $CSV_FILE${NC}"
process_csv_repos

# Cleanup template repository
echo -e "${BLUE}🧹 Cleaning up template files...${NC}"
if [ -d "$TEMPLATE_DIR_FULL" ]; then
    rm -rf "$TEMPLATE_DIR_FULL"
    echo "  ✅ Template directory cleaned up"
else
    echo "  ℹ️  Template directory already clean"
fi

# Cleanup any remaining temporary directories
if [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
    echo "  ✅ Temporary directory cleaned up"
fi

echo -e "\n${GREEN}🎉 Bulk setup completed!${NC}"
echo -e "${YELLOW}Note: Make sure to set CROWDIN_API_TOKEN as an organization secret${NC}"
echo -e "${YELLOW}Note: Use disable-crowdin-github-integration.sh to disable GitHub integrations if needed${NC}"
