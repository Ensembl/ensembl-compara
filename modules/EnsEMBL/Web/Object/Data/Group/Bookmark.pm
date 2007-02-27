package EnsEMBL::Web::Object::Data::Group::Bookmark;

use strict;
use warnings;

#use base 'EnsEMBL::Web::Object::Data::Bookmark';

{

sub BUILD {
  warn "ALERT";
}

sub key {
  return "group_record_id";
}

sub table {
  return "group_record";
}

}

1;
