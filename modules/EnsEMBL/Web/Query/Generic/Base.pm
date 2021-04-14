=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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

sub loop_species {
  my ($self,$args,$subpart) = @_;

  my @out;
  foreach my $sp (@{$SiteDefs::PRECACHE_DEFAULT_SPECIES}) {
    next if ($subpart->{'species'}||$sp) ne $sp;
    my %out = %$args;
    $out{'species'} = $sp;
    $out{'__name'} = $sp;
    push @out,\%out;
  }
  return \@out;
}

1;
