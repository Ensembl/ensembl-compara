package EnsEMBL::Web::Object::Data::User::Configuration;

use strict;
use warnings;

use base 'EnsEMBL::Web::Object::Data::Configuration';

{

sub key {
  return "%%user_record%%_id";
}

}

1;
