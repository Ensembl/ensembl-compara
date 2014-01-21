=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  
  my %feats    = $glyphset->features; # FIXME: this works for bigwig/bigbed, but won't for other types where features returns a sensible data structure
  my @features = grep !($_->can('score') && $_->score == 0), map { ref $_->[0] eq 'ARRAY' ? @{$_->[0]} : @$_ } values %feats;
  my $i        = 0;
  
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

sub feature_content {
  my ($self, $feature, $i) = @_;
  my %extra  = $feature->can('extra_data') && ref $feature->extra_data eq 'HASH' ? %{$feature->extra_data} : ();
  my $start  = $feature->seq_region_start;
  my $end    = $feature->seq_region_end;
  my $single = $start == $end;
  
  $self->new_feature;
  
  $self->caption($feature->id || ($single ? $start : ''));
  
  my @entries = (
    $single ? (
      { type => 'Position', label => $start }
    ) : (
      { type => 'Start', label => $start },
      { type => 'End',   label => $end   },
    ),
    { type => 'Strand',     label => ('-', 'Forward', 'Reverse')[$feature->seq_region_strand] }, # remember, [-1] = at end
    { type => 'Hit start',  label => $feature->can('hstart')  ? $feature->hstart  : ''        },
    { type => 'Hit end',    label => $feature->can('hend')    ? $feature->hend    : ''        },
    { type => 'Hit strand', label => $feature->can('hstrand') ? $feature->hstrand : ''        },
    { type => 'Score',      label => $feature->can('score')   ? $feature->score   : ''        },
  );
  
  push @entries, { type => $self->format_type($_), label => join(', ', @{$extra{$_}}) } for sort grep !/^(_type|item_colour)$/, keys %extra;
  
  $self->add_entry($_) for grep $_->{'label'}, @entries;
}

sub summary_content {
  my ($self, $features) = @_;
  my $min = 9e99;
  my $max = -9e99;
  my ($mean, $score, $i);
  
  foreach (@$features) {
    next unless $_->can('score');
    
    $score = $_->score;
    $min   = min($min, $score);
    $max   = max($max, $score);
    $mean += $score;
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
