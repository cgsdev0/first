
source config.sh

declare -A USERNAME_CACHE
load_cache

declare -A VIEWER_SCORE_MAP
# get total score per viewer across all streamers
while read -r STREAMER_ID; do
  while read -r VIEWER_ID SCORE; do
    if [[ -v VIEWER_SCORE_MAP[$VIEWER_ID] ]]; then
      VIEWER_SCORE_MAP[$VIEWER_ID]=$((${VIEWER_SCORE_MAP[$VIEWER_ID]} + $SCORE))
    else
      VIEWER_SCORE_MAP[$VIEWER_ID]=$SCORE
    fi
  done < <(cat data/scores/$STREAMER_ID)
done < <(cat data/rewards | cut -d' ' -f1)

# sort then print
while read -r VIEWER_ID SCORE; do
  TABLE+="<tr>"
  TABLE+="<td>${USERNAME_CACHE[$VIEWER_ID]}</td>"
  TABLE+="<td>$SCORE</td>"
  TABLE+="</tr>"
done < <(for VIEWER_ID in ${!VIEWER_SCORE_MAP[@]}; do
  echo "$VIEWER_ID ${VIEWER_SCORE_MAP[$VIEWER_ID]}"
done | sort -nrk 2)

htmx_page <<-EOF
  <a href="/"><h1>${PROJECT_NAME}</h1></a>
  <h2>Viewer Leaderboard</h2>
  <table>
  <thead>
  <tr>
    <th>Viewer</th>
    <th>Score</th>
  </tr>
  </thead>
  <tbody>
  $TABLE
  </tbody>
  </table>
EOF
