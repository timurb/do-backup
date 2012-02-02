#!./roundup/roundup

describe "Encryption"

for path in '.' '..'; do
  if [ -x "${path}/do-backup" ]; then
    export BACKUP="${path}/do-backup"
    export KEYRING="${path}/tests/keyring"
    export GPG="gpg -q --homedir=${KEYRING} --no-permission-warning --batch"
    break
  fi
done

create_keyring() {
  rm -rf "$KEYRING" 2>&1 > /dev/null ||:
  mkdir "$KEYRING" 2>&1 > /dev/null ||:
  cat <<EOF | $GPG --gen-key
%echo Generating a key for testing of backups encryption
%echo This might take a minute or a couple and needs to be done only once.
Key-Type: RSA
Key-Usage: encrypt,sign,auth
Key-Length: 1024
Name-Real: test key
Name-Email: foo@bar.baz
Expire-Date: 0
%commit
%echo done
EOF
}

before() {
  [ -d "$KEYRING" -a -r "$KEYRING/pubring.gpg" -a -r "$KEYRING/secring.gpg" ] || create_keyring

  WORKDIR=$(mktemp -d)
  PREFIX='files'
  FILELIST="$WORKDIR/$PREFIX"
  SRC="$WORKDIR/src"
  DST="$WORKDIR/dst"
  ARCHIVENAME="$PREFIX*.gpg"   # this might not prove reliable but should be ok
                               # while we process only single list
  KEY='test'

  mkdir -p "$SRC" "$DST"
  echo 'file one' > "$SRC/one"
  echo "$SRC" > "$FILELIST"
}

after() {
  rm -rf "$WORKDIR"
}

it_should_produce_usage_about_encryption() {
  $BACKUP 2>&1 | grep -qi encrypt
}

it_should_not_fail_when_encrypting() {
  GNUPGHOME="$KEYRING" $BACKUP -f "$FILELIST" -d "$DST" -e $KEY
}

it_creates_encrypted_archive_in_destdir() {
  GNUPGHOME="$KEYRING" $BACKUP -f "$FILELIST" -d "$DST" -e $KEY
  RESULT=$(find "$DST" -name $ARCHIVENAME)
  test -n "$RESULT"
}

it_should_encrypt_correctly() {
  GNUPGHOME="$KEYRING" $BACKUP -f "$FILELIST" -d "$DST" -e $KEY
  echo dummy | $GPG -d $(find "$DST" -name "$ARCHIVENAME") | tar -C "$DST" -zx
  diff -r "$SRC" "$DST/$SRC" -q
}
