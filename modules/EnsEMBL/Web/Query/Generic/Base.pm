package EnsEMBL::Web::Query::Generic::Base;

use strict;
use warnings;

use Attribute::Handlers;
use Data::Dumper;

sub _new {
  my ($proto,$store) = @_;

  my $class = ref($proto) || $proto;
  my $self = { store => $store };
  bless $self,$class;
  return $self;
}

sub source {
  my ($self,$source) = @_;

  return $self->{'store'}->_source($source);
}

sub post_process_unique {
  my ($self,$glyphset,$key,$ff) = @_;

  my %features;
  $features{$_->{$key}} = $_ for(@$ff);
  @$ff = values %features;
}

1;
