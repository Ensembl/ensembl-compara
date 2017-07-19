=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

our %strand_text = (
                    '1'   => 'Forward',
                    '-1'  => 'Reverse',
                    '0'   => 'None',
);

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $click_data = $self->click_data;
  
  return unless $click_data;
  $click_data->{'display'}  = 'text';
  $click_data->{'strand'}   = $hub->param('fake_click_strand');

  my $strand = $hub->param('fake_click_strand') || 1;
  my ($caption, @features);

  my $type     = $click_data->{'my_config'}->data->{'glyphset'};
  my $glyphset = "EnsEMBL::Draw::GlyphSet::$type";
  my $slice    = $click_data->{'container'};

  if ($self->dynamic_use($glyphset)) {
    $glyphset = $glyphset->new($click_data);

    my $i = 0;
    my $feature_id  = $hub->param('feature_id') || $hub->param('id');

    my $data = $glyphset->get_data;
    foreach my $track (@$data) {
      next unless (scalar @{$track->{'features'}||[]});
      $caption ||= $track->{'metadata'}{'zmenu_caption'};
      if ($feature_id) {
        foreach (@{$track->{'features'}||[]}) {
          if ($_->{'label'} eq $feature_id) {
            $_->{'track_name'} = $track->{'metadata'}{'name'};
            $_->{'url'}        = $track->{'metadata'}{'url'};
            delete($_->{'href'});
            push @features, $_;
          }
        }
      }
      else {
        push @features, @{$track->{'features'}||[]};
      }
    }
  }

  if (scalar @features > 5) {
    $self->summary_content(\@features, $caption);
  } else {
    $self->feature_content(\@features, $caption);
  }
}

sub feature_content {
  my ($self, $features, $caption) = @_;

  my $default_caption = 'Feature';
  $default_caption   .= 's' if scalar @$features > 1;

  foreach (@$features) {
    my $id = $_->{'label'};

    unless ($caption) {
      $caption = $_->{'track_name'} || $default_caption;
      $caption .= ': '.$id if scalar(@$features) == 1 && $id; 
    }

    $self->add_entry({'type' => 'Location', 
                      'label' => sprintf('%s:%s-%s', 
                                            $_->{'seq_region'}, 
                                            $_->{'start'}, 
                                            $_->{'end'})
                      });

    if (defined($_->{'strand'})) {
      $self->add_entry({'type' => 'Strand', 'label' => $strand_text{$_->{'strand'}}});
    }

    if (defined($_->{'score'})) {
      $self->add_entry({'type' => 'Score', 'label' => $_->{'score'}});
    }

    if ($_->{'extra'}) {
      foreach my $extra (@{$_->{'extra'}||[]}) {
        next unless $extra->{'name'};
        if ($extra->{'value'} =~ /<a /) {
          $self->add_entry({'type' => $extra->{'name'}, 'label_html' => $extra->{'value'}});
        }
        elsif ($extra->{'name'} =~ /^url$/i) {
          $self->add_entry({'type' => 'Link', 'label_html' => sprintf('<a href="%s">%s</a>', $extra->{'value'}, $extra->{'value'})});
        }
        else {
          $self->add_entry({'type' => $extra->{'name'}, 'label' => $extra->{'value'}});
        }
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
