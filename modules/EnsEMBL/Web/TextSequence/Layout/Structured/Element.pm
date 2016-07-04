package EnsEMBL::Web::TextSequence::Layout::Structured::Element;

use strict;
use warnings;

sub new {
  my ($proto,$string,$format) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    string => $string,
    format => $format,
  };
  bless $self,$class;
  return $self;
}

sub format { $_[0]->{'format'} = $_ if @_>1; return $_[0]->{'format'}; }
sub string { $_[0]->{'string'} = $_ if @_>1; return $_[0]->{'string'}; }

sub append { $_[0]->{'string'} .= $_[1] }

sub size {
  my ($self) = @_;

  return 0 if ref($self->{'string'});
  return length $self->{'string'};
}

1;
