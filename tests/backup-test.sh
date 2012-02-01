#!./roundup/roundup

describe "Backup"

for path in '.' '..'; do
  if [ -x "${path}/do-backup" ]; then
    export BACKUP="${path}/do-backup"
    break
  fi
done

before() {
  WORKDIR=$(mktemp -d)
  PREFIX='files'
  EXT='tgz'
  FILELIST="$WORKDIR/$PREFIX"
  EXCLUDELIST="$WORKDIR/$PREFIX-excl"
  SRC="$WORKDIR/src"
  DST="$WORKDIR/dst"
  ARCHIVENAME="$PREFIX*.$EXT"  # this might not prove reliable but should be ok
                               # while we process only single list

  mkdir -p "$SRC/dir1" "$SRC/dir2" "$DST"
  echo 'file one' > "$SRC/one"
  cat << EOF > "$SRC/two"
this
is
a
file
two
EOF
  echo 'file 3' > "$SRC/dir1/three"
  echo 'file 4' > "$SRC/dir2/for"

  echo "$SRC" > "$FILELIST"

  echo "$SRC" > "$EXCLUDELIST"
  echo "*excludes* $SRC/dir2" > "$EXCLUDELIST"
}

after() {
  rm -rf "$WORKDIR"
}

it_displays_usage() {
  "$BACKUP" 2>&1 | grep -qi 'Usage'
}

it_exits_non_zero_when_not_run() {
  ! "$BACKUP"
}

it_exits_with_zero_after_successful_backup() {
  "$BACKUP" -f "$FILELIST"
}

it_fails_on_unknown_options() {
  ! "$BACKUP" --some --strante --option
}

it_fails_when_list_not_found() {
  ! "$BACKUP" -f /some/strange/path
}

it_places_archive_to_currentdir_when_destdir_not_specified() {
  "$BACKUP" -f "$FILELIST"
  RESULT=$(find . -name $ARCHIVENAME)
  test -n "$RESULT"
}

it_places_archive_to_destdir() {
  "$BACKUP" -f "$FILELIST" -d "$DST"
  RESULT=$(find "$DST" -name $ARCHIVENAME)
  test -n "$RESULT"
}

it_does_a_correct_backup() {
  "$BACKUP" -f "$FILELIST" -d "$DST"
  tar -C "$DST" -xf $(find "$DST" -name "$ARCHIVENAME")
  diff -r "$SRC" "$DST" -q
}

it_honors_excludes() {
  "$BACKUP" -f "$EXCLUDELIST" -d "$DST"
  tar -C "$DST" -xf $(find "$DST" -name "$ARCHIVENAME")
  rm -rf "$SRC/dir2"
  diff -r "$SRC" "$DST" -q
}
