#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

BEGIN {
  use_ok( 'EnsEMBL::Web::RegObj' );
}

my $mock_registry = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY; 

isa_ok( $mock_registry, 'EnsEMBL::Web::MockRegistry' );
