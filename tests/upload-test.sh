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

it_should_produce_usage_about_uploads() {
  $BACKUP 2>&1 | grep -qi upload
}

it_should_accepts_upload_switch() {
  false
}

it_should_exit_with_zero_on_upload() {
  false
}

it_should_upload_archive_correctly() {
  false
}

it_should_be_able_to_upload_encrypted_archive() {
 false
}

it_should_be_able_to_upload_encrypted_archive_correctly() {
 false
}
