#!./roundup/roundup

describe "Hooks"

for path in '.' '..'; do
  if [ -x "${path}/do-backup" ]; then
    export BACKUP="${path}/do-backup"
    break
  fi
done

before() {
  WORKDIR=$(mktemp -d)
  SRC="$WORKDIR/src"
  DST="$WORKDIR/dst"
  PRE="$WORKDIR/pre"
  POST="$WORKDIR/post"
  ARCHIVENAME="files*.tgz"   # this might not prove reliable but should be ok
                             # while we process only single list
  mkdir -p "$SRC" "$DST"
  echo 'file one' > "$SRC/one"
  echo "$SRC" > "$WORKDIR/files"
  echo "pre: touch $PRE" >> "$WORKDIR/files"
  echo "pre: touch $PRE-1" >> "$WORKDIR/files"
  echo "post: touch $POST" >> "$WORKDIR/files"
  echo "post: touch $POST-1" >> "$WORKDIR/files"

  cp "$WORKDIR/files" "$WORKDIR/files-fail-pre"
  echo "pre: /bin/false" >> "$WORKDIR/files-fail-pre"
  echo "pre: touch $PRE-2" >> "$WORKDIR/files-fail-pre"

  cp "$WORKDIR/files" "$WORKDIR/files-fail-post"
  echo "post: /bin/false" >> "$WORKDIR/files-fail-post"
  echo "post: touch $POST-2" >> "$WORKDIR/files-fail-post"

  echo "$SRC" > "$WORKDIR/files-mixed"
  echo "post: touch $POST" >> "$WORKDIR/files-mixed"
  echo "pre: touch $PRE" >> "$WORKDIR/files-mixed"
  echo "post: touch $POST-1" >> "$WORKDIR/files-mixed"
  echo "pre: touch $PRE-1" >> "$WORKDIR/files-mixed"
  echo "post: touch $POST-2" >> "$WORKDIR/files-mixed"

  echo "pre: touch $PRE" >> "$WORKDIR/files-empty"
  echo "pre: touch $PRE-1" >> "$WORKDIR/files-empty"
  echo "post: touch $POST" >> "$WORKDIR/files-empty"
  echo "post: touch $POST-1" >> "$WORKDIR/files-empty"
}

after() {
  rm -rf "$WORKDIR"
}

it_should_not_fail_when_using_hooks() {
  $BACKUP -f "$WORKDIR/files" -d "$DST"
}

it_should_run_pre_hooks() {
  $BACKUP -f "$WORKDIR/files" -d "$DST"
  test -e "$PRE"
  test -e "$PRE-1"
}

it_should_run_post_hooks() {
  $BACKUP -f "$WORKDIR/files" -d "$DST"
  test -e "$POST"
  test -e "$POST-1"
}

it_should_create_archives_when_running_hooks() {
  OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST")
  test -e $OUTPUT
}

it_should_run_both_pre_and_post_hooks_when_they_are_specified_in_mixed_order() {
  $BACKUP -f "$WORKDIR/files-mixed" -d "$DST"
  test -e "$PRE"
  test -e "$PRE-1"
  test -e "$POST"
  test -e "$POST-1"
  test -e "$POST-2"
}

it_should_fail_on_failing_hooks() {
  ! $BACKUP -f "$WORKDIR/files-fail-pre" -d "$DST"
  ! $BACKUP -f "$WORKDIR/files-fail-post" -d "$DST"
}

it_should_fail_on_first_failing_pre_hook() {
  $BACKUP -f "$WORKDIR/files-fail-pre" -d "$DST" ||:
  [ ! -e "$PRE-2" ]
}

it_should_fail_on_first_failing_post_hook() {
  $BACKUP -f "$WORKDIR/files-fail-post" -d "$DST" ||:
  [ ! -e "$POST-2" ]
}

it_should_not_produce_backups_on_failing_pre_hooks() {
  $BACKUP -f "$WORKDIR/files-fail-pre" -d "$DST" ||:
  RESULT=$(find "$DST" -name "$ARCHIVENAME")
  [ -z "$RESULT" ]
}

it_should_run_pre_and_post_hooks_when_using_empty_list_with_allow_empty() {
  $BACKUP -f "$WORKDIR/files-empty" -d "$DST" --allow-empty
  test -e "$PRE"
  test -e "$PRE-1"
  test -e "$POST"
  test -e "$POST-1"
}
