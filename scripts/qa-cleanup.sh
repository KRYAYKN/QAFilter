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

# Step 2: Identify Passed, Failed, and Aborted Branches
echo "Identifying passed, failed, and aborted branches..."
PASSED_BRANCHES=$(jq -r '.summary.testCaseSummaryList[] | select(.status == "pass") | .metadata.tags[]' accelq-results.json | sort | uniq)
FAILED_OR_ABORTED_BRANCHES=$(jq -r '.summary.testCaseSummaryList[] | select(.status == "fail" or .status == "aborted") | .metadata.tags[]' accelq-results.json | sort | uniq)

if [[ -z "$FAILED_OR_ABORTED_BRANCHES" ]]; then
  echo "No failed or aborted branches found. QA branch is clean."
  exit 0
fi

echo "Passed branches: $PASSED_BRANCHES"
echo "Failed or aborted branches: $FAILED_OR_ABORTED_BRANCHES"

# Step 3: Checkout QA Branch
echo "Checking out QA branch..."
rm -f accelq-results.json  # Geçici dosyayı kaldır
git checkout qa || { echo "Failed to checkout QA branch"; exit 1; }
git pull origin qa || { echo "Failed to pull latest QA branch"; exit 1; }

# Step 4: Revert All Commits from Failed or Aborted Branches
for branch in $FAILED_OR_ABORTED_BRANCHES; do
  echo "Processing branch: $branch"

  # Find all commits related to the branch (including merges and normal commits)
  COMMITS=$(git log --pretty=format:"%H" --grep="$branch")

  if [[ -z "$COMMITS" ]]; then
    echo "No commits from branch $branch found in QA branch."
    continue
  fi

  # Revert each commit related to the branch
  for commit in $COMMITS; do
    echo "Reverting commit: $commit"

    # Check if commit is a merge commit
    if git show --quiet --pretty=format:"%P" $commit | grep -q ' '; then
      # If it's a merge commit, use -m 1 to specify the first parent
      git revert --no-edit -m 1 $commit || {
        echo "Failed to revert merge commit $commit. Skipping..."
        continue
      }
    else
      # If it's not a merge commit, revert normally
      git revert --no-edit $commit || {
        echo "Failed to revert commit $commit. Skipping..."
        continue
      }
    fi
  done
done

# Step 5: Push Updated QA Branch
echo "Pushing updated QA branch to origin..."
git push origin qa || { echo "Failed to push updated QA branch"; exit 1; }

echo "QA branch cleanup completed successfully."
