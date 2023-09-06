PROJECT_NAME=first
TAILWIND=on

touch data/rewards
touch data/refresh_tokens
touch data/username_cache
mkdir -p data/scores

function load_cache() {
  declare -A USERNAME_CACHE
  local USER_ID
  local USER_NAME
  while IFS= read -r USER_ID USER_NAME; do
    USERNAME_CACHE[$USER_ID]=$USER_NAME
  done < data/username_cache
}
export -f load_cache
