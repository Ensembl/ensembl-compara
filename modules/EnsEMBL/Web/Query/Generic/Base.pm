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

sub fixup_unique {
  my ($self,$key) = @_;

  if($self->phase eq 'post_process') {
    my %features;
    $features{$_->{$key}} = $_ for(@{$self->data});
    @{$self->data} = values %features;
  }
}

sub phase { return $_[0]->{'_phase'}; }
sub data { return $_[0]->{'_data'}; }
sub context { return $_[0]->{'_context'}; }
sub args { return $_[0]->{'_args'}; }
sub fixup {}

1;
