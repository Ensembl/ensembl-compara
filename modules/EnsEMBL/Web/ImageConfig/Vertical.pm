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

package EnsEMBL::Web::ImageConfig::Vertical;

use strict;

use List::Util qw(sum);

use Bio::EnsEMBL::ExternalData::BigFile::BigWigAdaptor;
use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::File::User;

use base qw(EnsEMBL::Web::ImageConfig);

# We load less data on vertical drawing code, as it shows regions 
# at a much smaller scale. We also need to distinguish between
# density features, rendered as separate tracks, and pointers,
# which are part of the karyotype track
sub load_user_tracks {
  my ($self, $session) = @_;
  my $menu = $self->get_node('user_data');
  
  return unless $menu;
  
  $self->SUPER::load_user_tracks($session);
  
  my $width              = $self->get_parameter('all_chromosomes') eq 'yes' ? 10 : 60;
  my %remote_formats     = map { lc $_ => 1 } @{$self->hub->species_defs->multi_val('REMOTE_FILE_FORMATS')||[]};
  
  foreach ($menu->nodes) {
    my $format = $_->get('format');
    if ($remote_formats{lc $format} && lc $format ne 'bigwig') {
      $_->remove;
    } else {
      my (undef, $renderers) = $self->_user_track_settings($format);
      $_->set('renderers', $renderers);
      $_->set('glyphset',  'Vuserdata');
      $_->set('colourset', 'densities');
      $_->set('maxmin',    1);
      $_->set('width',     $width);
      $_->set('strand',    'b');
    }
  }
}

sub _user_track_settings {
  my ($self, $format) = @_;

  my $renderers = [
    'density_line',       'Density plot - line graph',
    'density_bar',        'Density plot - filled bar chart',
    'density_outline',    'Density plot - outline bar chart',
                  ];

  unless (lc $format eq 'bigwig') {
    unshift @$renderers, (
      'highlight_lharrow',  'Arrow on lefthand side',
      'highlight_rharrow',  'Arrow on righthand side',
      'highlight_bowtie',   'Arrows on both sides',
      'highlight_wideline', 'Line',
      'highlight_widebox',  'Box',
    );
  }

  unshift @$renderers, ('off', 'Off');
  return ('b', $renderers);
}

sub load_user_track_data {
  my ($self, $chromosomes) = @_;
  my $hub          = $self->hub;
  my $species_defs = $hub->species_defs;
  my $bins         = 150;
  my $bin_size     = int($self->container_width / $bins);
  my $track_width  = $self->get_parameter('width') || 80;
  my @colours      = qw(darkred darkblue darkgreen purple grey red blue green orange brown magenta violet darkgrey);
  my ($feature_adaptor, $slice_adaptor, $parser, %data, $max);
  
  foreach my $track ($self->get_node('user_data')->nodes) {
    my $display = $track->get('display');
    my $ftype = $track->get('ftype');
    
    next if $display eq 'off';
    
    my $logic_name = $track->get('logic_name');
    my $colour     = \@colours;
    my $max_value;
    
    unshift @$colour, 'black' if $display eq 'density_graph'; 
   
    if ($logic_name) {
      $feature_adaptor ||= $hub->get_adaptor('get_DnaAlignFeatureAdaptor', 'userdata');
      $slice_adaptor   ||= $hub->get_adaptor('get_SliceAdaptor');
      
      ($data{$track->id}, $max_value) = $self->get_dna_align_features($logic_name, $feature_adaptor, $slice_adaptor, $bins, $bin_size, $chromosomes, $colour->[0]);
    } 
    else {
      if (lc $track->get('format') eq 'bigwig') {
        ### Use the glyphset, because it already has data-checking
        my $track_data = $track->{'data'};
        my $adaptor = Bio::EnsEMBL::ExternalData::BigFile::BigWigAdaptor->new($track_data->{'url'}); 
        ($data{$track->id}, $max_value) = $self->get_bigwig_features($adaptor, $track_data->{'name'}, $chromosomes, $bins, $bin_size); 
      }
      else {
        if ($parser) {
          $parser->reset;
        } else {
          $parser = EnsEMBL::Web::Text::FeatureParser->new($species_defs);
          $parser->no_of_bins($bins);
          $parser->bin_size($bin_size);
          $parser->filter($chromosomes->[0]) if scalar @$chromosomes == 1;
        }
      
        ( $data{$track->id}, $max_value) = $self->get_parsed_features($track, $parser, $bins, $colour);
      }
    }
    
    $max = $max_value if $max_value > $max;
  }
  
  if ($max) {
    my $scale = $track_width / $max;
    
    foreach my $id (keys %data) {
      foreach my $chr (keys %{$data{$id}}) {
        foreach my $track_data (values %{$data{$id}{$chr}}) {
          $_ *= $scale for @{$track_data->{'scores'} || []};
          $self->get_node($id)->set('colour', $track_data->{'colour'});
        }
      }
    }
  }
  
  $self->set_parameter('bins',      $bins);
  $self->set_parameter('max_value', $max);
  
  return \%data;
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
  my ($self, $track, $parser, $bins, $colours) = @_;
  my $file_path = $track->get('url') || $track->get('file');
  my %args = ('hub' => $self->hub, 'file' => $file_path);
  my $file = EnsEMBL::Web::File::User->new(%args);
  my $result = $file->read;
  
  return undef unless $result->{'content'};
  
  $parser->parse($result->{'content'}, $track->get('format'));
  
  my $max_values = $parser->max_values;
  my $sort       = 0;
  my (%data, $max);
  
  while (my ($name, $track_data) = each %{$parser->get_all_tracks}) {
    my $count;
    
    while (my ($chr, $results) = each %{$track_data->{'bins'}}) {
      $data{$chr}{$name} = {
        scores => [ map $results->[$_], 0..$bins-1 ],
        colour => $track_data->{'config'}{'color'} || $colours->[$count],
        sort   => $sort
      };
    }
    
    $max = $max_values->{$name} if $max < $max_values->{$name};
    
    $count++ unless $track->{'config'}{'color'};
    $sort++;
  }
  
  return (\%data, $max);
}

