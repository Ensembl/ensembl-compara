all:
	perl -I modules -MTest::Harness -e '$$Test::Harness::verbose=0; runtests @ARGV;' tests/blast/*.t tests/edoc/*.t tests/interface/*.t tests/tools/*.t 
