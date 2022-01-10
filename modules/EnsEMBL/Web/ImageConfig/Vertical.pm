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

package EnsEMBL::Web::ImageConfig::Vertical;

use strict;
use warnings;
no warnings qw(uninitialized);

use EnsEMBL::Web::Constants;
use EnsEMBL::Web::File::User;
use EnsEMBL::Web::IOWrapper;
use EnsEMBL::Web::IOWrapper::Indexed;

use parent qw(EnsEMBL::Web::ImageConfig);

sub orientation {
  ## @override
  return 'vertical';
}

sub load_user_tracks {
  ## @override
  ## We load less data on vertical drawing code, as it shows regions at a much smaller scale. We also need to distinguish between
  ## density features, rendered as separate tracks, and pointers, which are part of the karyotype track
  my $self  = shift;
  my $menu  = $self->get_node('user_data');

  return unless $menu;

  $self->SUPER::load_user_tracks;

  my $width           = $self->get_parameter('all_chromosomes') eq 'yes' ? 10 : 60;
  my %remote_formats  = map { lc $_ => 1 } @{$self->hub->species_defs->multi_val('REMOTE_FILE_FORMATS') || []};

  foreach (@{$menu->get_all_nodes}) {
    my $format = $_->get_data('format');

    # except bigwig, remove all tracks with big remote formats
    if (($remote_formats{lc $format} && lc $format ne 'bigwig') || (lc $format eq 'vcf' && $_->get_data('url'))) {
      $_->remove;
    } else {
      my ($strand, $renderers) = $self->_user_track_settings($format);
      $_->set('renderers', $renderers);
      $_->set('glyphset',  'Vuserdata');
      $_->set('colourset', 'densities');
      $_->set('maxmin',    1);
      $_->set('width',     $width);
      $_->set('strand',    $strand);
    }
  }
}

sub _user_track_settings {
  ## @override
  ## @private
  my ($self, $format) = @_;
  my $renderers;

  if (lc $format eq 'bigwig') {
    $renderers = [
                  'density_raw',        'Line graph - raw mean',
                  'density_line',       'Line graph - mean scaled to max',
                  'density_whiskers',   'Line graph - mean with whiskers',
                  'density_bar',        'Histogram, filled - mean',
                  'density_outline',    'Histogram, outline - mean',
                  ];
  }
  else {
    $renderers = [
                  'highlight_lharrow',  'Arrow on lefthand side',
                  'highlight_rharrow',  'Arrow on righthand side',
                  'highlight_bowtie',   'Arrows on both sides',
                  'highlight_wideline', 'Line',
                  'highlight_widebox',  'Box',
                  'density_line',       'Density plot - line graph',
                  'density_bar',        'Density plot - filled bar chart',
                  'density_outline',    'Density plot - outline bar chart',
                  ];

  }

  unshift @$renderers, ('off', 'Off');
  return ('b', $renderers);
}


##### ---------

sub load_user_track_data {
  my ($self, $chromosomes) = @_;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $bins         = 150;
  my $bin_size     = int(($self->container_width || 0) / $bins);
  my $colours      = [qw(darkred darkblue darkgreen purple grey red blue green orange brown magenta violet darkgrey)];
  my ($feature_adaptor, $slice_adaptor, %data, $max_value, $max_mean, $mapped, $unmapped);
  my $format_info  = EnsEMBL::Web::Constants::USERDATA_FORMATS;

  my $menu = $self->get_node('user_data');
  my $i    = 0;

  foreach my $track ($menu ? @{$menu->get_all_nodes} : ()) {
    my $display = $track->get('display');
    next if $display eq 'off';
    ## Of the remote formats, only bigwig is currently supported on this scale
    my $format = lc $track->get('format');
    next if $format_info->{$format}{'no_karyotype'};

    my $logic_name = $track->get('logic_name');
    my ($max1, $max2);

    unshift @$colours, 'black' if ($i == 0 && $display eq 'density_graph');

    my $colour = $colours->[$i];

    if (lc $track->get('format') eq 'bigwig' && $track->get('url')) {
      ## Just configure label and colour - we now get the data itself in the glyphset, where it belongs
      my $track_data = $track->{'data'};
      my $short_name = $track_data->{'caption'};
      my $track_name = $track_data->{'name'} || $short_name;
      $short_name = substr($short_name, 0, 17).'...' if length($short_name) > 20;
      $track->set('label', $short_name);
      $track->set('colour', $colour);
    }
    else {
      ## Get the file contents
      my %args = (
                  'hub'     => $hub,
                  'format'  => $track->get('format'),
                  'file'    => $track->get('file'),
                  );

      my $file  = EnsEMBL::Web::File::User->new(%args);
      my $iow = EnsEMBL::Web::IOWrapper::open($file,
                                             'hub'         => $hub,
                                             'config_type' => $self->type,
                                             'track'       => $track->id,
                                             );

      if ($iow) {
        $bins = 0 if $display !~ /^density/;
        ($data{$track->id}, $max1, $mapped, $unmapped) = $self->get_parsed_features($iow, $bins, $colour);
      }
      else {
        $hub->session->set_record_data({
          'type'      => 'message',
          'function'  => '_warning',
          'code'      => "deleted_userdata",
          'message'   => "Your file has been deleted from our servers. If you wish to keep your data longer than 7 days, please log into (or create) your user account and save your data.", 
        });

      }
    }

    $max_value = $max1 if $max1 && $max1 > $max_value;
    $max_mean = $max2 if $max2 && $max2 > $max_mean;
    $i++;
  }

  if ($max_value) {
    foreach my $id (keys %data) {
      foreach my $chr (keys %{$data{$id}}) {
        foreach my $track_data (values %{$data{$id}{$chr}}) {
          $self->get_node($id)->set('colour', $track_data->{'colour'});
        }
      }
    }
  }

  $self->set_parameter('bins',      $bins);
  $self->set_parameter('max_value', $max_value);
  $self->set_parameter('max_mean',  $max_mean);

  return (\%data, $mapped, $unmapped);
}

