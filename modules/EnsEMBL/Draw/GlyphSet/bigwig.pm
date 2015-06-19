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

package EnsEMBL::Draw::GlyphSet::bigwig;

### Module for drawing data in BigWIG format (either user-attached, or
### internally configured via an ini file or database record

use strict;

use List::Util qw(min max);

use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::IO::Adaptor::BigWigAdaptor;

# Temporary hack while dependencies are fixes, 2015-04-20
use Bio::EnsEMBL::ExternalData::BigFile::BigWigAdaptor;

use EnsEMBL::Web::File::Utils::URL;

use base qw(EnsEMBL::Draw::GlyphSet::_alignment EnsEMBL::Draw::GlyphSet_wiggle_and_block);

sub href_bgd       { return $_[0]->_url({ action => 'UserData' }); }
sub wiggle_subtitle { return $_[0]->my_config('caption'); }

sub bigwig_adaptor { 
  my $self = shift;

  my $url = $self->my_config('url');
  my $error;
  if ($url && $url =~ /^(http|ftp)/) { ## remote bigwig file
    unless ($self->{'_cache'}->{'_bigwig_adaptor'}) {
      ## Check file is available before trying to load it 
      ## (Bio::DB::BigFile does not catch C exceptions)
      my $headers = EnsEMBL::Web::File::Utils::URL::get_headers($url, {
                                                                    'hub' => $self->{'config'}->hub, 
                                                                    'no_exception' => 1
                                                            });
      if ($headers) {
        if ($headers->{'Content-Type'} !~ 'text/html') { ## Not being redirected to a webpage, so chance it!
          my $ad = Bio::EnsEMBL::IO::Adaptor::BigWigAdaptor->new($url);
          $error = "Bad BigWIG data" unless $ad->check;
          $self->{'_cache'}->{'_bigwig_adaptor'} = $ad;
        }
        else {
          $error = "File at URL $url does not appear to be of type BigWig; returned MIME type ".$headers->{'Content-Type'};
        }
      }
      else {
        $error = "No HTTP headers returned by URL $url";
      }
    }
    $self->errorTrack('Could not retrieve file from trackhub') if $error;
  }
  else { ## local bigwig file
    my $config    = $self->{'config'};
    my $hub       = $config->hub;
    my $dba       = $hub->database($self->my_config('type'), $self->species);

    if ($dba) {
      my $dfa = $dba->get_DataFileAdaptor();
      $dfa->global_base_path($hub->species_defs->DATAFILE_BASE_PATH);
      my ($logic_name) = @{$self->my_config('logic_names')||[]};
      my ($df) = @{$dfa->fetch_all_by_logic_name($logic_name)||[]};

      $self->{_cache}->{_bigwig_adaptor} ||= $df->get_ExternalAdaptor(undef, 'BIGWIG');
    }
  }
  return $self->{_cache}->{_bigwig_adaptor};
}

sub render_compact { $_[0]->render_normal(8, 0); }

sub render_normal {
  my $self = shift;
  
  return if $self->strand != 1;
  return $self->render_text if $self->{'text_export'};

  my $agg = $self->wiggle_aggregate();

  my $h               = @_ ? shift : ($self->my_config('height') || 8);
     $h               = $self->{'extras'}{'height'} if $self->{'extras'} && $self->{'extras'}{'height'};
  my $name            = $self->my_config('name');
  my @greyscale       = qw(ffffff d8d8d8 cccccc a8a8a8 999999 787878 666666 484848 333333 181818 000000);

  $self->push($self->Barcode({
    values    => $agg->{'values'},
    x         => 1,
    y         => 0,
    height    => $h,
    unit      => $agg->{'unit'},
    max       => $agg->{'max'},
    colours   => \@greyscale,
  }));
  $self->_render_hidden_bgd($h) if @{$agg->{'values'}};
  
  $self->errorTrack("No features from '$name' on this strand") unless @{$agg->{'values'}} || $self->{'no_empty_track_message'} || $self->{'config'}->get_option('opt_empty_tracks') == 0;
}

sub render_text {
  my ($self, $wiggle) = @_;
  warn 'No text render implemented for bigwig';
  return '';
}

sub bins {
  my ($self) = @_;

  if(!$self->{'_bins'}) {
    my $slice = $self->{'container'};
    $self->{'_bins'} = min($self->{'config'}->image_width, $slice->length);
  }
  return $self->{'_bins'};
}

sub features {
  my ($self, $bins, $cache_key) = @_;
  $bins ||= $self->bins;
  my $slice         = $self->{'container'};
  my $fake_analysis = Bio::EnsEMBL::Analysis->new(-logic_name => 'fake');
  my @features;
  
  foreach (@{$self->wiggle_features($bins, $cache_key)}) {
    push @features, {
      start    => $_->{'start'}, 
      end      => $_->{'end'}, 
      score    => $_->{'score'}, 
      slice    => $slice, 
      analysis => $fake_analysis,
      strand   => 1, 
    };
  }
  
  return \@features;
}

