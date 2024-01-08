#!/bin/bash

# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

PROXY_NAME="oauth2-cc-jwt-mb1531"
DEVELOPER_EMAIL="${PROXY_NAME}-apigeesamples@cymbalgroup.com"

create_apiproduct() {
    local product_name=$1
    local ops_file="./configuration-data/operations-defn-${product_name}.json"
    if apigeecli products get --name "${product_name}" --org "$PROJECT" --token "$TOKEN" --disable-check >>/dev/null 2>&1; then
        printf "  The apiproduct %s already exists!\n" "${product_name}"
    else
        [[ ! -f "$ops_file" ]] && printf "missing operations definition file %s\n" "$ops_file" && exit 1
        apigeecli products create --name "${product_name}" --displayname "${product_name}" \
            --opgrp "$ops_file" \
            --envs "$APIGEE_ENV" --approval auto \
            --org "$PROJECT" --token "$TOKEN" --disable-check
    fi
}

create_app() {
    local product_name=$1
    local developer=$2
    local app_name=${product_name}-app
    local KEYPAIR

    local NUM_APPS
    NUM_APPS=$(apigeecli apps get --name "${app_name}" --org "$PROJECT" --token "$TOKEN" --disable-check | jq -r .'| length')
    if [[ $NUM_APPS -eq 0 ]]; then
        mapfile -t KEYPAIR < <(apigeecli apps create --name "${app_name}" --email "${developer}" --prods "${product_name}" --org "$PROJECT" --token "$TOKEN" --disable-check | jq -r ".credentials[0] | .consumerKey,.consumerSecret")
    else
        # must not echo here, it corrupts the return value of the function.
        # printf "  The app %s already exists!\n" ${app_name}
        mapfile -t KEYPAIR < <(apigeecli apps get --name "${app_name}" --org "$PROJECT" --token "$TOKEN" --disable-check | jq -r ".[0].credentials[0] | .consumerKey,.consumerSecret")
    fi
    echo "${KEYPAIR[@]}"
}

import_and_deploy_apiproxy() {
    local proxy_name=$1
    REV=$(apigeecli apis create bundle -f "./apiproxy" -n "$proxy_name" --org "$PROJECT" --token "$TOKEN" --disable-check | jq ."revision" -r)
    apigeecli apis deploy --wait --name "$proxy_name" --ovr --rev "$REV" --org "$PROJECT" --env "$APIGEE_ENV" --token "$TOKEN" --disable-check
}

# ==========================================================

[[ -z "$PROJECT" ]] && echo "No PROJECT variable set" && exit 1
[[ -z "$APIGEE_ENV" ]] && echo "No APIGEE_ENV variable set" && exit 1
[[ -z "$APIGEE_HOST" ]] && echo "No APIGEE_HOST variable set" && exit 1

TOKEN=$(gcloud auth print-access-token)

echo "Installing apigeecli"
curl -s https://raw.githubusercontent.com/apigee/apigeecli/master/downloadLatest.sh | bash
export PATH=$PATH:$HOME/.apigeecli/bin

printf "Importing and Deploying the Apigee proxies...\n"
import_and_deploy_apiproxy "$PROXY_NAME"

printf "Creating API Product\n"
create_apiproduct "apiproduct-example-1"

printf "Creating Developer %s\n" "${DEVELOPER_EMAIL}"
if apigeecli developers get --email "${DEVELOPER_EMAIL}" --org "$PROJECT" --token "$TOKEN" --disable-check >>/dev/null 2>&1; then
    printf "  The developer already exists.\n"
else
    apigeecli developers create --user "${DEVELOPER_EMAIL}" --email "${DEVELOPER_EMAIL}" \
        --first APIProduct --last SampleDeveloper \
        --org "$PROJECT" --token "$TOKEN" --disable-check
fi

printf "Checking and possibly Creating Developer App\n"
# shellcheck disable=SC2046,SC2162
IFS=$' ' read -a APP_CREDS <<<$(create_app "apiproduct-example-1" "${DEVELOPER_EMAIL}")

export TOKEN_DISPENSER_BASEPATH="/$PROXY_NAME-token-dispenser"
export TOKEN_VERIFIER_BASEPATH="/$PROXY_NAME-token-verifier"
export APP_CLIENT_ID=${APP_CREDS[0]}
export APP_CLIENT_SECRET=${APP_CREDS[1]}

echo " "
echo "All the Apigee artifacts are successfully deployed."
echo " "
echo "Copy/paste these statements into cloud shell to set variables for the"
echo "API Keys and secrets. You need the CLIENT_SECRET variables only if you"
echo "will be using the access token examples."
echo " "
echo "  APP_CLIENT_ID=$APP_CLIENT_ID"
echo "  APP_CLIENT_SECRET=$APP_CLIENT_SECRET"
echo " "

echo "Get a token:"
echo "curl -i -X POST \\"
echo "  -u \$APP_CLIENT_ID:\$APP_CLIENT_SECRET \\"
echo "  -d grant_type=client_credentials \\"
echo "  https://${APIGEE_HOST}${TOKEN_DISPENSER_BASEPATH}/token"
echo " "

echo "Use the token:"
echo "curl -i -X GET \\"
echo "  -H \"Authorization: Bearer \$access_token\" \\"
echo "  https://${APIGEE_HOST}${TOKEN_VERIFIER_BASEPATH}/check"
echo " "
