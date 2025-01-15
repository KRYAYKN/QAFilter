#!/bin/bash

# AccelQ API credentials
API_TOKEN="_vEXPgyaqAxtXL7wbvzvooY49cnsIYYHrWQMJH-ZcEM"
EXECUTION_ID="452413"
USER_ID="koray.ayakin@pargesoft.com"

# Step 1: Fetch AccelQ Test Results
echo "Fetching AccelQ test results..."
curl -X GET "https://poc.accelq.io/awb/api/1.0/poc25/runs/${EXECUTION_ID}" \
  -H "api_key: ${API_TOKEN}" \
  -H "user_id: ${USER_ID}" \
  -H "Content-Type: application/json" > accelq-results.json
echo "AccelQ test results saved to accelq-results.json"

# Step 2: Identify Passed Features
echo "Identifying passed features..."
PASSED_FEATURES=$(jq -r '.summary.testCaseSummaryList[] | select(.status == "pass") | .metadata.tags[]' accelq-results.json | sort | uniq)

if [[ -z "$PASSED_FEATURES" ]]; then
  echo "No passed features found. Exiting..."
  exit 0
fi

echo "Passed features: $PASSED_FEATURES"

# Step 3: Process Each Passed Feature
for feature in $PASSED_FEATURES; do
  echo "Processing feature: $feature"

  # Find commits in QA branch related to the feature
  COMMITS=$(git log qa --pretty=format:"%H" --grep="$feature")

  if [[ -z "$COMMITS" ]]; then
    echo "No commits found for feature: $feature"
    continue
  fi

  # Step 4: Create a temporary branch for staging
  TEMP_BRANCH="temp-staging-${feature//\//-}-$(date +%s)"
  git checkout staging
  git pull origin staging
  git checkout -b "$TEMP_BRANCH"

  # Cherry-pick commits
  for commit in $COMMITS; do
    echo "Cherry-picking commit: $commit"
    if git rev-list --parents -n 1 $commit | grep -q " "; then
      echo "Commit $commit is a merge commit. Using -m option."
      git cherry-pick -m 1 $commit --strategy-option=theirs || { 
        echo "Failed to cherry-pick $commit. Resolving conflict automatically...";
        git cherry-pick --abort;
        exit 1;
      }
    else
      git cherry-pick $commit --strategy-option=theirs || { 
        echo "Failed to cherry-pick $commit. Resolving conflict automatically...";
        git cherry-pick --abort;
        exit 1;
      }
    fi
  done

  # Push the temporary branch and create a PR
  git push origin "$TEMP_BRANCH"
  gh pr create --base staging --head "$TEMP_BRANCH" --title "Promotion to Staging: $feature" --body "QA tests passed for $feature."
done

# Cleanup temporary file
rm -f accelq-results.json

echo "All passed features have been processed."
