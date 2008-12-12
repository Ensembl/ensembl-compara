#!/usr/local/bin/perl

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
my $EXPORT      = $SiteDefs::ENSEMBL_SERVERROOT.'/utils/edoc/temp/';
my $SUPPORT     = $SiteDefs::ENSEMBL_SERVERROOT.'/utils/edoc/support/';
my @locations = ( "$SERVER_ROOT/ensembl-draw/modules", map { "$SERVER_ROOT/modules/$_" } @modules );

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
