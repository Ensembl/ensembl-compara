package EnsEMBL::Web::Object::Data::Group::Configuration;

use strict;
use warnings;

use base 'EnsEMBL::Web::Object::Data::Configuration';

{

sub key {
  return "group_record_id";
}

sub table {
  return '%%group_record%%';
}

}

1;
