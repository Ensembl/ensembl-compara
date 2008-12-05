package EnsEMBL::Web::Data::Trackable;

## Parent class for data objects that can be tracked by user and timestamp
## Can be multiply-inherited with Object::Data::Record

use strict;
use warnings;
use HTTP::Date qw(str2time time2iso);
use EnsEMBL::Web::Tools::Misc;
use base qw(EnsEMBL::Web::Data);


__PACKAGE__->add_queriable_fields(
  created_at  => 'datetime',
  created_by  => 'int',
  modified_at => 'datetime',
  modified_by => 'int',
);

__PACKAGE__->add_trigger(
  before_create => sub {
                     $_[0]->created_at(time2iso());
                     $_[0]->created_by($ENV{'ENSEMBL_USER_ID'} || 0);
                   }
);

__PACKAGE__->add_trigger(
  before_update => sub {
                     $_[0]->modified_at(time2iso());
                     $_[0]->modified_by($ENV{'ENSEMBL_USER_ID'} || 0);
                   }
);

sub created_at_pretty {
  my $self = shift;
  return pretty_date(str2time($self->created_at));
}

sub modified_at_pretty {
  my $self = shift;
  return pretty_date(str2time($self->modified_at));
}

1;
