#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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


use strict;
use warnings;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception;
use Data::Dumper;


my $usage = " 
This script will create a registry file from the locator field in the genome_db table of the
 compara db url provided (if only_current = 1, then only get current assemblies), or 
 directly from the server for a particular release version. If no_print_ret = 1, you can append 
 to the file.

$0 -url mysql://user:pass\@server:port/db_name|release_version -only_current 1

eg.
$0 -url mysql://user:pass\@server:port/compara_db_name # get db list from compara genome_db locator field
$0 -url mysql://user:pass\@server:port/77 # get all 77 core dbs from server 

";

my ($help, $url, $only_current, $no_print_ret);

GetOptions(
 'help'   => \$help,
 'only_current=i' => \$only_current,
 'no_print_ret=i' => \$no_print_ret, # dont print the 1 return value at the end of the module.
 'url=s' => \$url);

if ($help) {
  print $usage;
  exit 0;
}

if (!defined $url){
  print $usage;
  exit 1;
}

#parse the -url arg
my ($driver,$user,$pass,$host,$port,$db_name)=$url=~/(\w+):\/\/(\w+):*(\w*)\@([\w+\-]*):(\w+)\/(\w+)/;

unless( $driver && $user && $host && $port && $db_name){
 print $usage;
 exit 1;
}

my @connection_params;

# assume all the databases to put in the reg_conf file are of type "core"
my $group = "core";

# if the url ends in a release number - get the available core dbs from the host
if($db_name=~/^\d+$/){
 Bio::EnsEMBL::Registry->load_registry_from_url($url);
 my @db_adaptors = @{ Bio::EnsEMBL::Registry->get_all_DBAdaptors( -group => "$group") };
 foreach my $db_adaptor (@db_adaptors) {
  my $db_connection = $db_adaptor->dbc();
  my $pass = $db_connection->pass() ? $db_connection->pass() : '';
  push(@connection_params, { 
   adaptor => ref($db_adaptor), 
   host => $db_connection->host(), 
   port => $db_connection->port(), 
   user => $db_connection->user(),
   pass => $pass,
   dbname => $db_connection->dbname(), 
   species => $db_adaptor->species(), 
   group => $db_adaptor->group() } );
 }
 print_con(\@connection_params) if @connection_params;
}

# it's a compara db - get the info from the genome_db locator field
elsif($db_name=~/\w+/){
 my $compara_db_adaptor = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
  -driver => "$driver", -user => "$user", -pass => "$pass",
  -host => "$host", -port => "$port", dbname => "$db_name");
 my $genome_db_adaptor = $compara_db_adaptor->get_adaptor("GenomeDB");
 my @locator_strings;
 foreach my $genome_db( @{ $genome_db_adaptor->fetch_all }){ 
  if($only_current){
   push @locator_strings, $genome_db->locator if ( $genome_db->is_current && $genome_db->locator );
  } else {
   push @locator_strings, $genome_db->locator if $genome_db->locator;
  }
 }
 throw("no locator strings in database $db_name") unless @locator_strings;
 foreach my $locator(@locator_strings){
  my($lc_adp_host,@rest)= map { [ split "=", $_ ] } split ";",$locator;
  my($lc_adaptor,$lc_host)=@$lc_adp_host;
  my($lc_ad,$host_string)=(split '/', $lc_adaptor);
  my%loc_keys;
  foreach my $pair([ $host_string, $lc_host ], @rest){
   next if $pair->[0]=~/disconnect_when_inactive/;
   $loc_keys{ $pair->[0] } = $pair->[1];
  }
  $loc_keys{ adaptor } = $lc_ad ;
  push(@connection_params, \%loc_keys) 
 }
 print_con(\@connection_params) if @connection_params;
}

sub print_con {
 my $connection_params = shift;
 print "use strict;\nuse Bio::EnsEMBL::Utils::ConfigRegistry;\nuse Bio::EnsEMBL::DBSQL::DBAdaptor;". 
      "\nuse Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;\nuse Bio::EnsEMBL::Registry;\n\n";
 foreach my $con_hash(@$connection_params){  
  print "\n######\nnew $con_hash->{'adaptor'} (\n";
  delete($con_hash->{'adaptor'});
  foreach my $key(keys %$con_hash){
   if($con_hash->{$key}){
    print " -$key => \"", $con_hash->{$key}, "\",\n";
   }
  }
  print ");\n";
 }
 unless($no_print_ret){
  print "\n1;\n";
 }
}
