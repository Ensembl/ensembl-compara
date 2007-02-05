all:
	perl -I modules -I lib -MTest::Harness -e '$$Test::Harness::verbose=0; runtests @ARGV;' tests/blast/*.t tests/edoc/*.t tests/interface/*.t tests/tools/*.t 

user:
	perl -I modules -I ensembl -I conf -I lib -MTest::Harness -e '$$Test::Harness::verbose=0; runtests @ARGV;' tests/user/*.t

data:
	perl -I conf -I ensembl -I ensembl-draw -I modules -I ensembl -I conf -I lib -I mock_modules -MTest::Harness -e '$$Test::Harness::verbose=0; runtests @ARGV;' tests/data/*.t 

mock:
	perl -I modules -I ensembl -I conf -I mock_modules -I lib -MTest::Harness -e '$$Test::Harness::verbose=0; runtests @ARGV;' tests/mock/*.t
