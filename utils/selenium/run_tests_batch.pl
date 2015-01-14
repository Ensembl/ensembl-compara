# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#!/usr/local/bin/perl
use strict;
use lib '../modules';
use Getopt::Long;
use Data::Dumper;
use FindBin qw($Bin);
use LWP::UserAgent;

my $start_time = time;
my $output_dir = '.';
my $cmd;
my ($module, $url, $timeout, $browser, $host);

GetOptions(
  'module=s'  => \$module,
  'url=s'     => \$url,
  'browser=s' => \$browser,  
  'timeout=s' => \$timeout,
  'host=s'    => \$host,
);

$timeout   = qq{-timeout $timeout} if($timeout);
$url       = qq{-url $url} if($url);
$browser   = qq{-browser "$browser"} if($browser);
my @module = split(/,/, $module) if($module);
my $port   = "4444";

# check to see if the selenium server is online(URL returns OK if server is online).
my $ua = LWP::UserAgent->new(keep_alive => 5, env_proxy => 1);
$ua->timeout(10);
my $response = $ua->get("http://$host:$port/selenium-server/driver/?cmd=testComplete");
if($response->content ne 'OK') { print "\nSelenium Server is offline !!!!\n";exit;}

#prepare report dir`
if (-d 'test_reports') {
  print "Deleting old reports files\n";
  `rm -f test_reports/*.txt`;
} else {
  print "Creating reports dir\n";
  mkdir('test_reports');
}

#non-species related test module....new module (non-species) can be added here.
my @non_species_modules = qw(Generic);

#species related test modules .... running every thing by default, new one (species related) needs to be added here
my @species_modules = qw(GenomeStatistics Gene Karyotype Location Regulation Transcript Variation Blat);

# running specific module from the command line e.g: -module Generic,Gene
if(@module) {
  my (%hash, %hash_species);  
  my @temp_array = grep { $hash{ $_ }++ } @module, @non_species_modules;
  @non_species_modules = @temp_array ? @temp_array : qw();
  
  my @temp_array2 = grep { $hash_species{ $_ }++ } @module, @species_modules;
  @species_modules = @temp_array2 ? @temp_array2 : qw();
}

foreach (@non_species_modules) {
  print "\nRunning Module $_ Test \n"; 
  my $report = $_."_report.txt";
  my $cmd = qq{perl run_tests.pl --module "$_" $timeout $url $browser --host $host --port $port > "test_reports/$report" 2>&1 };
  $cmd =~ s/\n//g;
#print "  $cmd\n";
  system $cmd;
}

#Test module related to species
foreach (@species_modules) {
  my $report = $_."_report.txt";
  print "Running Module $_ Test \n";
  
  my $species = qq{--species "all"}; #by default all species
  $species    = qq{--species "mus_musculus"} if ($_ eq 'Regulation'); #Regulation test module needs to be run for mouse only  
  
  $cmd = qq{perl run_tests.pl --module "$_" $species $timeout $url $browser --host $host --port $port > "test_reports/$report" 2>&1 };
  $cmd =~ s/\n//g;
 # print "  $cmd\n";
  system $cmd;  
}
printf "\nRuntime was %s secs\n", time - $start_time;
