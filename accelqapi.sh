#!/bin/bash

# AccelQ API credentials
API_TOKEN="_vEXPgyaqAxtXL7wbvzvooY49cnsIYYHrWQMJH-ZcEM"
EXECUTION_ID="452413"
USER_ID="koray.ayakin@pargesoft.com"

# Fetch test results
curl -X GET "https://poc.accelq.io/awb/api/1.0/poc25/runs/${EXECUTION_ID}" \
-H "api_key: ${API_TOKEN}" \
-H "user_id: ${USER_ID}" \
-H "Content-Type: application/json" > accelq-results.json

echo "AccelQ test results fetched and saved to accelq-results.json"
