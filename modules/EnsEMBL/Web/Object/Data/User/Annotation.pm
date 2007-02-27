package EnsEMBL::Web::Object::Data::User::Annotation;

use strict;
use warnings;

use base 'EnsEMBL::Web::Object::Data::Annotation';

{

sub key {
  return "user_record_id";
}

}

1;