sub get_bigwig_features {
  my ($self, $adaptor, $name, $chromosomes, $bins, $bin_size) = @_;
  warn ">>> CHROMOSOMES @$chromosomes";
  my (%data, $max);  
  return ({}, undef) unless $adaptor->check;
  $name ||= 'BigWig';

  my $bw = $adaptor->bigwig_open;
  if ($bw) { 
    ## If we're on a single-chromosome page, we want to filter the BigWig data
    my %chr_check;
    foreach (@{$chromosomes||[]}) {
      my $chr_name = 'chr'.$_;
      $chr_name = 'chrM' if $chr_name eq 'chrMT';
      $chr_check{$chr_name} = 1;
    }
    my $chrs = $bw->chromList;
    my $chr = $chrs->head;
    while ($chr) {
      if (!$chromosomes || $chr_check{$chr->name}) {
        my @scores;
        my $start = 0;
        my ($end, $previous_start, $previous_end);
      
        for (my $i = 0; $i < $bins; $i++) {
          last if $previous_end == $chr->size;
          $start  = $previous_end + 1;
          $end    = $start + $bin_size;
          $end    = $chr->size if $end > $chr->size;
        
          my $summary = $bw->bigWigSingleSummary($chr->name, $start, $end, 'bbiSumMean');
          push @scores, sprintf('%.2f', $summary);

          my $bin_max = sprintf('%.2f', $bw->bigWigSingleSummary($chr->name, $start, $end, 'bbiSumMax'));
          $max = $bin_max if $max < $bin_max;
 
          $previous_start = $start;
          $previous_end   = $end;
        }
        ## Translate chromosome name from its UCSC equivalent
        (my $chr_name = $chr->name) =~ s/chr//;
        $chr_name = 'MT' if $chr_name eq 'M';
        $data{$chr_name}{$name} = {
                                    'scores' => \@scores,
                                    'colour' => 'red',
                                    'sort'   => 0,
                                  };

      }
      $chr = $chr->next;
    }
  }
  return (\%data, $max);
}

sub create_user_features {
  my $self   = shift;
  my $hub    = $self->hub;
  my $menu   = $self->get_node('user_data');
  my $tracks = {};
  
  return $tracks unless $menu;
  
  foreach ($menu->nodes) {
    next unless $_->get('display') ne 'off'; 
    my $data   = $hub->fetch_userdata_by_id($_->id);
    my $parser = $data->{'parser'};
    
    if ($parser) {
      while (my ($type, $track) = each %{$parser->get_all_tracks}) {
        my @rows;
        foreach my $feature (@{$track->{'features'}}) {
          push @rows, {
            chr     => $feature->seqname || $feature->slice->name,
            start   => $feature->rawstart,
            end     => $feature->rawend,
            label   => $feature->id,
            gene_id => $feature->id,
            %{$feature->attribs},
          };
        }
        
        $track->{'config'}{'name'} = $data->{'name'};
        $track->{'config'}{'ftype'} = $_->get('ftype');
        
        $tracks->{$_->id}{$type} = {
          features => \@rows,
          config   => $track->{'config'}
        };
      }
    } else {
      while (my ($analysis, $track) = each %$data) {
        my @rows;
       
        foreach my $f (
          map  { $_->[0] }
          sort { $a->[1] <=> $b->[1] || $a->[2] cmp $b->[2] || $a->[3] <=> $b->[3] }
          map  {[ $_, $_->{'slice'}->seq_region_name, $_->{'start'}, $_->{'end'} ]}
          @{$track->{'features'}}
        ) {
          push @rows, {
            chr     => $f->{'slice'}->seq_region_name,
            start   => $f->{'start'},
            end     => $f->{'end'},
            length  => $f->{'length'},
            label   => "$f->{'start'}-$f->{'end'}",
            gene_id => $f->{'gene_id'},
          };
        }
        
        $tracks->{$_->id}{$analysis} = {
          features => \@rows,
          config   => $track->{'config'}
        };
      }
    }
  }
  
  return $tracks;
}

1;
