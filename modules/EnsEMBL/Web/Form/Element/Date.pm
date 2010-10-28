package EnsEMBL::Web::Form::Element::Date;

use strict;
use base qw( EnsEMBL::Web::Form::Element );

our @months = qw(January February March April May June July August September October November December);

sub render {
  my $self = shift;
  return format_date($self, time);
}

sub format_date {
  my ($self, $time) = @_;
  ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime($time);
  return sprintf("%s %s", $months[$mon], $year+1900 );
}

1;
