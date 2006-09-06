#! /usr/bin/perl -w

use Test::More qw( no_plan );
use warnings;
use strict;

use vars qw($start_dir $document);

BEGIN {
  use_ok( 'EnsEMBL::Web::Tools::Document' );
}

BEGIN {
  my $location = `pwd`;
  chomp $location;
  $start_dir = "$location/files/edoc/empty/";
  $document = EnsEMBL::Web::Tools::Document->new( (directory => [ $start_dir ]) );
}

isa_ok( $document, "EnsEMBL::Web::Tools::Document" );
ok( $document->directory->[0] eq $start_dir, "start dir ok");

my @found_modules = @{ $document->find_modules };
ok ($#found_modules eq "-1", "No modules found");
