#!/usr/local/bin/perl
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


use FindBin qw($Bin);
use File::Basename qw(dirname);
use strict;
use Data::Dumper;
use warnings;
use Time::HiRes qw(time);

my @modules = qw( EnsEMBL );

BEGIN{
  unshift @INC, "$Bin/../../conf";
  unshift @INC, "$Bin/../../modules";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
}

use EnsEMBL::eDoc::Generator;

my $VERSION     = $SiteDefs::ENSEMBL_VERSION;
my $SERVER_ROOT = $SiteDefs::ENSEMBL_SERVERROOT;
my $WEB_ROOT    = $SiteDefs::ENSEMBL_WEBROOT;

my $EXPORT      = $WEB_ROOT.'/utils/edoc/temp';
my $SUPPORT     = $WEB_ROOT.'/utils/edoc/support/';
my @locations   = map { "$WEB_ROOT/modules/$_" } @modules;

my @public_plugins = qw(ensembl orm users);

foreach my $plugin (@public_plugins) {
  push @locations, map { "$SERVER_ROOT/public-plugins/$plugin/modules/$_" } @modules;
}

foreach( @locations ) {
  print "$_\n";
}

mkdir $EXPORT, 0755 unless -e $EXPORT;
my $start = time();
my $generator = EnsEMBL::eDoc::Generator->new( (
  directories => \@locations,
  identifier  => "###",
  serverroot  => $SERVER_ROOT,
  version     => $VERSION,
) );

my $point_1 = time();
$generator->find_modules($SERVER_ROOT);

my $point_2 = time();
$generator->generate_html( $EXPORT, '/info/docs/webcode/edoc', $SUPPORT );
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
