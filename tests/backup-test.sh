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
  FILELIST="$WORKDIR/$PREFIX"
  EXCLUDELIST="$WORKDIR/$PREFIX-excl"
  SRC="$WORKDIR/src"
  DST="$WORKDIR/dst"
  ARCHIVENAME="$PREFIX*.tgz"   # this might not prove very reliable but should be ok
                               # while we process only a single list

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
  echo "*exclude* $SRC/dir2" >> "$EXCLUDELIST"
}

after() {
  rm -rf "$WORKDIR"
}

it_displays_usage() {
  $BACKUP 2>&1 | grep -qi 'Usage'
}

it_exits_non_zero_on_usage() {
  ! $BACKUP
}

it_requires_f_switch() {
  ! $BACKUP -d "$DST"
}

it_requires_d_switch() {
  ! $BACKUP -f "$FILELIST"
}

it_exits_with_zero_after_successful_backup() {
  $BACKUP -f "$FILELIST" -d "$DST"
}

it_fails_on_unknown_options() {
  ! $BACKUP --some --strante --option -f "$FILELIST" -d "$DST"
}

it_fails_when_list_not_found() {
  ! $BACKUP -f /some/strange/path -d "$DST"
}

it_fails_when_destdir_not_found() {
  ! $BACKUP -f "$FILELIST" -d /some/strange/path
}

it_creates_archive_in_destdir() {
  $BACKUP -f "$FILELIST" -d "$DST"
  RESULT=$(find "$DST" -name $ARCHIVENAME)
  test -n "$RESULT"
}

it_does_a_correct_backup() {
  $BACKUP -f "$FILELIST" -d "$DST"
  tar -C "$DST" -xf $(find "$DST" -name "$ARCHIVENAME")
  diff -r "$SRC" "$DST/$SRC" -q
}

it_honors_excludes() {
  $BACKUP -f "$EXCLUDELIST" -d "$DST"
  tar -C "$DST" -xf $(find "$DST" -name "$ARCHIVENAME")
  rm -rf "$SRC/dir2"
  diff -r "$SRC" "$DST/$SRC" -q
}

it_accepts_several_f_params() {
  false
}

it_accepts_several_lines_in_list() {
  false
}
