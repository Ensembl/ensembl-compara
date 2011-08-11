package Bio::EnsEMBL::GlyphSet::bigwig;

use strict;

use Bio::EnsEMBL::ExternalData::BigFile::BigWigAdaptor;
use Data::Dumper;

use base qw(Bio::EnsEMBL::GlyphSet_wiggle_and_block);

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
      #print STDERR "bin $i: min=$s->{minVal} max=$s->{maxVal} sum=$s->{sumData} mean=$mean\n";
#      my $feat = Bio::EnsEMBL::Feature->new_fast( {
#                         'start' => ($i*$binwidth+1),
#                         'end' => (($i+1)*$binwidth),
#                         'strand' => 1,
#                         'score' => $mean,
#                        } );
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
  #print STDERR "!!!!!!!!!!!!!!!!!!!!!!!! BIGWIG !!!!!!!!!!!!!!!\n";

  my $slice = $self->{'container'};

  my $feature_type = $self->my_config('caption');

  my $colour = $self->my_config('colour');

  #print STDERR "COLOUR = $colour\n";

  #my $colour = $self->my_colour($fset_cell_line) || 'steelblue';
  #my $colour = 'steelblue';


  # render wiggle if wiggle
  if ($wiggle) { 
    my $max_bins = $self->{'config'}->image_width();
    if ($max_bins > $slice->length) {
      $max_bins = $slice->length;
    }

    #print STDERR "max bins = $max_bins\n";
    my $features =  $self->wiggle_features($max_bins);
    $drawn_wiggle_flag = "wiggle";

    my $min_score = $features->[0]->{score};
    my $max_score = $features->[0]->{score};
    foreach my $feature (@$features) { 
      my $fscore = $feature->{score};
      if ($fscore < $min_score) { $min_score = $fscore };
      if ($fscore > $max_score) { $max_score = $fscore };
    }

      # render wiggle plot        
    $self->draw_wiggle_plot(
          $features,                      ## Features array
          { 'min_score'    => $min_score, 
            'max_score'    => $max_score, 
            'description'  =>  $self->my_config('caption'),
            'score_colour' =>  $colour,
          },
          #[$colour],
          #[$feature_type],
        );
    $self->draw_space_glyph() if $drawn_wiggle_flag;
  }

  if( !$wiggle || $wiggle eq 'both' ) { 
    warn("bigwig glyphset doesn't draw blocks\n");
  }

  my $error = $self->draw_error_tracks($drawn_wiggle_flag);
  return 1;
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


1;
