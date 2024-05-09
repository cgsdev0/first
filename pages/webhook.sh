# headers

source .secrets

SIGNATURE=${HTTP_HEADERS['twitch-eventsub-message-signature']}
TOPIC=${HTTP_HEADERS['twitch-eventsub-subscription-type']}
MSG_ID=${HTTP_HEADERS['twitch-eventsub-message-id']}
TIMESTAMP=${HTTP_HEADERS['twitch-eventsub-message-timestamp']}
TYPE=${HTTP_HEADERS['twitch-eventsub-message-type']}
HMAC_MSG="${MSG_ID}${TIMESTAMP}${REQUEST_BODY}"

SIGNATURE2="sha256=$(echo -n "$HMAC_MSG" | openssl sha256 -hmac "$TWITCH_EVENTSUB_SECRET" | cut -d' ' -f2)"

if [[ -z "$SIGNATURE" ]] || [[ -z "$SIGNATURE2" ]] || [[ "$SIGNATURE" != "$SIGNATURE2" ]]; then
  printf "\r\n"
  printf "\r\n"
  echo "invalid signature"
  debug "BAD SIG"
  return $(status_code 400)
fi

if [[ "$TYPE" == "webhook_callback_verification" ]]; then
  CHALLENGE=$(echo "$REQUEST_BODY" | jq -r '.challenge')
  CHALLEN=$(echo "$CHALLENGE" | wc -c)
  printf "%s\r\n" "Content-Type: $CHALLEN"
  printf "\r\n"
  printf "\r\n"
  echo "$CHALLENGE"
  debug "COMPLETING CHALLENGE"
  return $(status_code 200)
fi

printf "\r\n"
printf "\r\n"

