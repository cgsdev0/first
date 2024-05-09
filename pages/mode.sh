
if [[ "$REQUEST_METHOD" != "POST" ]]; then
  return $(status_code 405)
fi

MODE="${FORM_DATA[mode]}"
if [[ "$MODE" != "legacy" ]] && [[ "$MODE" != "checkin" ]]; then
  echo "outta here with that"
  return $(status_code 400)
fi

SESSION[mode]="$MODE"
save_session
