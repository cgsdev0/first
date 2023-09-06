
source .secrets
source config.sh

HOST=${HTTP_HEADERS["host"]}
PROTOCOL="https://"
if [[ "$HOST" =~ "localhost"* ]]; then
  PROTOCOL="http://"
fi

AUTHORIZATION_CODE=${QUERY_PARAMS["code"]}

TWITCH_RESPONSE=$(curl -Ss -X POST \
  "https://id.twitch.tv/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${TWITCH_CLIENT_ID}&client_secret=${TWITCH_CLIENT_SECRET}&code=${AUTHORIZATION_CODE}&grant_type=authorization_code&redirect_uri=${PROTOCOL}${HOST}/oauth")

ACCESS_TOKEN=$(echo "$TWITCH_RESPONSE" | jq -r '.access_token')
REFRESH_TOKEN=$(echo "$TWITCH_RESPONSE" | jq -r '.refresh_token')
RESPONSE="<pre>${TWITCH_RESPONSE}</pre>"

if [[ -z "$ACCESS_TOKEN" ]] || [[ "$ACCESS_TOKEN" == "null" ]]; then
  htmx_page <<-EOF
  <div class="container">
    <h1>Error</h1>
    ${RESPONSE}
    <p>Something went wrong registering for ${PROJECT_NAME}. :(</p>
    <p><a href="/">Back to Home</a></p>
  </div>
EOF
  return $(status_code 400)
fi

# we have to get the stupid user id
TWITCH_RESPONSE=$(curl -Ss -X GET 'https://id.twitch.tv/oauth2/validate' \
  -H "Authorization: OAuth ${ACCESS_TOKEN}")

USER_ID=$(echo "$TWITCH_RESPONSE" | jq -r '.user_id')
USER_NAME=$(echo "$TWITCH_RESPONSE" | jq -r '.login')
RESPONSE="<pre>${TWITCH_RESPONSE}</pre>"

if [[ -z "$USER_ID" ]] || [[ "$USER_ID" == "null" ]]; then
  htmx_page <<-EOF
  <div class="container">
    <h1>Error</h1>
    ${RESPONSE}
    <p>Something went wrong registering for ${PROJECT_NAME}. :(</p>
    <p><a href="/">Back to Home</a></p>
  </div>
EOF
  return $(status_code 400)
fi

USER_ACCESS_TOKEN="$ACCESS_TOKEN"

# now we need to get a DIFFERENT token, unrelated, but actually kinda related lol
# see here: https://dev.twitch.tv/docs/eventsub/manage-subscriptions/#subscribing-to-events
TWITCH_RESPONSE=$(curl -Ss -X POST \
  "https://id.twitch.tv/oauth2/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${TWITCH_CLIENT_ID}&client_secret=${TWITCH_CLIENT_SECRET}&grant_type=client_credentials")

ACCESS_TOKEN=$(echo "$TWITCH_RESPONSE" | jq -r '.access_token')

# create the custom reward
TWITCH_RESPONSE=$(curl -Ss -X POST 'https://api.twitch.tv/helix/channel_points/custom_rewards?broadcaster_id='$USER_ID \
-H "Authorization: Bearer ${USER_ACCESS_TOKEN}" \
-H "Client-Id: ${TWITCH_CLIENT_ID}" \
-H 'Content-Type: application/json' \
-d '{"title": "first", "cost": 1, "is_max_per_stream_enabled": true, "max_per_stream": 3, "is_max_per_user_per_stream_enabled": 1, "max_per_user_per_stream": 1, "should_redemptions_skip_request_queue": true}')

HAS_DATA=$(echo "$TWITCH_RESPONSE" | jq -r '.data')
REWARD_ID=$(echo "$TWITCH_RESPONSE" | jq -r '.data[0].id')
RESPONSE="<pre>$TWITCH_RESPONSE</pre>"

if [[ "$HAS_DATA" == "null" ]]; then
  htmx_page <<-EOF
  <div class="container">
    <h1>${PROJECT_NAME}</h1>
    ${RESPONSE}
    <p>Something went wrong creating the custom reward. :(</p>
    <p><a href="/">Back to Home</a></p>
  </div>
EOF
  return $(status_code 400)
fi

# register the webhook using the access token
TWITCH_RESPONSE=$(curl -Ss -X POST 'https://api.twitch.tv/helix/eventsub/subscriptions' \
-H "Authorization: Bearer ${ACCESS_TOKEN}" \
-H "Client-Id: ${TWITCH_CLIENT_ID}" \
-H 'Content-Type: application/json' \
-d '{"type":"stream.online","version":"1","condition":{"broadcaster_user_id":"'${USER_ID}'"},"transport":{"method":"webhook","callback":"https://first.bashsta.cc/webhook","secret":"'${TWITCH_EVENTSUB_SECRET}'"}}')

HAS_DATA=$(echo "$TWITCH_RESPONSE" | jq -r '.data')
STATUS=$(echo "$TWITCH_RESPONSE" | jq -r '.status')
RESPONSE="<pre>$TWITCH_RESPONSE</pre>"

if [[ "$HAS_DATA" == "null" ]]; then
  htmx_page <<-EOF
  <div class="container">
    <h1>${PROJECT_NAME}</h1>
    ${RESPONSE}
    <p>Something went wrong setting up an EventSub subscription. :(</p>
    <p><a href="/">Back to Home</a></p>
  </div>
EOF
  return $(status_code 400)
fi

# register the webhook using the access token
TWITCH_RESPONSE=$(curl -Ss -X POST 'https://api.twitch.tv/helix/eventsub/subscriptions' \
-H "Authorization: Bearer ${ACCESS_TOKEN}" \
-H "Client-Id: ${TWITCH_CLIENT_ID}" \
-H 'Content-Type: application/json' \
-d '{"type":"channel.channel_points_custom_reward_redemption.add","version":"1","condition":{"reward_id":"'$REWARD_ID'","broadcaster_user_id":"'${USER_ID}'"},"transport":{"method":"webhook","callback":"https://first.bashsta.cc/webhook","secret":"'${TWITCH_EVENTSUB_SECRET}'"}}')

HAS_DATA=$(echo "$TWITCH_RESPONSE" | jq -r '.data')
STATUS=$(echo "$TWITCH_RESPONSE" | jq -r '.status')
RESPONSE="<pre>$TWITCH_RESPONSE</pre>"

if [[ "$HAS_DATA" == "null" ]] && [[ "$STATUS" != "409" ]]; then
  htmx_page <<-EOF
  <div class="container">
    <h1>${PROJECT_NAME}</h1>
    ${RESPONSE}
    <p>Something went wrong setting up an EventSub subscription. :(</p>
    <p><a href="/">Back to Home</a></p>
  </div>
EOF
  return $(status_code 400)
fi

# success! persist data
if grep -q "^$USER_ID " data/username_cache; then
  sed -i 's/^'$USER_ID' .*$/'$USER_ID' '$USER_NAME'/' data/username_cache
else
  printf "%s %s\n" "$USER_ID" "$USER_NAME" >> data/username_cache
fi
if grep -q "^$USER_ID " data/rewards; then
  sed -i 's/^'$USER_ID' .*$/'$USER_ID' '$REWARD_ID'/' data/rewards
else
  printf "%s %s\n" "$USER_ID" "$REWARD_ID" >> data/rewards
fi
if grep -q "^$USER_ID " data/refresh_tokens; then
  sed -i 's/^'$USER_ID' .*$/'$USER_ID' '$REFRESH_TOKEN'/' data/refresh_tokens
else
  printf "%s %s\n" "$USER_ID" "$REFRESH_TOKEN" >> data/refresh_tokens
fi
touch data/scores/$USER_ID


htmx_page <<-EOF
  <div class="container">
    <h1>${PROJECT_NAME}</h1>
    <p>Successfully registered! Welcome <span>${USER_NAME}</span> :D</p>
  </div>
EOF
