package EnsEMBL::Web::Query::Generic::Base;

use strict;
use warnings;

use Attribute::Handlers;

sub _new {
  my ($proto,$store) = @_;

  my $class = ref($proto) || $proto;
  my $self = { store => $store };
  bless $self,$class;
  return $self;
}

sub _route {
  my ($self,$route,$data) = @_;

  my $out = $data;
  foreach my $r (@$route) {
    if($r eq '*') {
      my @new;
      push @new,@{$_||[]} for(@$out);
      $out = \@new;
    } else {
      $out = [ map { $_->{$r} } @$out ];
    }
  }
  return $out;
}

sub source {
  my ($self,$source) = @_;

  return $self->{'store'}->_source($source);
}

sub fixup_unique {
  my ($self,$key) = @_;

  if($self->phase eq 'post_process') {
    my @route = split('/',$key);
    $key = pop @route;
    my %features;
    my $route = $self->_route(\@route,$self->data);
    foreach my $f (@$route) {
      next unless $f->{$key};
      $features{$f->{$key}} = $f;
    }
    @$route = values %features;
  }
}

sub species_defs {
  return $_[0]->source('SpeciesDefs');
}

sub database_dbc {
  my ($self,$species,$type) = @_;

  return $self->source('Adaptors')->database_dbc($species,$type);
}

sub phase { return $_[0]->{'_phase'}; }
sub data { return $_[0]->{'_data'}; }
sub context { return $_[0]->{'_context'}; }
sub args { return $_[0]->{'_args'}; }
sub fixup {}

1;
