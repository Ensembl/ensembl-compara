package EnsEMBL::Web::TextSequence::Legend;

use strict;
use warnings;

# This module is responsible for collecting legend information for a
# view. There is exactly one per view. It is separate as this
# functionality is complex and independent of the other tasks of a view.
# There is also a fair chance that individual components may wish to
# override some aspect of it.

use EnsEMBL::Web::TextSequence::ClassToStyle qw(create_legend);

sub new {
  my ($proto) = @_;

  my $class = ref($proto) || $proto;
  my $self = {
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
  $exon_type = $config->{'exon_display'} unless $config->{'exon_display'} eq 'selected';
  $exon_type = 'All' if !$exon_type || $exon_type eq 'core';
  $exon_type = ucfirst $exon_type;

  my $example = ($hub->param('v')) ? ' (i.e. '.$hub->param('v').')' : '';

  my $key = create_legend($hub,{ %$config, exon_type => $exon_type, example => $example },$self->extra_keys($config));

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