sub get_dna_align_features {
  my ($self, $logic_name, $feature_adaptor, $slice_adaptor, $bins, $bin_size, $chromosomes, $colour) = @_;
  my (%data, $max);

  foreach my $chr (@$chromosomes) {
    my $slice    = $slice_adaptor->fetch_by_region('chromosome', $chr);
    my $features = $feature_adaptor->fetch_all_by_Slice($slice, $logic_name);

    next unless scalar @$features;

    my $start = 1;
    my $end   = $bin_size;
    my @scores;

    for (0..$bins-1) {
      my $count    = scalar grep { $_->start >= $start && $_->end <= $end } @$features;

      $_  += $bin_size for $start, $end;
      $max = $count if $max < $count;

      push @scores, $count;
    }

    $data{$chr}{'dnaAlignFeature'} = {
      scores => \@scores,
      colour => $colour,
      sort   => 0,
    };
  }

  return (\%data, $max);
}

sub get_parsed_features {
  ## Parse the file and then munge the results into the format
  ## needed by the vertical drawing code
  my ($self, $wrapper, $bins, $colours) = @_;

  my $tracks  = $wrapper->create_tracks(undef, {'bins' => $bins, 'include_attribs' => 1});
  my $data    = {};
  my ($count, $sort, $max, $mapped, $unmapped) = (0,0,0,0,0);

  foreach my $track (@$tracks) {
    my $name = 'Data_'.$count;

    if ($track->{'metadata'}) {
      $name = $track->{'metadata'}{'name'};
      $max = $track->{'metadata'}{'max_value'} if (defined($track->{'metadata'}{'max_value'}) && $max < $track->{'metadata'}{'max_value'});
      $mapped += $track->{'metadata'}{'mapped'} || 0;
      $unmapped += $track->{'metadata'}{'unmapped'} || 0;
    }

    if ($bins) {
      while (my ($chr, $results) = each %{$track->{'bins'}}) {
        $data->{$chr}{$name} = {
          scores => [map $results->{$_}, 1..$bins],
          colour => $track->{'data'}{'config'}{'color'} || $colours->[$count],
          sort   => $sort
        };
      }
    }
    else {
      $data->{$name} = {'features' => $track->{'features'} || [],
                        'metadata' => $track->{'metadata'} || {}};
    }

    $count++ unless ($track->{'metadata'}{'color'} || $track->{'metadata'}{'colour'});
    $sort++;
  }

  return ($data, $max, $mapped, $unmapped);
}

sub get_bigwig_features {
  my ($self, $parser, $name, $chromosomes, $bins, $colour) = @_;
  my $data;

  my ($raw_data, $max, $max_mean) = $parser->fetch_scores_by_chromosome($chromosomes, $bins);

  while (my($chr, $scores) = each(%$raw_data)) {
    $data->{$chr}{$name} = {
                            'scores' => $scores,
                            'colour' => $colour,
                            'sort'   => 0,
                          };
  }
  return ($data, $max, $max_mean);
}

1;
