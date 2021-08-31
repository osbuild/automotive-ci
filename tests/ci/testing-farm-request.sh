#!/bin/bash

set -e

dnf install -y jq

ENDPOINT="https://api.dev.testing-farm.io/v0.1/requests"

if [[ "${ARCH}" == "x86_64" ]]; then
    COMPOSE="CentOS-Stream-8"
else
    COMPOSE="CentOS-Stream-8-aarch64"
fi

cat <<EOF > request.json
{
"api_key": "${TF_API_KEY}",
"test": {
    "fmf": {
    "url": "https://github.com/osbuild/automotive-ci",
    "ref": "run-in-testing-farm",
    "name": "/tests/ci/create-commit"
    }
},
"environments": [
    {
    "arch": "${ARCH}",
    "os": {"compose": "${COMPOSE}"},
    "variables": {
        "ARCH": "${ARCH}",
        "UUID": "${UUID}",
        "GITHUB_RUN_ID": "${UUID}",
        "AWS_ACCESS_KEY_ID": "${AWS_ACCESS_KEY_ID}",
        "AWS_SECRET_ACCESS_KEY": "${AWS_SECRET_ACCESS_KEY}"
    }
    }
]
}
EOF

curl --silent ${ENDPOINT} \
    --header "Content-Type: application/json" \
    --data @request.json \
    --output response.json

jq . response.json

ID=$(jq -r '.id' response.json)
echo "Wait until the job finished at the Testing Farm"
while true; do
    rm -f response.json
    curl --silent --output response.json "${ENDPOINT}/${ID}"
    STATUS=$(jq -r '.state' response.json)
    if [[ "$STATUS" == "complete" ]] || [[ "$STATUS" == "error" ]]; then
        echo ; echo "Finished"
        break
    fi
    echo -n "."
    sleep 30
done
RESULT=$(jq -r '.result.overall' response.json)
echo "Result: $RESULT"
# If the result is an error, there is no report to show
if [[ "$RESULT" == "error" ]]; then
    jq -r '.result.summary' response.json
    exit 1
fi
EXIT_CODE=1
if [[ "$RESULT" == "passed" ]]; then
    EXIT_CODE=0
fi

URL=$(jq -r '.run.artifacts' response.json)
curl --silent --output report.html "$URL/"
echo "The build results are here: $URL"

exit $EXIT_CODE