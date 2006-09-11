#! /usr/bin/perl -w

use Test::More qw( no_plan );
use warnings;
use strict;

use vars qw($start_dir $export $support $document);

BEGIN {
  use_ok( 'EnsEMBL::Web::Tools::Document' );
}

BEGIN {
  my $location = `pwd`;
  chomp $location;
  $start_dir = "$location/files/edoc/modules/";
  $export = "$location/files/edoc/export/";
  $support = "$location/files/edoc/support/";
  $document = EnsEMBL::Web::Tools::Document->new( (
                  directory => [ $start_dir ], 
                  identifier => "###"
              ) );
}

my @found_modules = @{ $document->find_modules };
#warn "FOUND: " . $#found_modules;
ok ($#found_modules == 4, "modules found");

my @found_methods = @{ $document->methods };
foreach my $method (@found_methods) {
#  warn $method->name . ": " . $method->package->name;
}
#warn "FOUND: $#found_methods";
ok ($#found_methods == 48, "methods found ok");

$document->generate_html($export, $support);
