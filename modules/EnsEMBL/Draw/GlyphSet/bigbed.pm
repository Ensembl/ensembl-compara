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

package EnsEMBL::Draw::GlyphSet::bigbed;

### Module for drawing data in BigBED format (either user-attached, or
### internally configured via an ini file or database record

use strict;
use warnings;
no warnings 'uninitialized';

use List::Util qw(min max);

use Bio::EnsEMBL::IO::Adaptor::BigBedAdaptor;

use EnsEMBL::Web::File::AttachedFormat::BIGBED;
use EnsEMBL::Web::File::Utils::URL;
use EnsEMBL::Web::Text::Feature::BED;

use base qw(EnsEMBL::Draw::GlyphSet::_alignment EnsEMBL::Draw::GlyphSet_wiggle_and_block);

sub my_helplink   { return 'bigbed'; }
sub feature_id    { $_[1]->id;       }
sub feature_group { $_[1]->id;       }
sub feature_label { $_[1]->id;       }
sub feature_title { return undef;    }
sub href          { return $_[0]->_url({ action => 'UserData', id => $_[1]->id, %{$_[2]||{}} }); }
sub href_bgd      { return $_[0]->_url({ action => 'UserData' }); }

sub bigbed_adaptor {
  my ($self,$in) = @_;

  $self->{'_cache'}->{'_bigbed_adaptor'} = $in if defined $in;
 
  my $error;
  unless ($self->{'_cache'}->{'_bigbed_adaptor'}) { 
    ## Check file is available before trying to load it 
    ## (Bio::DB::BigFile does not catch C exceptions)
    my $headers = EnsEMBL::Web::File::Utils::URL::get_headers($self->my_config('url'), {
                                                                    'hub' => $self->{'config'}->hub, 
                                                                    'no_exception' => 1
                                                            });
    if ($headers) {
      if ($headers->{'Content-Type'} !~ 'text/html') { ## Not being redirected to a webpage, so chance it!
        my $ad = Bio::EnsEMBL::IO::Adaptor::BigBedAdaptor->new($self->my_config('url'));
        $error = "Broken bigbed file" unless $ad->check;
        $self->{'_cache'}->{'_bigbed_adaptor'} = $ad;
      }
      else {
        $error = "File at URL ".$self->my_config('url')." does not appear to be of type BigBed; returned MIME type ".$headers->{'Content-Type'};
      }
    }
    else {
      $error = "No HTTP headers returned by URL ".$self->my_config('url');
    }
  }
  $self->errorTrack("Could not retrieve file from trackhub") if $error;
  return $self->{'_cache'}->{'_bigbed_adaptor'};
}

sub format {
  my $self = shift;

  my $format = $self->{'_cache'}->{'format'} ||=
    EnsEMBL::Web::File::AttachedFormat::BIGBED->new(
      $self->{'config'}->hub,
      "BIGBED",
      $self->my_config('url'),
      $self->my_config('style'), # contains trackline
    );
  $format->_bigbed_adaptor($self->bigbed_adaptor);
  return $format;
}

# Switched to using score for features rather than coverage - coverage tends to be 1, with a score 
# indicating the height
#
#sub wiggle_features {
#  my ($self,$bins) = @_;
#
#  return $self->{'_cache'}->{'wiggle_features'} if exists $self->{'_cache'}->{'wiggle_features'};
# 
#  my $slice = $self->{'container'}; 
#  my $summary_e = $self->bigbed_adaptor->fetch_extended_summary_array($slice->seq_region_name, $slice->start, $slice->end, $bins);
#  my $binwidth = $slice->length/$bins;
#  my $flip = ($slice->strand == 1) ? ($slice->length + 1) : undef;
#  my @features;
#
#  for(my $i=0; $i<$bins; $i++) {
#    my $s = $summary_e->[$i];
#    my $mean = 0;
#    $mean = $s->{'sumData'}/$s->{'validCount'} if $s->{'validCount'} > 0;
#    my ($a,$b) = ($i*$binwidth+1, ($i+1)*$binwidth);
#    push @features,{
#      start => $flip ? $flip - $b : $a,
#      end => $flip ? $flip - $a : $b,
#      score => $mean,
#    };
#  }
#  
#  return $self->{'_cache'}->{'wiggle_features'} = \@features;
#}

