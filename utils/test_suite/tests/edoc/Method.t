#! /usr/bin/perl -w

use Test::More qw( no_plan );
use warnings;
use strict;

use vars qw($name $location $documentation $type $result $method);

BEGIN {
  use_ok( 'EnsEMBL::Web::Tools::Document::Method' );
}

BEGIN {
  $name = "add_module";
  $documentation = "This is a test method";
  $type = "constructor";
  $result = "return type";
  $method = EnsEMBL::Web::Tools::Document::Method->new( (
              name => $name,
              documentation => $documentation,
              type => $type,
              result => $result
            ) );
}

isa_ok( $method, "EnsEMBL::Web::Tools::Document::Method" );
ok( $method->name eq $name , "name ok");
ok( $method->documentation eq $documentation, "documentation ok");
ok( $method->type eq $type, "type ok");
ok( $method->result eq $result, "result ok");
