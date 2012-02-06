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
    aws --silent --simple "--secrets-file=$AWSSECRET" rm "$BUCKET/$(basename $file)"
  done ||:
}

it_should_produce_usage_about_rotation() {
  $BACKUP 2>&1 | grep -qi rotat
}

it_should_accept_key_for_rotation() {
  OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST" -r 10)
}

it_should_fail_on_nonpositive_number() {
  ! OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST" -r 0)
  ! OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST" -r -1)
  ! OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST" -r -10)
  ! OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST" -r blah)
}

it_should_rotate_local_archives() {
  FIRST=$($BACKUP -f "$WORKDIR/files" -d "$DST" -r 10)
  sleep 1
  SECOND=$($BACKUP -f "$WORKDIR/files" -d "$DST" -r 10)
  for x in 1 2 3 4 5 6 7 8 9; do
    sleep 1
    $BACKUP -f "$WORKDIR/files" -d "$DST" -r 10
  done
  test ! -e "$FIRST"
  test -e "$SECOND"
}

it_should_rotate_encrypted_archives() {
  echo "GPG keyring should be in $KEYRING"
  test -d "$KEYRING" -a -r "$KEYRING/pubring.gpg" -a -r "$KEYRING/secring.gpg"
  FIRST=$( GNUPGHOME="$KEYRING" $BACKUP -f "$WORKDIR/files" -d "$DST" -r 10 -e $KEY )
  sleep 1
  SECOND=$( GNUPGHOME="$KEYRING" $BACKUP -f "$WORKDIR/files" -d "$DST" -r 10 -e $KEY )
  for x in 1 2 3 4 5 6 7 8 9; do
    sleep 1
    GNUPGHOME="$KEYRING" $BACKUP -f "$WORKDIR/files" -d "$DST" -r 10 -e $KEY 
  done
  test ! -e "$FIRST"
  test -e "$SECOND"
}

it_should_rotate_uploaded_archives() {
  [ -r "$AWSSECRET" -a -r "$AWSBUCKET" ] || fail
  export BUCKET=$(cat $AWSBUCKET)

  FIRST=$( basename $( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" -r 5 ))
  # sleep 1   # this is not needed here as upload to S3 is quite lengthy
  SECOND=$( basename $( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" -r 5 ))
  CLEANUP="$FIRST $SECOND"
  for x in 1 2 3 4; do
    # sleep 1   # this is not needed here as upload to S3 is quite lengthy
    OUTPUT=$( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" -r 5 )
    CLEANUP="$CLEANUP $OUTPUT"
  done
  ! aws --silent --simple "--secrets-file=$AWSSECRET" ls "$BUCKET/$FIRST" | grep "$FIRST"
  aws --silent --simple "--secrets-file=$AWSSECRET" ls "$BUCKET/$SECOND" | grep "$SECOND"
  cleanup "$CLEANUP"
}
