#!./roundup/roundup

describe "Rotation"

fail() {
  echo "Place AWS credentials to tests/awssecret in order to run S3 upload tests." > /dev/stderr
  echo "Place AWS bucket name to tests/awsbucket." > /dev/stderr
  echo "That user should have full access to specified bucket" > /dev/stderr
  exit
}

for path in '.' '..'; do
  if [ -x "${path}/do-backup" ]; then
    export BACKUP="${path}/do-backup"
    export AWSSECRET="${path}/tests/awssecret"
    export AWSBUCKET="${path}/tests/awsbucket"
    export KEYRING="${path}/tests/keyring"
    export GPG="gpg -q --homedir=${KEYRING} --no-permission-warning --batch"
    break
  fi
done

# AWS Setup to avoid trashing ones data
export AWS_CALLING_FORMAT="SUBDOMAIN"
unset AWS_CREDENTIAL_FILE
unset AWS_SECRET_ACCESS_KEY
unset AWS_ACCESS_KEY_ID
unset EC2_PRIVATE_KEY
unset EC2_CERT

before() {
  WORKDIR=$(mktemp -d)
  FILELIST="$WORKDIR/files"
  SRC="$WORKDIR/src"
  DST="$WORKDIR/dst"
  KEY='test'
  ROTATE=10
  mkdir -p "$SRC" "$DST"
  echo 'file one' > "$SRC/one"
  echo "$SRC" > "$FILELIST"
}

after() {
  rm -rf "$WORKDIR"
}

#  cleanup S3 after ourselves
cleanup() {
  [ -n "$1" ] && for file in $(echo "$@"); do
    aws --silent --simple "--secrets-file=$AWSSECRET" rm "$BUCKET/$file"
  done ||:
}

it_should_produce_usage_about_rotation() {
  $BACKUP 2>&1 | grep -qi rotat
}

it_should_produce_usage_about_detailed_rotation_keys() {
  $BACKUP 2>&1 | grep -i rotat | egrep -qi '(local|remot)'
}

it_should_accept_key_for_rotation() {
  OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST" -r 10)
}

it_should_accept_lr_and_rr_keys_for_rotation() {
  OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST" --lr 10 --rr 20 )
}

it_should_fail_on_nonpositive_number() {
  ! OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST" -r 0)
  ! OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST" -r -1)
  ! OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST" -r -10)
  ! OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST" -r blah)
}

it_should_rotate_local_archives() {
  FIRST=$($BACKUP -f "$WORKDIR/files" -d "$DST" -r "$ROTATE")
  sleep 1
  SECOND=$($BACKUP -f "$WORKDIR/files" -d "$DST" -r "$ROTATE")
  for x in $(seq $(( $ROTATE - 1)) ); do
    sleep 1
    $BACKUP -f "$WORKDIR/files" -d "$DST" -r "$ROTATE"
  done
  test ! -e "$FIRST"
  test -e "$SECOND"
}

it_should_rotate_local_archives_through_lr_switch() {
  FIRST=$($BACKUP -f "$WORKDIR/files" -d "$DST" --lr "$ROTATE")
  sleep 1
  SECOND=$($BACKUP -f "$WORKDIR/files" -d "$DST" --lr "$ROTATE")
  for x in $(seq $(( $ROTATE - 1)) ); do
    sleep 1
    $BACKUP -f "$WORKDIR/files" -d "$DST" --lr "$ROTATE"
  done
  test ! -e "$FIRST"
  test -e "$SECOND"
}

it_should_override_r_switch_by_lr() {
  FIRST=$($BACKUP -f "$WORKDIR/files" -d "$DST" --lr "$ROTATE" -r 1)
  sleep 1
  SECOND=$($BACKUP -f "$WORKDIR/files" -d "$DST" --lr "$ROTATE" -r 1)
  for x in $(seq $(( $ROTATE - 1)) ); do
    sleep 1
    $BACKUP -f "$WORKDIR/files" -d "$DST" --lr "$ROTATE" -r 1
  done
  test ! -e "$FIRST"
  test -e "$SECOND"
}

