# $Id: 
#!/usr/local/bin/perl

use strict;
use Getopt::Long;
use Class::Inspector;
use FindBin qw($Bin);
use vars qw( $SERVERROOT );
use LWP::UserAgent;

BEGIN {
  $SERVERROOT = "$Bin/../..";
  unshift @INC,"$SERVERROOT/public-plugins/selenium/modules";  
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;    
}

# check to see if the selenium server is online(URL returns OK if server is online).
my $ua = LWP::UserAgent->new(keep_alive => 5, env_proxy => 1);
$ua->timeout(10);
my $response = $ua->get("http://172.20.10.187:4444/selenium-server/driver/?cmd=testComplete");
if($response->content ne 'OK') { print "\nSelenium Server is offline !!!!\n";exit;}

my $module;
my $url = 'http://test.ensembl.org';
my $host = '172.20.10.187';#'localhost'; 
my $port = '4444';
my $browser = '*firefox';
my $test;
my $skip;
my $verbose;
my $species;
my $timeout;
my @species_list;

GetOptions(
  'module=s'  => \$module,
  'url=s'     => \$url,
  'host=s'    => \$host,
  'port=s'    => \$port,
  'browser=s' => \$browser,
  'test=s'    => \$test,
  'skip=s'    => \$skip,
  'verbose'   => \$verbose,
  'species=s' => \$species,
  'timeout=s' => \$timeout,
);

die "You must specify a test module, eg. --module Generic" unless $module;
die "You must specify a url to test against, eg. --url http://www.ensembl.org" unless $url;

# hack: collect errors so that we can check for selenium failures
my @errors;
$SIG{'__DIE__'} = sub { push(@errors, $_[0]) };

# try to use the package
my $package = "EnsEMBL::Selenium::Test::$module";
eval("use $package");
die "can't use $package\n$@" if $@;

# look for test methods
no strict 'refs';
my @methods = sort grep { /^test_/ } @{Class::Inspector->methods($package, 'public')};
use strict 'refs';
die "Module has no test methods (test methods must be named 'test_*')" unless @methods;
# create test object
my $object = $package->new(
  url => $url,
  host => $host,
  port => $port,
  browser => $browser,
  conf => {
    timeout => $timeout,
  },
  verbose => $verbose,  
);

my $methods_called = 0;

#FIRST CHECK IF WEBSITE IS UP.....
$object->check_website;

#TODO:: regex clear all spaces
my @test = split(/,/, $test);
my @skip = split(/,/, $skip);
@species_list = ($species =~ /,/) ? split(/,/, $species) : $species; #TODO::CHeck for invalid species like unknownspecies

#getting all valid species for ensembl
if($species eq 'all') {
  my $SD = $object->get_species_def;
  my @valid_species = $SD->valid_species;

  @species_list = @valid_species;
}

# run tests
#run the test again for each species so only if module eq species run through loops
foreach (@species_list) {
  $object->set_species($_) if($_);
  foreach my $method (@methods) {
    next if @test and !grep {$method =~ /^(test_)?$_$/i} @test;
    next if @skip and grep {$method =~ /^(test_)?$_$/i} @skip; 
    
    my $test_case = $method;
    $test_case =~ s/test_//g;
    $test_case = uc($test_case);

    print "\n****************************************\n";
    ($_) ? print " Testing $_ \n" : print " Testing $test_case\n"; 
    print "****************************************\n";
    print "TESTING $test_case \n" if($_);
    
    $object->$method;
    $methods_called++;
  }
}

# check for problems
if ($methods_called) {    
  print "\nAll tests passed OK\n" 
    unless ($verbose or grep {/^Error.*selenium/} @errors or $object->testmore_output =~ /not ok/m);
} else {
  print "No test methods to run\n";
}
