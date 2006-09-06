all:
	perl -I modules -MTest::Harness -e '$$Test::Harness::verbose=0; runtests @ARGV;' tests/*.t tests/edoc/*.t
verbose:
	perl -I modules -MTest::Harness -e '$$Test::Harness::verbose=1; runtests @ARGV;' tests/*.t
