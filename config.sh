PROJECT_NAME=first
TAILWIND=on
ENABLE_SESSIONS=true

touch data/rewards
touch data/case
touch data/mode
touch data/count
touch data/refresh_tokens
touch data/username_cache
mkdir -p data/scores

function load_cache() {
  local USER_ID
  local USER_NAME
  while read -r USER_ID USER_NAME; do
    USERNAME_CACHE[$USER_ID]=$USER_NAME
  done < data/username_cache
}
export -f load_cache

function change_case() {
  local CASE
  CASE=$1
  shift
  if [[ "$CASE" == "upper" ]]; then
    echo "${1^^}"
  elif [[ "$CASE" == "title" ]]; then
    echo "${1^}"
  else
    echo "$1"
  fi
}

export -f change_case
