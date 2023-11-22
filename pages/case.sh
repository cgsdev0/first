
if [[ "$REQUEST_METHOD" != "POST" ]]; then
  return $(status_code 405)
fi

CASE="${FORM_DATA[case]}"
if [[ "$CASE" != "upper" ]] && [[ "$CASE" != "title" ]] && [[ "$CASE" != "lower" ]]; then
  echo "outta here with that"
  return $(status_code 400)
fi

SESSION[case]="$CASE"
debug "Changed case to ${SESSION[case]}"
save_session
