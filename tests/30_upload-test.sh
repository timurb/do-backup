#!./roundup/roundup

describe "Upload"

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

[ -r "$AWSSECRET" -a -r "$AWSBUCKET" ] || fail
export BUCKET=$(cat $AWSBUCKET)

before() {
  WORKDIR=$(mktemp -d)
  FILELIST="$WORKDIR/files"
  SRC="$WORKDIR/src"
  DST="$WORKDIR/dst"
  BADSECRET="$WORKDIR/badsecret"
  KEY='test'
  mkdir -p "$SRC" "$DST"
  echo 'file one' > "$SRC/one"
  echo "$SRC" > "$FILELIST"
  cat $AWSSECRET |sed 's,$,blah,' > "$BADSECRET"
}

after() {
  rm -rf "$WORKDIR"
}

#  cleanup S3 after ourselves
cleanup() {
  [ -n "$1" ] && aws --silent --simple "--secrets-file=$AWSSECRET" rm "$BUCKET/$(basename $1)"  ||:
}

it_should_produce_usage_about_uploads() {
  $BACKUP 2>&1 | grep -qi upload
}

it_should_produce_usage_about_secrets_file() {
  $BACKUP 2>&1 | grep -qi secret
}

it_should_exit_with_zero_on_successful_upload() {
  OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET")
  cleanup "$OUTPUT"
}

it_should_fail_on_uploading_to_unexistant_bucket(){
  ! OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST" -u "very-wrong-$BUCKET-name" -s "$AWSSECRET")
}

it_should_fail_on_uploading_with_wrong_credentials(){
  ! OUTPUT=$($BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$BADSECRET")
}

it_should_upload_archive_correctly() {
  OUTPUT=$( $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" )
  rm -rf "$DST"
  mkdir "$DST"
  aws --silent --simple "--secrets-file=$AWSSECRET" get "$BUCKET/$(basename $OUTPUT)" "$DST/uploaded.tgz"
  cleanup "$OUTPUT"
  tar -C "$DST" -xf "$DST/uploaded.tgz"
  diff -r "$SRC" "$DST/$SRC" -q
}

it_should_be_able_to_upload_encrypted_archive() {
  echo "GPG keyring should be in $KEYRING"
  test -d "$KEYRING" -a -r "$KEYRING/pubring.gpg" -a -r "$KEYRING/secring.gpg"
  OUTPUT=$( GNUPGHOME="$KEYRING" $BACKUP -f "$WORKDIR/files" -d "$DST" -e $KEY -u "$BUCKET" -s "$AWSSECRET" )
  cleanup "$OUTPUT"
}

it_should_be_able_to_upload_encrypted_archive_correctly() {
  echo "GPG keyring should be in $KEYRING"
  test -d "$KEYRING" -a -r "$KEYRING/pubring.gpg" -a -r "$KEYRING/secring.gpg"
  OUTPUT=$( GNUPGHOME="$KEYRING" $BACKUP -f "$WORKDIR/files" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" -e $KEY)
  rm -rf "$DST"
  mkdir "$DST"
  aws --silent --simple "--secrets-file=$AWSSECRET" get "$BUCKET/$(basename $OUTPUT)" "$DST/uploaded.gpg"
  cleanup "$OUTPUT"
  echo dummy | $GPG -d "$DST/uploaded.gpg" | tar -C "$DST" -zx
  diff -r "$SRC" "$DST/$SRC" -q
}
