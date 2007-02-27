package EnsEMBL::Web::Object::Data::User::Bookmark;

use strict;
use warnings;

use base 'EnsEMBL::Web::Object::Data::Bookmark';

{

sub key {
  return "user_record_id";
}

}

1;