sub wiggle_features {
  my ($self,$bins) = @_;

  return $self->{'_cache'}->{'wiggle_features'} if exists $self->{'_cache'}->{'wiggle_features'};
 
  my $slice = $self->{'container'}; 
  my $adaptor = $self->bigbed_adaptor;
  return [] unless $adaptor;
  my $features = $adaptor->fetch_features($slice->seq_region_name,$slice->start,$slice->end);
  $_->map($slice) for @$features;

  my $flip = ($slice->strand == -1) ? ($slice->length + 1) : undef;
  my @block_features;

  for(my $i=0; $i<scalar(@$features); $i++) {
    my $f = $features->[$i];
    #print STDERR "f = $f start = " . $f->start . " end =  " . $f->end . "\n";

    my ($a,$b) = ($f->start, $f->end);

    push @block_features,{
      start => $flip ? $flip - $b : $a,
      end => $flip ? $flip - $a : $b,
      score => $f->score,
#      score => $f->extra_data->{thick_start}->[0],
    };
    #print STDERR "block feature $a $b " . $f->extra_data->{thick_start}->[0] . "\n";
    #print STDERR "block feature $a $b " . $f->score . "\n";
  }
  
  return $self->{'_cache'}->{'wiggle_features'} = \@block_features;
}

sub _draw_wiggle {
  my ($self) = @_;

  my $slice = $self->{'container'};

  my $max_bins = min $self->{'config'}->image_width, $slice->length;
  my $features = $self->wiggle_features($max_bins);
  my @scores = map { $_->{'score'} } @$features;
 
  $self->draw_wiggle_plot(
    $features, {
      min_score => min(@scores),
      max_score => max(@scores),
      description => $self->my_config('caption'),
      score_colour => $self->my_config('colour'),
  }); 
  $self->draw_space_glyph();
  return (); # No error
}

sub features {
  my ($self, $options) = @_;
  my %config_in = map { $_ => $self->my_config($_) } qw(colouredscore style);
  
  $options = { %config_in, %{$options || {}} };

  my $bba       = $options->{'adaptor'} || $self->bigbed_adaptor;
  return [] unless $bba;
  my $format    = $self->format;
  my $slice     = $self->{'container'};
  my $features  = $bba->fetch_features($slice->seq_region_name, $slice->start, $slice->end + 1);
  my $config    = {};
  my $max_score = 0;
  my $key       = $self->my_config('description') =~ /external webserver/ ? 'url' : 'feature';
  
  $self->{'_default_colour'} = $self->SUPER::my_colour($self->my_config('sub_type'));
  
  foreach (@$features) {
    $_->map($slice);
    $max_score = max($max_score, $_->score);
  }
  
  # WORK OUT HOW TO CONFIGURE FEATURES FOR RENDERING
  # Explicit: Check if mode is specified on trackline
  my $style = $options->{'style'} || $format->style;

  $config->{'simpleblock_optimise'} = 1; # No joins, etc, no need for composite.

  if ($style eq 'score' && !$self->my_config('colour')) {
    $config->{'useScore'}        = 1;
    $config->{'implicit_colour'} = 1;
    $config->{'greyscale_max'}   = $max_score;
  } elsif ($style eq 'colouredscore') {
    $config->{'useScore'} = 2;    
  } else {
    $config->{'useScore'} = 2;
    
    my $default_rgb_string;
    
    if ($options->{'fallbackcolour'}) {
      $default_rgb_string = join ',', $self->{'config'}->colourmap->rgb_by_name($options->{'fallbackcolour'} eq 'default' ? $self->{'_default_colour'} : $options->{'fallbackcolour'}, 1);
    } else {
      $default_rgb_string = $self->my_config('colour') || '0,0,0';
    }
   
    foreach (@$features) {
      if ($_->external_data->{'BlockCount'}) {
        $self->{'my_config'}->set('has_blocks', 1);
      }
      my $colour = $_->external_data->{'item_colour'};
      next if defined $colour && $colour->[0] =~ /^\d+,\d+,\d+$/;
      $_->external_data->{'item_colour'}[0] = $default_rgb_string;
    }
    
    $config->{'itemRgb'} = 'on';    
  }
  
  return ($key => [ $features, { %$config, %{$format->parse_trackline($format->trackline)} } ]);
}
 
sub draw_features {
  my ($self,$wiggle) = @_;
  my @error;
  
  if ($wiggle) {
    $self->{'height'} = 30;
    push @error, $self->_draw_wiggle;
  }
  
  return 0 unless @error;
  return join ' or ', @error;
}

=pod
sub render_normal {
  my $self = shift;
  $self->SUPER::render_normal(8, 20);  
}

sub render_compact {
  my $self = shift;
  $self->{'renderer_no_join'} = 1;
  $self->SUPER::render_normal(8, 0);  
}

sub render_labels {
  my $self = shift;
  $self->{'show_labels'} = 1;
  $self->render_normal(@_);
}
=cut

sub render_text { warn "No text renderer for bigbed\n"; return ''; }

sub my_colour {
  my ($self, $k, $v) = @_;
  my $c = $self->{'parser'}{'tracks'}{$self->{'track_key'}}{'config'}{'color'} || $self->{'_default_colour'};
  return $v eq 'join' ?  $self->{'config'}->colourmap->mix($c, 'white', 0.8) : $c;
}

1;

