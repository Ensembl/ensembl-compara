=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

use EnsEMBL::Web::Tools::Sanitize qw(strict_clean);

our %strand_text = (
                    '1'   => 'Forward',
                    '-1'  => 'Reverse',
                    '0'   => '-',
);

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $click_data = $self->click_data;
  
  return unless $click_data;
  $click_data->{'display'} = 'text';

  my @coords = map { $hub->param("fake_click_$_") } qw(chr start end);

  my $type     = $click_data->{'my_config'}->data->{'glyphset'};
  my $glyphset = "EnsEMBL::Draw::GlyphSet::$type";

  if ($self->dynamic_use($glyphset)) {
    $glyphset = $glyphset->new($click_data);

    my $i = 0;
    my (@id_features, @other_features);
    my $feature_id  = $hub->param('feature_id') || $hub->param('id');
    my $slice       = $click_data->{'container'};

    if ($type eq 'flat_file') { 
      my $data = $glyphset->features;
      foreach my $track (@$data) {
        foreach (@{$track->{'features'}||[]}) {
          if ($feature_id && $_->{'label'} eq $feature_id) {
            $_->{'track_name'} = $track->{'metadata'}{'name'};
            $_->{'url'}        = $track->{'metadata'}{'url'};
            delete($_->{'href'});
            push @id_features, $_;
          }
          elsif ($_->{'seq_region'} eq $coords[0]
                      && $_->{'start'} >= 0
                      && $_->{'end'} <= $slice->length) {
            $_->{'track_name'} = $track->{'metadata'}{'name'};
            $_->{'url'}        = $track->{'metadata'}{'url'};
            delete($_->{'href'});
            push @other_features, $_;
          }
        } 
      }
    }
=pod
    elsif ($type eq 'bigbed') {
      my %feats    = $glyphset->features; # bigbed returns a stupid data structure

      @features = map { ref $_->[0] eq 'ARRAY' ? @{$_->[0]} : @$_ } values %feats;
    } 
    else {
      @features = @{$glyphset->features};
    }
=cut
    my @features = scalar(@id_features) ? @id_features : @other_features;

    if (scalar @features > 5) {
      $self->summary_content(\@features);
    } else {
      $self->feature_content(\@features, $slice);
    }
  }
}

sub summary_content {
}

sub feature_content {
  my ($self, $features, $slice) = @_;
  my $caption;

  foreach (@$features) {
    $caption = $_->{'track_name'};
    my $id = $_->{'label'};
    $caption .= ': '.$id if scalar(@$features) == 1 && $id; 

    $self->add_entry({'type' => 'Location', 
                      'label' => sprintf('%s:%s-%s', 
                                            $_->{'seq_region'}, 
                                            $_->{'start'} + $slice->start, 
                                            $_->{'end'} + $slice->start)
                      });

    if (defined($_->{'strand'})) {
      $self->add_entry({'type' => 'Strand', 'label' => $strand_text{$_->{'strand'}}});
    }

    if (defined($_->{'score'})) {
      $self->add_entry({'type' => 'Score', 'label' => $_->{'score'}});
    }

    if ($_->{'extra'}) {
      foreach my $extra (@{$_->{'extra'}||[]}) {
        next unless $extra->{'value'};
        $self->add_entry({'type' => $extra->{'name'}, 'label' => $extra->{'value'}});
      }
    }

    my $url = $_->{'url'};
    if ($url) {
      if ($id) {
        $url =~ s/\$\$/$id/e;
      }
      $self->add_entry({'type' => 'Link', 'label_html' => sprintf('<a href="%s">%s</a>', $url, $id)});
    }
  }

  $self->caption($caption);
}

=pod  
  
sub feature_content {
  my ($self, $feature, $i) = @_;
  my %extra  = ref $feature ne 'HASH' && $feature->can('extra_data') && ref $feature->extra_data eq 'HASH' ? %{$feature->extra_data} : ();
  my $extra_order;
  $extra_order = $feature->extra_data_order if ref $feature ne 'HASH' && $feature->can('extra_data_order');

  my $start  = $feature->{'start'} + $self->hub->param('click_start') - 1;
  my $end    = $feature->{'end'} + $self->hub->param('click_start') - 1;
  my $single = $start == $end;
  my $type;
  my $click_data = $self->click_data;
  my $type = $click_data->{'my_config'}->data->{'glyphset'} if $click_data;
  
  $self->new_feature;

  my $caption = '';
  if(ref($feature) eq 'HASH' or !$feature->id) {
    if($single) { $caption = $start; } else { $caption = "$start-$end"; }
  } else {
    $caption = $feature->id;
  }
  if(!$caption and $single) { # last attempt!
    $caption = $start;
  }
  $self->caption($caption);
  
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
    { type => 'Score',      label => $feature->{'score'}, name => 'score' },
  );

  if(ref $feature ne 'HASH' && $feature->can('id') && $feature->id ne $caption) {
    push @entries, { type => 'Name', label => $feature->id, name => 'name' };
  }

  # Replace fields with name in autosql (only score for now)
  if(ref $feature ne 'HASH' && $feature->can('real_name')) {
    foreach my $e (@entries) {
      next unless $e->{'name'};
      my $name = $feature->real_name($e->{'name'});
      $e->{'type'} = $self->format_type(undef,$name) unless $name eq $e->{'name'};
    }
  }

  for($self->sorted_extra_keys(\%extra,$extra_order)) {
    push @entries, {
      type => $self->format_type($feature,$_),
      label_html => join(', ', map { strict_clean ($_) } @{$extra{$_}})
    };
  }
  
  $self->add_entry($_) for grep { $_->{'label'} or $_->{'label_html'} } @entries;
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
  if($i) {
    $self->add_entry({ type => 'Min score',  label => $min              });
    $self->add_entry({ type => 'Mean score', label => $mean / $i        });
    $self->add_entry({ type => 'Max score',  label => $max              });
  }
}

sub format_type {
  my ($self,$feature, $type) = @_;

  $type = $feature->real_name($type) if $feature and $feature->can('real_name');
  $type =~ s/(.)([A-Z])/$1 $2/g;
  $type =~ s/_/ /g;
  return ucfirst lc $type;
}

=cut

1;
