do-backup
=======================

Description
-----------

This is a tool to do backups.
It stores specified files in tar archive and optionally:

* compresses it
* encrypts it
* uploads to S3
* rotates locally
* rotates remotely

Besides it can:

* exclude specified files from an archive
* run pre and post hooks

Why one more of them?
---------------------
I needed a tool for myself to do backups.
It had to be simple, reliable, easily scriptable, and having few dependencies.

To esure that I've written a bunch of unit tests.
You can run them by:   sh ./run-tests.sh
First run can take up to 15min.
You need submodules initialized to do that.

Installation
------------

git clone git@github.com:timurbatyrshin/do-backup.git --update

Notice the --update key.


Requirements
------------

* AWS tool by Timothy Kay (https://github.com/timkay/aws) should be placed
somewhere in $PATH.
* Libshell (https://github.com/timurbatyrshin/libshell) should be placed in 
the same dir as do-backup (in libshell/ subdir)


Usage
-----

    do-backup -f FILE -d DESTDIR [OPTIONS]

    Switches:
      -f, --file FILE
          Files/dirs to backup should be listed in FILE one per line.
          Lines starting with 'exclude:' specify locations to exclude from backup.
          Lines starting with 'pre:' and 'post:' specify shell commands to run
          before and after backup running.
          Lines starting with 'compress:' specify which kind of compression to
          apply to archive. Possible values: tar, gzip. Default: gzip

          Several -f switches can be specified in which case several archives
          will be created.
      -l, --list DIR   
          You can instead place the files specified above into a single dir,
          name them as *.list and pass this dir's name as a param to --list key.
      -d, --destdir DESTDIR
          a target dir to put archive into
      -e, --encrypt KEY
          encrypt backup with specified GPG key
      -u, --upload BUCKET
          upload archive to S3 bucket
      -r, --rotate NUMBER
          keep NUMBER of last archives.  This applies both to local storage and to S3
      --lr, --local-rotate NUMBER
          The same as -r but for local archives only
      --rr, --remote-rotate NUMBER
          The same as -r but for remote archives only
          These two keys, -lr and -rr override -r

Troubleshooting
---------------

* Can't open ./libshell/shell-getopt
This means libshell should be checked out in ./libshell/ relating to do-backup
If you run do-backup from inside git repo you can use the following command
to fix that:
  git submodule update --init

* run-tests.sh: 3: tests/roundup/roundup.sh: not found
Update submodules (see above)

* Place AWS credentials to tests/awssecret in order to run S3 upload tests.
This means tests of uploading to S3 were not run. Do as messages suggests.

* ./do-backup: 172: aws: not found
Place aws command (https://github.com/timkay/aws) somewhere in $PATH

Contributions
-------------

# Write some tests.
# Add some code.
# Send me a pull request.

License
-------
MIT
