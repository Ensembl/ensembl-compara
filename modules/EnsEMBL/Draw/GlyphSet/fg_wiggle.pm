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

### MODULE AT RISK OF DELETION ##
# This module is unused in the core Ensembl code, and is at risk of
# deletion. If you have use for this module, please contact the
# Ensembl team.
### MODULE AT RISK OF DELETION ##

package EnsEMBL::Draw::GlyphSet::fg_wiggle;

### Regulatory features track? Can't find where it's used!

use strict;

use base qw(EnsEMBL::Draw::GlyphSet_wiggle_and_block);
use EnsEMBL::Web::Utils::Tombstone qw(tombstone);

sub new {
  my $self = shift;
  tombstone('2015-04-16','ds23');
  $self->SUPER::new(@_);
}

sub draw_features {
  my ($self, $wiggle) = @_;
  my $config  = $self->{'config'};
  my $colours = $self->get_colours($config->{'evidence'}->{'data'}->{'all_features'});
 
  if ($config->{'focus'}) {
    # first draw wiggle if data
    if ($config->{'focus'}->{'data'}->{'wiggle_features'}) {
      my $feature_set_data = $config->{'focus'}->{'data'}->{'wiggle_features'};
      $self->process_wiggle_data($feature_set_data);  
    }
    
    # draw block features data if any
    if ($config->{'focus'}->{'data'}->{'block_features'}) {
      my $feature_set_data = $config->{'focus'}->{'data'}->{'block_features'};
      $self->draw_blocks($feature_set_data, 'Core Evidence', undef, $colours); 
    }
  }
  
  if ($config->{'attribute'}) {
    my $histone_mod = $config->{'attribute'}{'data'}{'wiggle_features'} || $config->{'attribute'}{'data'}{'block_features'};
    
    foreach (sort keys %$histone_mod) { 
     # first draw wiggle if data
      # draw block features data
      my $block_data = $config->{'attribute'}->{'data'}->{'block_features'}->{$_};
      my $label      = 'Other evidence'; 
      $label         = 'Histone H' . substr $_, 1, 1 if /H\d/;
      
      $self->draw_blocks($block_data, $label, undef, $colours);          
    }
  }
  
  return 1; 
}

sub draw_wiggle {
  my ($self, $features, $min_score, $max_score, $colours) = @_;
  $self->draw_wiggle_plot($features, { min_score => $min_score, max_score => $max_score }, $colours);
}

sub draw_blocks {
  my ($self, $fs_data, $display_label, $bg_colour, $colours) = @_; 
  
  $self->draw_track_name($display_label, 'black', -118, 0);
  $self->draw_space_glyph;
  
  foreach my $f_set (sort { $a cmp $b  } keys %$fs_data) { 
    my $colour   = $colours->{$f_set}; 
    my $features = $fs_data->{$f_set};
    $self->draw_track_name($f_set, $colour, -108, 0, 'no_offset');
    $self->draw_block_features ($features, $colour, $f_set);
  }
  
  $self->draw_space_glyph;
}

sub get_colours {
  my ($self, $f) = @_;    

  # Assign each feature set a colour, and set the intensity based on methalation state
  my %ratio     = ( 1 => 0.6, 2 => 0.4, 3 => 0.2, 4 => 0 );
  my $colourmap = $self->{'config'}->colourmap;
  my %feature_colours;
  
  # First generate pool of colours we can draw from
  if (!exists $self->{'config'}{'pool'}) {
    my $colours = $self->my_config('colours');
    
    $self->{'config'}{'pool'} = [];
    
    if ($colours) {
      $self->{'config'}{'pool'}[$_] = $self->my_colour($_) for sort { $a <=> $b } keys %$colours;
    } else {
      $self->{'config'}{'pool'} = [qw(red blue green purple yellow orange brown black)]
    }
  }
  
  foreach my $name (keys %$f) {    
    if (!exists $feature_colours{$name}) {
      my $c = shift @{$self->{'config'}{'pool'}}; 
      
      if ($name =~ /^H\d+/) {
        # First assign a colour for most basic pattern - i.e. no methyalation state information
        my $histone_number = substr $name, 0, 2;
        my ($histone_pattern, $cell_line) = split /\:/, $name;
        
        $histone_pattern =~ s/^H\d+//; 
        $histone_pattern =~ s/me\d+//;
        $name            =~ s/me\d+//; 

        $feature_colours{$name} = $colourmap->mix($c, 'white', $ratio{4});     

        # Now add each possible methyalation state of this type with the appropriate intensity
        for (my $i = 1; $i <= 4; $i++) {   
          $histone_pattern = $histone_number . $histone_pattern unless $histone_pattern =~ /^H\d/;  
          
          if ($histone_pattern =~ /me\d+/) {
            $histone_pattern =~ s/me\d+/me$i/;
          } else {
            $histone_pattern .= "me$i:$cell_line";
          }
          
          $feature_colours{$histone_pattern} = $colourmap->mix($c, 'white', $ratio{$i});
        } 

      } else {
        $feature_colours{$name} = $colourmap->mix($c, 'white', $ratio{4});
      }
    }
  }

  return \%feature_colours;
}


sub process_wiggle_data {
  my ($self, $fs_data) = @_;
  
  my ($min_score, $max_score) == (0, 0);
  my @all_features;
  my @colours;

  foreach (keys %$fs_data) {
    my $colour   = $self->my_colour($_);
    my @features = sort { $a->score <=> $b->score } @{$fs_data->{$_}};
    
    my ($f_min_score, $f_max_score) = ($features[0]->score || 0, $features[-1]->score|| 0);
    
    $min_score = $f_min_score if $f_min_score <= $min_score;
    $max_score = $f_max_score if $f_max_score >= $max_score;
    
    push @all_features, \@features;
    push @colours, $colour;
  }
  
  $self->draw_wiggle(\@all_features, $min_score, $max_score, \@colours);
}

sub block_features_zmenu {
  my ($self, $f)  = @_;
  my $offset      = $self->{'container'}->strand > 0 ? $self->{'container'}->start - 1 :  $self->{'container'}->end + 1;
  my $pos         = $f->slice->seq_region_name . ':' . ($offset + $f->start) . '-' . ($f->end + $offset);
  my $feature_set = $f->feature_set->name;

  my $href = $self->_url({
    action => 'FeatureEvidence',
    rf     => $self->{'config'}->core_object('regulation')->stable_id,
    fdb    => 'funcgen',
    pos    => $pos,
    fs     => $feature_set,
  });

  return $href;
}

1;
