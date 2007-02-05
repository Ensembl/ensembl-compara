#! /usr/bin/perl -w

use Test::More qw( no_plan );
use strict;

BEGIN {
  use_ok( 'EnsEMBL::Web::Object::DataField' );
}

my $data_field = EnsEMBL::Web::Object::DataField->new({ name => 'title', type => 'text', queriable => 'yes' });

isa_ok( $data_field, 'EnsEMBL::Web::Object::DataField' );

ok ($data_field->get_name eq 'title', 'name is title');
ok ($data_field->get_type eq 'text',  'type is text');
ok ($data_field->get_queriable eq 'yes', 'queriable is yes');
ok ($data_field->is_queriable == 1, 'queriable is true');
