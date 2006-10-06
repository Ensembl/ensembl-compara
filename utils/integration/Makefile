all:
	perl -I lib -I modules -MTest::Harness -e '$$Test::Harness::verbose=0; runtests @ARGV;' tests/*.t 

tasks:
	perl -I lib -I modules -MTest::Harness -e '$$Test::Harness::verbose=0; runtests @ARGV;' tests/*Task*.t 

noncheckout:
	perl -I lib -I modules -MTest::Harness -e '$$Test::Harness::verbose=0; runtests @ARGV;' tests/*TaskRollback*.t 

testtasks:
	perl -I lib -I modules -MTest::Harness -e '$$Test::Harness::verbose=0; runtests @ARGV;' tests/*Test*.t 

log:
	perl -I lib -I modules -MTest::Harness -e '$$Test::Harness::verbose=0; runtests @ARGV;' tests/*Log*.t 

integration:
	perl -I lib -I modules -MTest::Harness -e '$$Test::Harness::verbose=0; runtests @ARGV;' tests/*Integration*.t 
