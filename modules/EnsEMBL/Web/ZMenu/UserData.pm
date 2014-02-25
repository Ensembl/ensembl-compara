=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::UserData;

use strict;

use List::Util qw(min max);

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $click_data = $self->click_data;
  
  return unless $click_data;
  
  my $type     = $click_data->{'my_config'}->data->{'glyphset'};
  my $glyphset = "Bio::EnsEMBL::GlyphSet::$type";
  
  return unless $self->dynamic_use($glyphset);
  
  $glyphset = $glyphset->new($click_data);
  
  my $i = 0;
  my @features;
  
  if ($type eq 'bigbed') {
    my %feats    = $glyphset->features; # bigbed returns a stupid data structure
       @features = grep !($_->can('score') && $_->score == 0), map { ref $_->[0] eq 'ARRAY' ? @{$_->[0]} : @$_ } values %feats;
  } else {
    @features = @{$glyphset->features};
  }
  
  if (scalar @features > 5) {
    $self->summary_content(\@features);
  } else {
    $self->feature_content($_, $i++) for @features;
    
    if (scalar @{$self->{'features'}} == 1) { # The first feature is empty, so in this case there are actually no features
      $self->caption('No features found');
      $self->add_entry({ label => sprintf('This track has no features in the region %s:%s-%s', $self->click_location) });
    }
  }
}

# This is a hack, we really need an order to be supplied by the glyphset
sub sorted_extra_keys {
  my ($self,$extra) = @_;

  my %sort;
  foreach my $k (keys %$extra) {
    next if $k =~ /^_type/ or $k =~ /^item_colour/;
    my $v = $k;
    $v = "A $v" if /start$/;
    $v = "B $v" if /end$/;
    $sort{$k} = $v;
  }

  return sort { $sort{$a} <=> $sort{$b} } keys %sort;
}

sub feature_content {
  my ($self, $feature, $i) = @_;
  my %extra  = ref $feature ne 'HASH' && $feature->can('extra_data') && ref $feature->extra_data eq 'HASH' ? %{$feature->extra_data} : ();
  my $start  = $feature->{'start'};
  my $end    = $feature->{'end'};
  my $single = $start == $end;
  
  $self->new_feature;
  
  $self->caption(ref $feature eq 'HASH' ? $single ? $start : "$start-$end" : $feature->id || ($single ? $start : ''));
  
  my @entries = (
    $single ? (
      { type => 'Position', label => $start }
    ) : (
      { type => 'Start', label => $start },
      { type => 'End',   label => $end   },
    ),
    { type => 'Strand',     label => ('-', 'Forward', 'Reverse')[$feature->{'strand'}] }, # remember, [-1] = at end
    { type => 'Hit start',  label => $feature->{'hstart'}  },
    { type => 'Hit end',    label => $feature->{'hend'}    },
    { type => 'Hit strand', label => $feature->{'hstrand'} },
    { type => 'Score',      label => $feature->{'score'}   },
  );
  
  push @entries, { type => $self->format_type($_), label => join(', ', @{$extra{$_}}) } for $self->sorted_extra_keys(\%extra);
  
  $self->add_entry($_) for grep $_->{'label'}, @entries;
}

sub summary_content {
  my ($self, $features) = @_;
  my $min = 9e99;
  my $max = -9e99;
  my ($mean, $i);
  
  foreach (@$features) {
    next unless $_->{'score'};
    
    $min   = min($min, $_->{'score'});
    $max   = max($max, $_->{'score'});
    $mean += $_->{'score'};
    $i++;
  }
  
  $self->caption(sprintf '%s:%s-%s summary', $self->click_location);
  
  $self->add_entry({ type => 'Feature count', label => scalar @$features });
  $self->add_entry({ type => 'Min score',     label => $min              });
  $self->add_entry({ type => 'Mean score',    label => $mean / $i        });
  $self->add_entry({ type => 'Max score',     label => $max              });
}

sub format_type {
  my ($self, $type) = @_;
  $type =~ s/(.)([A-Z])/$1 $2/g;
  $type =~ s/_/ /g;
  return ucfirst lc $type;
}

1;
