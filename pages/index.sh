
source config.sh

source .secrets

HOST=${HTTP_HEADERS["host"]}
PROTOCOL="https://"
if [[ "$HOST" =~ "localhost"* ]]; then
  PROTOCOL="http://"
fi

load_cache

STREAMERS="$(cat data/rewards | cut -d' ' -f1)"

TABLE="<table>"
for STREAMER_ID in $STREAMERS; do
  TABLE+="<tr>"
  TABLE+="<td>"
  TABLE+="${USERNAME_CACHE[$STREAMER_ID]}"
  TABLE+="</td>"
  TABLE+="<td>"
  TABLE+="$(cut -d' ' -f2 data/scores/$STREAMER_ID | paste -sd+ | bc)"
  TABLE+="</td>"
  TABLE+="</tr>"
done
TABLE+="</table>"

htmx_page <<-EOF
  <h1 class="text-blue-500 text-4xl mt-3 mb-3">${PROJECT_NAME}</h1>
  <p>Be the first person to arrive in your favorite Twitch streamer's chat and win internet points!</p>
  <p>This is a blatant rip off of the idea at <a href="https://first.strager.net/">https://first.strager.net/</a>.</p>
  <h2>Leaderboard</h2>
  $TABLE
  <h2>Register</h2>
  <p>Are you a Twitch streamer? Add this to your own stream:</p>
  <a href="https://id.twitch.tv/oauth2/authorize?client_id=${TWITCH_CLIENT_ID}&response_type=code&scope=channel:read:redemptions%20channel:manage:redemptions&force_verify=true&redirect_uri=${PROTOCOL}${HOST}/oauth" class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">Connect</a>
EOF
