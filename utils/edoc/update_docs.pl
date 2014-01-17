#!/usr/local/bin/perl
# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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


use FindBin qw($Bin);
use File::Basename qw(dirname);
use strict;
use Data::Dumper;
use warnings;
use Time::HiRes qw(time);

my @modules = qw( EnsEMBL ExaLead.pm ExaLead Acme );

BEGIN{
  unshift @INC, "$Bin/../../conf";
  unshift @INC, "$Bin/../../modules";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use EnsEMBL::Web::Tools::Document;

my $SERVER_ROOT = $SiteDefs::ENSEMBL_SERVERROOT;
my $EXPORT      = $SiteDefs::ENSEMBL_WEBROOT.'/utils/edoc/temp/';
my $SUPPORT     = $SiteDefs::ENSEMBL_WEBROOT.'/utils/edoc/support/';
my @locations   = map { "$SiteDefs::ENSEMBL_WEBROOT/modules/$_" } @modules;

foreach( @SiteDefs::ENSEMBL_LIB_DIRS ) {
  if( /plugins/ ) { 
    push @locations, $_;
  }
}
foreach( @locations ) {
  print "$_\n";
}

mkdir $EXPORT, 0755 unless -e $EXPORT;
my $start = time();
my $document = EnsEMBL::Web::Tools::Document->new( (
  directory => \@locations,
  identifier => "###",
  server_root => $SERVER_ROOT
) );

my $point_1 = time();
$document->find_modules;

my $point_2 = time();
$document->generate_html( $EXPORT, '/info/docs/webcode/edoc', $SUPPORT );
my $end = time();

print "Directories documented:\n";
foreach( @locations ) {
  print " $_\n";
}

printf "
Time to generate docs:
  Creating object: %8.4f
  Finding modules: %8.4f
  Generating HTML: %8.4f
  TOTAL:           %8.4f
", $point_1 - $start, $point_2 - $point_1, $end - $point_2, $end - $start;
