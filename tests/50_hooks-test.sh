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
}

xafter() {
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
