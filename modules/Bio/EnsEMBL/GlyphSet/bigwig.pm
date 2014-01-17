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

package Bio::EnsEMBL::GlyphSet::bigwig;

use strict;

use Bio::EnsEMBL::ExternalData::BigFile::BigWigAdaptor;
use Data::Dumper;
use Bio::EnsEMBL::SimpleFeature;
use Bio::EnsEMBL::Analysis;

use base qw(Bio::EnsEMBL::GlyphSet::_alignment  Bio::EnsEMBL::GlyphSet_wiggle_and_block);

sub my_helplink { return "bigwig"; }

# get a bigwig adaptor
sub bigwig_adaptor {
  my $self = shift;

  my $url = $self->my_config('url');
  $self->{_cache}->{_bigwig_adaptor} ||= Bio::EnsEMBL::ExternalData::BigFile::BigWigAdaptor->new($url);

  return $self->{_cache}->{_bigwig_adaptor};
}


# get the alignment features
sub wiggle_features {
  my ($self, $bins) = @_;

  my $slice = $self->{'container'};
  if (!exists($self->{_cache}->{wiggle_features})) {
    my $summary_e = $self->bigwig_adaptor->fetch_extended_summary_array($slice->seq_region_name, $slice->start, $slice->end, $bins);
    my $binwidth  = ($slice->length/$bins);
    my $flip      = $slice->strand == -1 ? $slice->length + 1 : undef;
    my @features;
    
    for (my $i=0; $i<$bins; $i++) {
      my $s = $summary_e->[$i];
      my $mean = $s->{validCount} > 0 ? $s->{sumData}/$s->{validCount} : 0;

      my $feat = {
        start => $flip ? $flip - (($i+1)*$binwidth) : ($i*$binwidth+1),
        end   => $flip ? $flip - ($i*$binwidth+1)   : (($i+1)*$binwidth),
        score => $mean
      };
      
      push @features,$feat;
    }
    
    $self->{_cache}->{wiggle_features} = \@features;
  }

  return $self->{_cache}->{wiggle_features};
}

sub draw_features {
  my ($self, $wiggle)= @_;  

  my $drawn_wiggle_flag = $wiggle ? 0: "wiggle"; 

  my $slice = $self->{'container'};

  my $feature_type = $self->my_config('caption');

  my $colour = $self->my_config('colour');

  # render wiggle if wiggle
  if ($wiggle) { 
    my $max_bins = $self->{'config'}->image_width();
    if ($max_bins > $slice->length) {
      $max_bins = $slice->length;
    }

    my $features =  $self->wiggle_features($max_bins);
    $drawn_wiggle_flag = "wiggle";

    my $min_score;
    my $max_score;

    my $viewLimits = $self->my_config('viewLimits');

    if (defined($viewLimits)) {
      ($min_score,$max_score) = split ":",$viewLimits;
    } else {
      $min_score = $features->[0]->{score};
      $max_score = $features->[0]->{score};
      foreach my $feature (@$features) { 
        my $fscore = $feature->{score};
        if ($fscore < $min_score) { $min_score = $fscore };
        if ($fscore > $max_score) { $max_score = $fscore };
      }
    }

    my $no_titles = $self->my_config('no_titles');

    my $params = { 'min_score'    => $min_score, 
                   'max_score'    => $max_score, 
                   'description'  =>  $self->my_config('caption'),
                   'score_colour' =>  $colour,
                 };

    if (defined($no_titles)) {
      $params->{'no_titles'} = 1;
    }

    # render wiggle plot        
    $self->draw_wiggle_plot(
          $features,                      ## Features array
          $params
          #[$colour],
          #[$feature_type],
        );
    $self->draw_space_glyph() if $drawn_wiggle_flag;
  }

  if( !$wiggle || $wiggle eq 'both' ) { 
    warn("bigwig glyphset doesn't draw blocks\n");
  }

  my $error = $self->draw_error_tracks($drawn_wiggle_flag);
  return 0;
}

sub features {
  my $self = shift;
  my $slice = $self->{'container'};

  my $max_bins = $self->{'config'}->image_width();
  if ($max_bins > $slice->length) {
    $max_bins = $slice->length;
  }

  my $feats =  $self->wiggle_features($max_bins);

  my @features;

  my $fake_anal = Bio::EnsEMBL::Analysis->new(-logic_name => 'fake');
  foreach my $feat (@$feats) {
    my $f = Bio::EnsEMBL::SimpleFeature->new(-start => $feat->{start}, 
                                             -end => $feat->{end}, 
                                             -slice => $slice, 
                                             -strand => 1, 
                                             -score => $feat->{score}, 
                                             -analysis => $fake_anal);
    push @features,$f;
  }

  my $config = {};

  $config->{'useScore'}        = 1;
  $config->{'implicit_colour'} = 1;
  $config->{'greyscale_max'}   = 100;

  return(
    'url' => [ \@features, $config ],
  );
}

sub draw_error_tracks {
  my ($self, $drawn_wiggle) = @_;
  return 0 if $drawn_wiggle;

  # Error messages ---------------------
  my $wiggle_name   =  $self->my_config('caption');
  my $error;
  if (!$drawn_wiggle) {
    $error = "$wiggle_name";
  }
  return $error;
}

sub render_text {
  my ($self, $wiggle) = @_;
  
  my $container = $self->{'container'};
  my $feature_type = $self->my_config('caption');

  warn("No text render implemented for bigwig\n");
  
  return '';
}

sub render_compact {
  my $self = shift;
  $self->{'renderer_no_join'} = 1;
  $self->SUPER::render_normal(8, 0);
}

sub feature_title {
  my ($self, $f, $db_name) = @_;
  return undef;
}

1;
