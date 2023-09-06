
USER_ID="${PATH_VARS[user_id]//[!0-9]/}"

source config.sh

declare -A USERNAME_CACHE
load_cache

while read -r STREAMER_ID SCORE; do
  TABLE+="<tr>"
  TABLE+="<td>${USERNAME_CACHE[$STREAMER_ID]}</td>"
  TABLE+="<td>$SCORE</td>"
  TABLE+="</tr>"
done < <(sort -nrk 2 data/scores/$USER_ID)

htmx_page <<-EOF
  <a href="/"><h1>${PROJECT_NAME}</h1></a>
  <h2>Leaderboard for ${USERNAME_CACHE[$USER_ID]}</h2>
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
EOF
