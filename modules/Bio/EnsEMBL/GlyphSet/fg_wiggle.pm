package Bio::EnsEMBL::GlyphSet::fg_wiggle;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_wiggle_and_block);

sub draw_features {
  my ($self, $wiggle)= @_;
  my $Config = $self->{'config'};
  my $colours = $self->get_colours($Config->{'evidence'}->{'data'}->{'all_features'});
 

  if ($Config->{'focus'}) {
    # first draw wiggle if data
    if ($Config->{'focus'}->{'data'}->{'wiggle_features'}){
      my $feature_set_data = $Config->{'focus'}->{'data'}->{'wiggle_features'};
      $self->process_wiggle_data($feature_set_data);  
    }
    # draw block features data if any
    if ($Config->{'focus'}->{'data'}->{'block_features'}){
      my $feature_set_data = $Config->{'focus'}->{'data'}->{'block_features'};
      $self->draw_blocks($feature_set_data, 'Core Evidence', undef, $colours); 
    }
  }  
  if ($Config->{'attribute'}) {
    my (%histone_mod);
    if ($Config->{'attribute'}->{'data'}->{'wiggle_features'}) {
      %histone_mod = %{$Config->{'attribute'}->{'data'}->{'wiggle_features'}};
    }
    else {
      %histone_mod = %{$Config->{'attribute'}->{'data'}->{'block_features'}};
    }
    foreach (sort keys %histone_mod){ 
     # first draw wiggle if data
      # draw block features data
      my $block_data = $Config->{'attribute'}->{'data'}->{'block_features'}->{$_};
      my $label = 'Other evidence';  
      if ($_ =~/H\d/){
        $label = 'Histone H' . substr($_,1,1);
      }
      $self->draw_blocks($block_data, $label, undef, $colours);          
    }
  }
 return 1; 
}

sub draw_wiggle {
  my ( $self, $features, $min_score, $max_score, $colours ) = @_;
    $self->draw_wiggle_plot(
      $features,                      ## Features array
      { 'min_score' => $min_score, 'max_score' => $max_score },
      $colours
    );
}

sub draw_blocks {
  my ($self, $fs_data, $display_label, $bg_colour, $colours) = @_; 
  $self->draw_track_name($display_label, 'black', -118, 0);
  $self->draw_space_glyph();
  
  foreach my $f_set (sort { $a cmp $b  } keys %$fs_data){ 
    my $colour   = $colours->{$f_set}; 
    my $features = $fs_data->{$f_set};
    $self->draw_track_name($f_set, $colour, -108, 0, 'no_offset');
    $self->draw_block_features ($features, $colour, $f_set);
  }   
  $self->draw_space_glyph();
}

sub get_colours {
  my( $self, $f ) = @_;    
  my %feature_colours;

  # First generate pool of colours we can draw from
  unless(exists $self->{'config'}{'pool'}) {
    $self->{'config'}{'pool'} = [];
    my $colours = $self->my_config('colours');
    if( $colours ) {
      foreach (sort { $a <=> $b } keys %$colours ) {
        $self->{'config'}{'pool'}[$_] = $self->my_colour( $_ );
      }
    } else {
      $self->{'config'}{'pool'} = [qw(red blue green purple yellow orange brown black)]
    }
  }

  # Assign each feature set a colour, and set the intensity based on methalation state
  my %ratio = ('1' => '0.6', '2' => '0.4', '3' => '0.2', '4' => '0');

  foreach my $name ( keys %$f){    
    unless ( exists $feature_colours{$name}) {
      my $c = shift @{$self->{'config'}{'pool'}}; 
      if ($name =~/^H\d+/){ 
        # First assign a colour for most basic pattern - i.e. no methyalation state information
        my ($histone_pattern, $cell_line) = split (/\:/, $name);
        my $histone_number = substr($name,0,2);
        $histone_pattern =~s/^H\d+//; 
        $histone_pattern =~s/me\d+//;
        $name =~s/me\d+//; 
        my $r =  $ratio{4};
        my $colour_mix = $self->{'config'}->colourmap->mix($c, 'white', $r); 
        $feature_colours{$name} = $colour_mix;     

        # Now add each possible methyalation state of this type with the appropriate intensity
        for (my $i =1; $i <= 4; $i++){
          unless ($histone_pattern =~/^H\d/){    
            $histone_pattern = $histone_number .$histone_pattern;  
          }
          if ($histone_pattern =~/me\d+/){
            $histone_pattern =~s/me\d+/me$i/;
          }     
          else {
            $histone_pattern .= 'me'.$i .":". $cell_line;
          }

          my $r =  $ratio{$i}; 
          my $colour_mix = $self->{'config'}->colourmap->mix($c, 'white', $r);
          $feature_colours{$histone_pattern} = $colour_mix;
        } 

      } else {
        my $r = $ratio{4};
        my $colour_mix = $self->{'config'}->colourmap->mix($c, 'white', $r);
        $feature_colours{$name} = $colour_mix;
      }
    }
  }

  return \%feature_colours;
}


sub process_wiggle_data {
  my ($self, $fs_data) = @_;
  my ($min_score, $max_score) ==  (0, 0);
  my @all_features;
  my @colours;

  foreach (keys %$fs_data){ warn $_; 
    my @features = @{$fs_data->{$_}};
    @features = sort { $a->score <=> $b->score  } @features;
    my ($f_min_score, $f_max_score) = ($features[0]->score || 0, $features[-1]->score|| 0);
    if ($f_min_score <= $min_score){ $min_score = $f_min_score; }
    if ($f_max_score >= $max_score){ $max_score = $f_max_score; }
    my $colour = $self->my_colour($_);
    push @all_features, \@features;
    push @colours, $colour;
  }
  $self->draw_wiggle( \@all_features, $min_score, $max_score, \@colours );
}

sub block_features_zmenu {
  my ($self, $f) = @_;
  my $offset = $self->{'container'}->strand > 0 ? $self->{'container'}->start - 1 :  $self->{'container'}->end + 1;
  my $pos = $f->slice->seq_region_name .":". ($offset + $f->start )."-".($f->end+$offset);
  my $feature_set = $f->feature_set->name;

  my $id = $self->{'config'}->core_objects->regulation->stable_id;
  my $href = $self->_url
  ({
    'action'  => 'FeatureEvidence',
    'rf'      => $id,
    'fdb'     => 'funcgen',
    'pos'     => $pos,
    'fs'      => $feature_set,
  });

  return $href;
}


1;
