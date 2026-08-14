
if [[ "$REQUEST_METHOD" != "GET" ]]; then
  return $(status_code 405)
fi

CASE="${QUERY_PARAMS[case]}"
if [[ "$CASE" != "upper" ]] && [[ "$CASE" != "title" ]] && [[ "$CASE" != "lower" ]]; then
  echo "outta here with that"
  return $(status_code 400)
fi

SESSION[case]="$CASE"
save_session
