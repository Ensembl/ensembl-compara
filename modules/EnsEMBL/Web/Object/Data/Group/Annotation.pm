package EnsEMBL::Web::Object::Data::Group::Annotation;

use strict;
use warnings;

use base 'EnsEMBL::Web::Object::Data::Annotation';

{

sub key {
  return "group_record_id";
}

sub table {
  return '%%group_record%%';
}

}

1;
