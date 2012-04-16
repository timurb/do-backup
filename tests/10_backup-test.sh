#!./roundup/roundup

describe "Backup"

for path in '.' '..'; do
  if [ -x "${path}/do-backup" ]; then
    export BACKUP="${path}/do-backup"
    export FULLPATH="$(pwd)/${path}/do-backup"
    break
  fi
done

before() {
  WORKDIR=$(mktemp -d)
  SRC="$WORKDIR/src"
  DST="$WORKDIR/dst"
  ARCHIVENAME="files*.tgz"   # this is used only for checking the file created
                             # matches the output

  mkdir -p "$SRC/dir1" "$SRC/dir2" "$DST" "$WORKDIR/list"
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

  echo "$SRC" > "$WORKDIR/files-excl"
  echo "exclude:              $SRC/dir2" >> "$WORKDIR/files-excl"
  cp "$WORKDIR/files1" "$WORKDIR/list/files1.list"
  cp "$WORKDIR/files2" "$WORKDIR/list/files2.list"

  touch "$WORKDIR/files-empty"
}

after() {
  rm -rf "$WORKDIR"
}

it_displays_usage() {
  $BACKUP 2>&1 | grep -qi 'Usage'
}

it_produces_usage_about_l_param() {
  $BACKUP 2>&1 | grep -qi -- ' -l'
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

it_should_work_ok_when_run_from_some_other_dir() {
  cd /
  $FULLPATH -f "$WORKDIR/files" -d "$DST"
} 

it_accepts_l_switch_instead_of_f() {
  $BACKUP -l "$WORKDIR/list" -d "$DST"
}

it_fails_on_two_l_switches_specified() {
  ! $BACKUP -l "$WORKDIR/list" -l "$WORKDIR/list" -d "$DST"
}

it_fails_on_f_prior_to_l_switch() {
  ! $BACKUP -f "$WORKDIR/file" -l "$WORKDIR/list" -d "$DST"
}

it_accepts_f_after_l_switch() {
  $BACKUP -l "$WORKDIR/list" -f "$WORKDIR/files"  -d "$DST"
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

it_produces_a_message_when_destdir_not_found() {
  OUTPUT="$($BACKUP -f "$WORKDIR/files" -d /some/strange/path 2>&1 ||:)"
  echo $OUTPUT | grep -qi 'not found or not accessible'
}

it_creates_archive_in_destdir() {
  OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST")
  RESULT=$(find "$DST" -name "$ARCHIVENAME")
  test -n "$RESULT"
  test -e "$OUTPUT"
  test "$OUTPUT" = "$RESULT"
}

it_stripts_list_from_archive_name() {
  ! $BACKUP -l "$WORKDIR/list" -d "$DST" | grep -qi '.list-'
}

it_does_a_correct_backup() {
  OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST")
  tar -C "$DST" -xf $OUTPUT
  diff -r "$SRC" "$DST/$SRC" -q
}

it_fails_on_empty_list() {
  ! $BACKUP -f "$WORKDIR/files-empty" -d "$DST"
}

it_should_not_fail_on_empty_list_with_allow_empty_provided() {
  $BACKUP -f "$WORKDIR/files-empty" -d "$DST" --allow-empty
}

it_produces_usage_about_allow_empty_key() {
 $BACKUP 2>&1 | grep -qi "allow-empty"
}

it_honors_excludes() {
  OUTPUT=$($BACKUP -f "$WORKDIR/files-excl" -d "$DST")
  tar -C "$DST" -xf $OUTPUT
  rm -rf "$SRC/dir2"
  diff -r "$SRC" "$DST/$SRC" -q
}

it_backups_correctly_with_provided_several_f_params() {
  OUTPUT=$($BACKUP -f "$WORKDIR/files1" -f "$WORKDIR/files2" -d "$DST")
  mv "$SRC" "${SRC}1"
  mkdir "$SRC"
  cp -ar "${SRC}1/dir1" "$SRC"
  tar -C "$DST" -xf $(echo $OUTPUT | cut -f 1 -d' ')
  diff -r "$SRC" "$DST/$SRC" -q
  rm -rf "$DST/$SRC" "$SRC"
  mkdir "$SRC"
  cp -ar "${SRC}1/dir2" "$SRC"
  tar -C "$DST" -xf  $(echo $OUTPUT | cut -f 2 -d' ')
  diff -r "$SRC" "$DST/$SRC" -q
}

it_backups_correctly_with_provided_l_param() {
  OUTPUT=$($BACKUP -l "$WORKDIR/list" -d "$DST")
  mv "$SRC" "${SRC}1"
  mkdir "$SRC"
  cp -ar "${SRC}1/dir1" "$SRC"
  tar -C "$DST" -xf $(echo $OUTPUT | cut -f 1 -d' ')
  diff -r "$SRC" "$DST/$SRC" -q
  rm -rf "$DST/$SRC" "$SRC"
  mkdir "$SRC"
  cp -ar "${SRC}1/dir2" "$SRC"
  tar -C "$DST" -xf  $(echo $OUTPUT | cut -f 2 -d' ')
  diff -r "$SRC" "$DST/$SRC" -q
}

iit_accepts_several_lines_in_list() {
  OUTPUT=$($BACKUP -f "$WORKDIR/filesML" -d "$DST")
  tar -C "$DST" -xf $OUTPUT
  rm -rf "$SRC/one" "$SRC/two"
  diff -r "$SRC" "$DST/$SRC" -q
}

it_should_do_a_correct_backup_with_special_file_provided_as_an_input() {
  OUTPUT=$( cat "$WORKDIR/files" | $BACKUP -f /proc/self/fd/0 -d "$DST" | grep -v '/proc/self/fd/0' )
  tar -C "$DST" -xf $OUTPUT
  diff -r "$SRC" "$DST/$SRC" -q
}