it_should_rotate_encrypted_archives() {
  echo "GPG keyring should be in $KEYRING"
  test -d "$KEYRING" -a -r "$KEYRING/pubring.gpg" -a -r "$KEYRING/secring.gpg"
  FIRST=$( GNUPGHOME="$KEYRING" $BACKUP -f "$WORKDIR/files" -d "$DST" -r "$ROTATE" -e $KEY )
  sleep 1
  SECOND=$( GNUPGHOME="$KEYRING" $BACKUP -f "$WORKDIR/files" -d "$DST" -r "$ROTATE" -e $KEY )
  for x in $(seq $(( $ROTATE - 1)) ); do
    sleep 1
    GNUPGHOME="$KEYRING" $BACKUP -f "$WORKDIR/files" -d "$DST" -r "$ROTATE" -e $KEY 
  done
  test ! -e "$FIRST"
  test -e "$SECOND"
}

it_should_rotate_uploaded_archives() {
  [ -r "$AWSSECRET" -a -r "$AWSBUCKET" ] || fail
  export BUCKET=$(cat $AWSBUCKET)

  FIRST=$( basename $( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" -r "$ROTATE" ))
  # sleep 1   # this is not needed here as upload to S3 is quite lengthy
  SECOND=$( basename $( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" -r "$ROTATE" ))
  CLEANUP="$(basename "$FIRST") $(basename "$SECOND")"
  for x in $(seq $(( $ROTATE - 1)) ); do
    # sleep 1   # this is not needed here as upload to S3 is quite lengthy
    OUTPUT=$( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" -r "$ROTATE" )
    CLEANUP="$CLEANUP $(basename "$OUTPUT")"
  done
  [ -z "$(aws --silent --simple "--secrets-file=$AWSSECRET" ls "$BUCKET/$FIRST")" ]
  [ -n "$(aws --silent --simple "--secrets-file=$AWSSECRET" ls "$BUCKET/$SECOND")" ]
  cleanup "$CLEANUP"
}

it_should_rotate_uploaded_archives_when_using_prefix() {
  [ -r "$AWSSECRET" -a -r "$AWSBUCKET" ] || fail
  export BUCKET=$(cat $AWSBUCKET)

  FIRST=$( basename $( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET/prefix" -s "$AWSSECRET" -r "$ROTATE" ))
  # sleep 1   # this is not needed here as upload to S3 is quite lengthy
  SECOND=$( basename $( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET/prefix" -s "$AWSSECRET" -r "$ROTATE" ))
  CLEANUP="prefix/$FIRST prefix/$SECOND"
  for x in $(seq $(( $ROTATE - 1)) ); do
    # sleep 1   # this is not needed here as upload to S3 is quite lengthy
    OUTPUT=$( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET/prefix" -s "$AWSSECRET" -r "$ROTATE" )
    CLEANUP="$CLEANUP prefix/$(basename "$OUTPUT")"
  done
  ! aws --silent --simple "--secrets-file=$AWSSECRET" ls "$BUCKET/prefix/$FIRST" | grep "$FIRST"
  aws --silent --simple "--secrets-file=$AWSSECRET" ls "$BUCKET/prefix/$SECOND" | grep "$SECOND"
  cleanup "$CLEANUP"
}

it_should_rotate_uploaded_archives_through_rr_switch() {
  [ -r "$AWSSECRET" -a -r "$AWSBUCKET" ] || fail
  export BUCKET=$(cat $AWSBUCKET)

  FIRST=$( basename $( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" --rr "$ROTATE" ))
  # sleep 1   # this is not needed here as upload to S3 is quite lengthy
  SECOND=$( basename $( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" --rr "$ROTATE" ))
  CLEANUP="$(basename "$FIRST") $(basename "$SECOND")"
  for x in $(seq $(( $ROTATE - 1)) ); do
    # sleep 1   # this is not needed here as upload to S3 is quite lengthy
    OUTPUT=$( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" --rr "$ROTATE" )
    CLEANUP="$CLEANUP $(basename "$OUTPUT")"
  done
  ! aws --silent --simple "--secrets-file=$AWSSECRET" ls "$BUCKET/$FIRST" | grep "$FIRST"
  aws --silent --simple "--secrets-file=$AWSSECRET" ls "$BUCKET/$SECOND" | grep "$SECOND"
  cleanup "$CLEANUP"
}

it_should_override_r_switch_by_rr() {
  [ -r "$AWSSECRET" -a -r "$AWSBUCKET" ] || fail
  export BUCKET=$(cat $AWSBUCKET)

  FIRST=$( basename $( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" --rr "$ROTATE" -r 1 ))
  # sleep 1   # this is not needed here as upload to S3 is quite lengthy
  SECOND=$( basename $( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" --rr "$ROTATE" -r 1 ))
  CLEANUP="$(basename "$FIRST") $(basename "$SECOND")"
  for x in $(seq $(( $ROTATE - 1)) ); do
    # sleep 1   # this is not needed here as upload to S3 is quite lengthy
    OUTPUT=$( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" --rr "$ROTATE" -r 1 )
    CLEANUP="$CLEANUP $(basename "$OUTPUT")"
  done
  ! aws --silent --simple "--secrets-file=$AWSSECRET" ls "$BUCKET/$FIRST" | grep "$FIRST"
  aws --silent --simple "--secrets-file=$AWSSECRET" ls "$BUCKET/$SECOND" | grep "$SECOND"
  cleanup "$CLEANUP"
}

it_should_treat_lr_and_rr_switches_differently() {
  [ -r "$AWSSECRET" -a -r "$AWSBUCKET" ] || fail
  export BUCKET=$(cat $AWSBUCKET)

  FIRST=$( basename $( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" --rr "$ROTATE" --lr "$(( $ROTATE - 1))"))
  # sleep 1   # this is not needed here as upload to S3 is quite lengthy
  SECOND=$( basename $( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" --rr "$ROTATE" --lr "$(( $ROTATE - 1))"))
  CLEANUP="$(basename "$FIRST") $(basename "$SECOND")"
  for x in $(seq $(( $ROTATE - 1)) ); do
    # sleep 1   # this is not needed here as upload to S3 is quite lengthy
    OUTPUT=$( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" --rr "$ROTATE" --lr "$(( $ROTATE - 1))")
    CLEANUP="$CLEANUP $(basename "$OUTPUT")"
  done
  ! aws --silent --simple "--secrets-file=$AWSSECRET" ls "$BUCKET/$FIRST" | grep "$FIRST"
  aws --silent --simple "--secrets-file=$AWSSECRET" ls "$BUCKET/$SECOND" | grep "$SECOND"
  test ! -e "$FIRST"
  test ! -e "$SECOND"
  cleanup "$CLEANUP"
}

it_should_produce_warning_on_stderr_on_rotation_with_special_files() {
  cat "$WORKDIR/files" | $BACKUP -f /proc/self/fd/0 -d "$DST" -r "$ROTATE" 2>&1 > /dev/null | grep -qi warning
}

it_should_not_produce_warning_on_stdout_on_rotation_with_special_files() {
  ! (cat "$WORKDIR/files" | $BACKUP -f /proc/self/fd/0 -d "$DST" -r "$ROTATE" | grep -qi warning )
}

it_should_do_a_correct_backup_with_special_file_provided_as_an_input_and_rotation_enabled() {
  OUTPUT=$( cat "$WORKDIR/files" | $BACKUP -f /proc/self/fd/0 -d "$DST" -r "$ROTATE" | grep -v '/proc/self/fd/0' )
  tar -C "$DST" -xf $OUTPUT
  diff -r "$SRC" "$DST/$SRC" -q
}
