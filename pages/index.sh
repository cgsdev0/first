
source config.sh

source .secrets

HOST=${HTTP_HEADERS["host"]}
PROTOCOL="https://"
if [[ "$HOST" =~ "localhost"* ]]; then
  PROTOCOL="http://"
fi

declare -A USERNAME_CACHE
load_cache

while read -r STREAMER_ID SCORE; do
  if [[ "$SCORE" != "" ]]; then
    TABLE+="<tr>"
    TABLE+="<td><a href='/leaderboard/$STREAMER_ID'>${USERNAME_CACHE[$STREAMER_ID]}</a></td>"
    TABLE+="<td>$SCORE</td>"
    TABLE+="</tr>"
  fi
done < <(while read -r STREAMER_ID; do
  echo "$STREAMER_ID $(cut -d' ' -f2 data/scores/$STREAMER_ID | paste -sd+ | bc)"
done < <(cat data/rewards | cut -d' ' -f1) | sort -nrk 2 )

htmx_page <<-EOF
  <h1>${PROJECT_NAME}</h1>
  <p>Be the first person to arrive in your favorite Twitch streamer's chat and win internet points!</p>
  <p>This is a blatant rip off of the idea at <a href="https://first.strager.net/">https://first.strager.net/</a>.</p>
  <h2>Leaderboard</h2>
  <table>
  <thead>
  <tr>
    <th>Streamer</th>
    <th>Score</th>
  </tr>
  </thead>
  <tbody>
  $TABLE
  </tbody>
  </table>
  <h2>Register</h2>
  <p>Are you a Twitch streamer? Add this to your own stream:</p>
  <a href="https://id.twitch.tv/oauth2/authorize?client_id=${TWITCH_CLIENT_ID}&response_type=code&scope=channel:read:redemptions%20channel:manage:redemptions&force_verify=true&redirect_uri=${PROTOCOL}${HOST}/oauth" class="bg-blue-500 hover:bg-blue-700 text-white inline-block font-bold py-2 px-4 rounded">Connect</a>
EOF
