#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

use vars qw($filename $parser);

BEGIN {
  use_ok( 'EnsEMBL::Web::Object::Data' );
  use_ok( 'EnsEMBL::Web::Object::DataField' );
}

my $data_object = EnsEMBL::Web::Object::Data->new();

isa_ok( $data_object, 'EnsEMBL::Web::Object::Data' );

$data_object->add_field({ name => 'name', type => 'text' });
$data_object->add_field({ name => 'id', type => 'int' });

my @fields = @{ $data_object->get_fields };

ok ($#fields == 1, 'field count is 2');
isa_ok ($fields[0], 'EnsEMBL::Web::Object::DataField');