if [[ "$TYPE" == "notification" ]]; then
  EVENT_TYPE=$(echo "$REQUEST_BODY" | jq -r '.subscription.type')
  EVENT=$(echo "$REQUEST_BODY" | jq -r '.event')
  USER_ID=$(echo "$EVENT" | jq -r '.broadcaster_user_id')
  debug "hello from $USER_ID"
  REWARD_ID=$(grep "^$USER_ID " data/rewards | cut -d' ' -f2 | tr -d '\n')
  CASE="$(grep "^$USER_ID " data/case | cut -d' ' -f2 | tr -d '\n')"
  CASE="${CASE:-lower}"
  MODE="$(grep "^$USER_ID " data/mode | cut -d' ' -f2 | tr -d '\n')"
  MODE="${MODE:-legacy}"
  COUNT="$(grep "^$USER_ID " data/count | cut -d' ' -f2 | tr -d '\n')"
  COUNT="${COUNT:-0}"
  STREAM_ID="$(grep "^$USER_ID " data/stream_id | cut -d' ' -f2 | tr -d '\n')"
  STREAM_ID="${STREAM_ID:-42069}"
  debug "GOT NOTIFICATION FOR EVENT TYPE $EVENT_TYPE"
  if [[ "$EVENT_TYPE" == "stream.online" ]]; then
    NEW_STREAM_ID=$(echo "$EVENT" | jq -r '.id')
    if grep -q "^$USER_ID " data/stream_id; then
      sed -i 's/^'$USER_ID' .*$/'$USER_ID' '$NEW_STREAM_ID'/' data/stream_id
    else
      printf "%s %s\n" "$USER_ID" "$NEW_STREAM_ID" >> data/mode
    fi

    # refresh our token
    USER_REFRESH_TOKEN=$(grep "^$USER_ID " data/refresh_tokens | cut -d' ' -f2)
    RESPONSE=$(curl -Ss -X POST "https://id.twitch.tv/oauth2/token" \
    -F "client_id=${TWITCH_CLIENT_ID}" \
    -F "refresh_token=${USER_REFRESH_TOKEN}" \
    -F "client_secret=${TWITCH_CLIENT_SECRET}" \
    -F 'grant_type=refresh_token' )
    USER_REFRESH_TOKEN=$(echo "$RESPONSE" | jq -r '.refresh_token')
    USER_ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')

    if [[ "$USER_ACCESS_TOKEN" == "null" ]]; then
      debug "BAILING - NULL ACCESS TOKEN"
      return $(status_code 500)
    fi
    if [[ "$USER_REFRESH_TOKEN" == "null" ]]; then
      debug "BAILING - NULL REFRESH TOKEN"
      return $(status_code 500)
    fi
    sed -i 's/^'$USER_ID' .*$/'$USER_ID' '$USER_REFRESH_TOKEN'/' data/refresh_tokens

    if grep -q "^$USER_ID " data/count; then
      sed -i 's/^'$USER_ID' .*$/'$USER_ID' 0/' data/count
    else
      printf "%s %s\n" "$USER_ID" "0" >> data/count
    fi
    # reset the name of the thing
    TWITCH_RESPONSE=$(curl -Ss -X PATCH 'https://api.twitch.tv/helix/channel_points/custom_rewards?broadcaster_id='$USER_ID'&id='$REWARD_ID \
    -H "Authorization: Bearer ${USER_ACCESS_TOKEN}" \
    -H "Client-Id: ${TWITCH_CLIENT_ID}" \
    -H 'Content-Type: application/json' \
    -d '{"title": "'$(change_case $CASE first)'"}')
    # update broadcaster username in cache
    BROADCASTER_NAME=$(echo "$EVENT" | jq -r '.broadcaster_user_name')
    if grep -q "^$USER_ID " data/username_cache; then
      sed -i 's/^'$USER_ID' .*$/'$USER_ID' '$BROADCASTER_NAME'/' data/username_cache
    else
      printf "%s %s\n" "$USER_ID" "$BROADCASTER_NAME" >> data/username_cache
    fi
  elif [[ "$EVENT_TYPE" == "channel.channel_points_custom_reward_redemption.add" ]]; then
    # check if we care about this reward
    REDEEMED_ID=$(echo "$EVENT" | jq -r '.reward.id' | tr -d '\n')
    if [[ "$REDEEMED_ID" != "$REWARD_ID" ]]; then
      debug "REWARD ID MISMATCH '$REDEEMED_ID' != '$REWARD_ID'"
      return $(status_code 204)
    fi
    # refresh our token
    USER_REFRESH_TOKEN=$(grep "^$USER_ID " data/refresh_tokens | cut -d' ' -f2)
    RESPONSE=$(curl -Ss -X POST "https://id.twitch.tv/oauth2/token" \
    -F "client_id=${TWITCH_CLIENT_ID}" \
    -F "refresh_token=${USER_REFRESH_TOKEN}" \
    -F "client_secret=${TWITCH_CLIENT_SECRET}" \
    -F 'grant_type=refresh_token' )
    USER_REFRESH_TOKEN=$(echo "$RESPONSE" | jq -r '.refresh_token')
    USER_ACCESS_TOKEN=$(echo "$RESPONSE" | jq -r '.access_token')

    if [[ "$USER_ACCESS_TOKEN" == "null" ]]; then
      debug "BAILING - NULL ACCESS TOKEN"
      return $(status_code 500)
    fi
    if [[ "$USER_REFRESH_TOKEN" == "null" ]]; then
      debug "BAILING - NULL REFRESH TOKEN"
      return $(status_code 500)
    fi
    sed -i 's/^'$USER_ID' .*$/'$USER_ID' '$USER_REFRESH_TOKEN'/' data/refresh_tokens

    # update the count
    ((COUNT++))
    sed -i 's/^'$USER_ID' .*$/'$USER_ID' '$COUNT'/' data/count

    # update the reward
    TITLE=$(echo "$EVENT" | jq -r '.reward.title' | tr '[:upper:]' '[:lower:]')
    REDEEMED_BY_ID=$(echo "$EVENT" | jq -r '.user_id')
    REDEEMED_BY_NAME=$(echo "$EVENT" | jq -r '.user_name')
    SCORE=0
    case $TITLE in
      first)
        NEW_TITLE="second"
        SCORE=5
        ;;

      second)
        NEW_TITLE="third"
        SCORE=3
        ;;

      third)
        if [[ "$MODE" == "checkin" ]]; then
          NEW_TITLE="checkin"
        else
          NEW_TITLE="first"
        fi
        SCORE=1
        ;;
    esac
    if [[ "$NEW_TITLE" != "$TITLE" ]]; then
      TWITCH_RESPONSE=$(curl -Ss -X PATCH 'https://api.twitch.tv/helix/channel_points/custom_rewards?broadcaster_id='$USER_ID'&id='$REWARD_ID \
      -H "Authorization: Bearer ${USER_ACCESS_TOKEN}" \
      -H "Client-Id: ${TWITCH_CLIENT_ID}" \
      -H 'Content-Type: application/json' \
      -d '{"title": "'$(change_case $CASE $NEW_TITLE)'"}')
    fi
    # special coppinger integration
    if [[ "$USER_ID" == "93766092" ]]; then
      TWITCH_RESPONSE="$(curl -Ss -X PATCH 'https://api.twitch.tv/helix/users?&id='$REDEEMED_BY_ID \
      -H "Authorization: Bearer ${USER_ACCESS_TOKEN}" \
      -H "Client-Id: ${TWITCH_CLIENT_ID}" \
      -H 'Content-Type: application/json')"
      PROFILE_IMAGE_URL="$(echo "$TWITCH_RESPONSE" | jq -r '.profile_image_url')"
      curl -Ss "$CHARLIE_WEBHOOK_URL" \
        -X POST \
        -H "Authorization: Pelion ${CHARLIE_WEBHOOK_SECRET}" \
        -H 'Content-Type: application/json' \
        -d '{
              "stream_id": '"$STREAM_ID"',
              "profile_image_url": "'"$PROFILE_IMAGE_URL"'",
              "user_id": "'"$REDEEMED_BY_ID"'",
              "user_name": "'"$REDEEMED_BY_NAME"'",
              "nth": '"$COUNT"'
            }' &>/dev/null &
    fi
    # increment points
    if [[ $SCORE -gt 0 ]]; then
      if CURRENT_SCORE=$(grep "^$REDEEMED_BY_ID " data/scores/$USER_ID); then
        CURRENT_SCORE=$(echo "$CURRENT_SCORE" | cut -d' ' -f2)
        CURRENT_SCORE=$(( CURRENT_SCORE + SCORE ))
        sed -i 's/^'$REDEEMED_BY_ID' .*$/'$REDEEMED_BY_ID' '$CURRENT_SCORE'/' data/scores/$USER_ID
      else
        printf "%s %s\n" "$REDEEMED_BY_ID" "$SCORE" >> data/scores/$USER_ID
      fi
    fi
    # update the username cache
    if grep -q "^$REDEEMED_BY_ID " data/username_cache; then
      sed -i 's/^'$REDEEMED_BY_ID' .*$/'$REDEEMED_BY_ID' '$REDEEMED_BY_NAME'/' data/username_cache
    else
      printf "%s %s\n" "$REDEEMED_BY_ID" "$REDEEMED_BY_NAME" >> data/username_cache
    fi
  fi
  return $(status_code 204)
fi
