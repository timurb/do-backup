#!./roundup/roundup

describe "Compression"

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
  KEY='test'
  mkdir -p "$SRC" "$DST"
  echo 'file one' > "$SRC/one"
  echo "$SRC" > "$WORKDIR/files.common"
  for x in none tar gzip gz blah; do
    cp "$WORKDIR/files.common" "$WORKDIR/files.$x"
    echo "compress:$x" >> "$WORKDIR/files.$x"
  done
}

xafter() {
  rm -rf "$WORKDIR"
}

#  cleanup S3 after ourselves
cleanup() {
  [ -n "$1" ] && aws --silent --simple "--secrets-file=$AWSSECRET" rm "$BUCKET/$(basename $1)"  ||:
}

it_should_produce_usage_about_compression() {
  $BACKUP 2>&1 | grep -qi compress
}

it_should_not_fail_when_using_compression() {
  $BACKUP -f "$WORKDIR/files.tar" -d "$DST"
}

it_should_produce_error_about_unknown_compression_method(){
  ! $BACKUP -f "$WORKDIR/files.blah" -d "$DST"
}

it_should_produce_correct_tar_with_compression_set_to_none() {
  OUTPUT=$($BACKUP -f "$WORKDIR/files.none" -d "$DST")
  file -b "$OUTPUT" | grep -qi 'tar archive'
  tar -C "$DST" -xf "$OUTPUT"
  diff -r "$SRC" "$DST/$SRC" -q
}

it_should_produce_correct_tar_with_compression_set_to_tar() {
  OUTPUT=$($BACKUP -f "$WORKDIR/files.tar" -d "$DST")
  file -b "$OUTPUT" | grep -qi 'tar archive'
  tar -C "$DST" -xf "$OUTPUT"
  diff -r "$SRC" "$DST/$SRC" -q
}

it_should_produce_correct_gzip_with_compression_set_to_gzip() {
  OUTPUT=$($BACKUP -f "$WORKDIR/files.gzip" -d "$DST")
  file -b "$OUTPUT" | grep -qi 'gzip compressed'
  tar -C "$DST" -xf "$OUTPUT"
  diff -r "$SRC" "$DST/$SRC" -q
}

it_should_produce_correct_gzip_with_compression_set_to_gz() {
  OUTPUT=$($BACKUP -f "$WORKDIR/files.gz" -d "$DST")
  file -b "$OUTPUT" | grep -qi 'gzip compressed'
  tar -C "$DST" -xf "$OUTPUT"
  diff -r "$SRC" "$DST/$SRC" -q
}

it_should_encrypt_backup_with_compression_set_to_tar() {
  echo "GPG keyring should be in $KEYRING"
  test -d "$KEYRING" -a -r "$KEYRING/pubring.gpg" -a -r "$KEYRING/secring.gpg"
  OUTPUT=$( GNUPGHOME="$KEYRING" $BACKUP -f "$WORKDIR/files.tar" -d "$DST" -e "$KEY")
  echo dummy | $GPG -d $OUTPUT | tar -C "$DST" -x
  diff -r "$SRC" "$DST/$SRC" -q
}

it_should_encrypt_backup_with_compression_set_to_gzip() {
  echo "GPG keyring should be in $KEYRING"
  test -d "$KEYRING" -a -r "$KEYRING/pubring.gpg" -a -r "$KEYRING/secring.gpg"
  OUTPUT=$( GNUPGHOME="$KEYRING" $BACKUP -f "$WORKDIR/files.gzip" -d "$DST" -e "$KEY")
  echo dummy | $GPG -d $OUTPUT | tar -C "$DST" -zx
  diff -r "$SRC" "$DST/$SRC" -q
}

it_should_upload_archive_with_compression_set_to_tar() {
  OUTPUT=$( $BACKUP -f "$WORKDIR/files.tar" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" )
  rm -rf "$DST"
  mkdir "$DST"
  aws --silent --simple "--secrets-file=$AWSSECRET" get "$BUCKET/$(basename $OUTPUT)" "$DST/uploaded.tar"
  cleanup "$OUTPUT"
  tar -C "$DST" -xf "$DST/uploaded.tar"
  diff -r "$SRC" "$DST/$SRC" -q
}

it_should_upload_archive_with_compression_set_to_gzip() {
  OUTPUT=$( $BACKUP -f "$WORKDIR/files.gzip" -d "$DST" -u "$BUCKET" -s "$AWSSECRET" )
  rm -rf "$DST"
  mkdir "$DST"
  aws --silent --simple "--secrets-file=$AWSSECRET" get "$BUCKET/$(basename $OUTPUT)" "$DST/uploaded.tgz"
  cleanup "$OUTPUT"
  tar -C "$DST" -xf "$DST/uploaded.tgz"
  diff -r "$SRC" "$DST/$SRC" -q
}