# get the alignment features
sub wiggle_aggregate {
  my ($self) = @_;
  my $hub = $self->{'config'}->hub;
  my $has_chrs = scalar(@{$hub->species_defs->ENSEMBL_CHROMOSOMES});

  if (!$self->{'_cache'}{'wiggle_aggregate'}) {
    my $slice     = $self->{'container'};
    my $bins      = min($self->{'config'}->image_width, $slice->length);
    my $adaptor   = $self->bigwig_adaptor;
    return [] unless $adaptor;
    my $values   = $adaptor->fetch_summary_array($slice->seq_region_name, $slice->start, $slice->end, $bins, $has_chrs);
    my $bin_width = $slice->length / $bins;
    my $flip      = $slice->strand == -1 ? $slice->length + 1 : undef;

    $self->{'_cache'}{'wiggle_aggregate'} = {
      unit => $bin_width,
      length => $slice->length,
      strand => $slice->strand,
      max => max(@$values),
      values => $values,
    };
  }

  return $self->{'_cache'}{'wiggle_aggregate'};
}

sub _max_val {
  my ($self) = @_;

  # TODO cache output so as not to re-call
  my $hub = $self->{'config'}->hub;
  my $has_chrs = scalar(@{$hub->species_defs->ENSEMBL_CHROMOSOMES});
  my $slice = $self->{'container'};
  my $adaptor = $self->bigwig_adaptor;
  my $max_val = $adaptor->fetch_summary_array($slice->seq_region_name, $slice->start, $slice->end, $self->bins, $has_chrs);
  return max(@$max_val);
}

sub gang_prepare {
  my ($self,$gang) = @_;

  my $max = $self->_max_val;
  $gang->{'max'} = max($gang->{'max'}||0,$max);
}

# get the alignment features
sub wiggle_features {
  my ($self, $bins, $multi_key) = @_;
  my $hub = $self->{'config'}->hub;
  my $has_chrs = scalar(@{$hub->species_defs->ENSEMBL_CHROMOSOMES});
  
  my $wiggle_features = $multi_key ? $self->{'_cache'}{'wiggle_features'}{$multi_key} 
                                   : $self->{'_cache'}{'wiggle_features'}; 

  if (!$wiggle_features) {
    my $slice     = $self->{'container'};
    my $adaptor   = $self->bigwig_adaptor;
    return [] unless $adaptor;

    my $summary   = $adaptor->fetch_summary_array($slice->seq_region_name, $slice->start, $slice->end, $bins, $has_chrs);
    my $bin_width = $slice->length / $bins;
    my $flip      = $slice->strand == -1 ? $slice->length + 1 : undef;
    $wiggle_features = [];
    
    for (my $i = 0; $i < $bins; $i++) {
      next unless defined $summary->[$i];
      push @$wiggle_features, {
        start => $flip ? $flip - (($i + 1) * $bin_width) : ($i * $bin_width + 1),
        end   => $flip ? $flip - ($i * $bin_width + 1)   : (($i + 1) * $bin_width),
        score => $summary->[$i],
      };
    }
  
    if ($multi_key) {
      $self->{'_cache'}{'wiggle_features'}{$multi_key} = $wiggle_features;
    }
    else {
      $self->{'_cache'}{'wiggle_features'} = $wiggle_features;
    }
  }
  
  return $wiggle_features;
}

sub draw_features {
  my ($self, $wiggle) = @_;
  my $slice        = $self->{'container'};
  my $colour       = $self->my_config('colour') || 'slategray';

  # render wiggle if wiggle
  if ($wiggle) {
    my $agg = $self->wiggle_aggregate();

    my $viewLimits = $self->my_config('viewLimits');
    my $no_titles  = $self->my_config('no_titles');
    # TODO barcode renderer cannot cope with minimum score being non-zero
    my $max_score;
    my $signal_range = $self->my_config('signal_range');
    if(defined $signal_range) {
      $max_score = $signal_range->[1];
    }
    unless(defined $max_score) {
      if (defined $viewLimits) {
        $max_score = [ split ':', $viewLimits ]->[1];
      } else {
        $max_score = $agg->{'max'};
      }
    }
   
    my $gang = $self->gang();
    if($gang and $gang->{'max'}) {
      $max_score = $gang->{'max'};
    }

    # render wiggle plot
    my $height = $self->my_config('height') || 60;
    $self->draw_wiggle_plot($agg->{'values'}, {
      min_score    => 0,
      max_score    => $max_score,
      score_colour => $colour,
      axis_colour  => $colour,
      no_titles    => defined $no_titles,
      unit         => $agg->{'unit'},
      height       => $height,
      graph_type   => 'bar',
    });
    $self->_render_hidden_bgd($height) if @{$agg->{'values'}};
  }

  warn q{bigwig glyphset doesn't draw blocks} if !$wiggle || $wiggle eq 'both';
  
  return 0;
}

1;
