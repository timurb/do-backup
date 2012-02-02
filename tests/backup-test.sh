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
  EXCLUDELIST="$WORKDIR/$PREFIX-excl"
  SRC="$WORKDIR/src"
  DST="$WORKDIR/dst"
  ARCHIVENAME="files*.tgz"   # this might not prove very reliable but should be ok
                               # while we process only a single list
  ARCHIVENAME1="files1*.tgz"
  ARCHIVENAME2="files2*.tgz"
  ARCHIVENAMEML="filesML*.tgz"

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

  echo "$SRC" > "$WORKDIR/files"
  echo "$SRC/dir1" > "$WORKDIR/files1"
  echo "$SRC/dir2" > "$WORKDIR/files2"
  echo "$SRC/dir1" > "$WORKDIR/filesML"
  echo "$SRC/dir2" >> "$WORKDIR/filesML"

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
  ! $BACKUP -f "$WORKDIR/files"
}

it_exits_with_zero_after_successful_backup() {
  $BACKUP -f "$WORKDIR/files" -d "$DST"
}

it_fails_on_unknown_options() {
  ! $BACKUP --some --strante --option -f "$WORKDIR/files" -d "$DST"
}

it_fails_when_list_not_found() {
  ! $BACKUP -f /some/strange/path -d "$DST"
}

it_fails_when_destdir_not_found() {
  ! $BACKUP -f "$WORKDIR/files" -d /some/strange/path
}

it_creates_archive_in_destdir() {
  $BACKUP -f "$WORKDIR/files" -d "$DST"
  RESULT=$(find "$DST" -name "$ARCHIVENAME")
  test -n "$RESULT"
}

it_does_a_correct_backup() {
  $BACKUP -f "$WORKDIR/files" -d "$DST"
  tar -C "$DST" -xf $(find "$DST" -name "$ARCHIVENAME")
  diff -r "$SRC" "$DST/$SRC" -q
}

it_honors_excludes() {
  $BACKUP -f "$EXCLUDELIST" -d "$DST"
  tar -C "$DST" -xf $(find "$DST" -name "$ARCHIVENAME")
  rm -rf "$SRC/dir2"
  diff -r "$SRC" "$DST/$SRC" -q
}

it_backups_correctly_with_provided_several_f_params() {
  $BACKUP -f "$WORKDIR/files1" -f "$WORKDIR/files2" -d "$DST"
  mv "$SRC" "${SRC}1"
  mkdir "$SRC"
  cp -ar "${SRC}1/dir1" "$SRC"
  tar -C "$DST" -xf $(find "$DST" -name "$ARCHIVENAME1")
  diff -r "$SRC" "$DST/$SRC" -q
  rm -rf "$DST/$SRC" "$SRC"
  mkdir "$SRC"
  cp -ar "${SRC}1/dir2" "$SRC"
  tar -C "$DST" -xf $(find "$DST" -name "$ARCHIVENAME2")
  diff -r "$SRC" "$DST/$SRC" -q
}

it_accepts_several_lines_in_list() {
  $BACKUP -f "$WORKDIR/filesML" -d "$DST"
  tar -C "$DST" -xf $(find "$DST" -name "$ARCHIVENAME")
  rm -rf "$SRC/one" "$SRC/two"
  diff -r "$SRC" "$DST/$SRC" -q
}
