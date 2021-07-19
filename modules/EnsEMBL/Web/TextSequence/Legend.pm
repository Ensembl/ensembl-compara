=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::TextSequence::Legend;

use strict;
use warnings;

# This module is responsible for collecting legend information for a
# view. There is exactly one per view. It is separate as this
# functionality is complex and independent of the other tasks of a view.
# There is also a fair chance that individual components may wish to
# override some aspect of it.

sub new {
  my ($proto,$view) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
    view => $view,
    key => undef,
    expect => [],
    final => 0,
  };
  bless $self,$class;
  return $self;
}

sub extra_keys { return {}; } # Overridden in sub-classes

sub configured { # For overriding, if needed
  my ($self,$config,$entry,$type,$m) = @_;

  my $k = $entry->{'config'}||$m;
  return ($config->{'key'}{$type}{$k} or $config->{$k});
}

sub compute_legend {
  my ($self,$hub,$config) = @_;

  my $exon_type;
  unless(($config->{'exon_display'}||'selected') eq 'selected') {
    $exon_type = $config->{'exon_display'};
  }
  $exon_type = 'All' if !$exon_type || $exon_type eq 'core';
  $exon_type = ucfirst $exon_type;

  my $example = ($hub->param('v')) ? ' (i.e. '.$hub->param('v').')' : '';

  my $key = $self->{'view'}->output->c2s->create_legend({ %$config, exon_type => $exon_type, example => $example },$self->extra_keys($config));

  my @messages;
  foreach my $type (keys %$key) {
    foreach my $m (keys %{$key->{$type}}) {
      my $k = $key->{$type}{$m}{'config'}||$m;
      next unless $self->configured($config,$key->{$type}{$m},$type,$m);
      if($key->{$type}{$m}{'text'}) {
        $self->{'key'}{$type}{$m} = $key->{$type}{$m};
      }
      if($key->{$type}{$m}{'messages'}) {
        push @messages,@{$key->{$type}{$m}{'messages'}};
      }
    }
  }
  $self->{'key'}{'_messages'} = \@messages;
  $self->{'view'}->output->legend({
    legend => $self->{'key'},
    expect => $self->expect
  });
}

sub expect {
  my ($self,$val) = @_;

  return [] if $self->{'final'};
  push @{$self->{'expect'}},$val if @_>1;
  return $self->{'expect'};
}

sub legend { return $_[0]->{'key'}; }
sub final { $_[0]->{'final'} = 1; }

1;
