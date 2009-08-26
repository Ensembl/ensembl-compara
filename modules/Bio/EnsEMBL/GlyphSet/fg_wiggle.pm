package Bio::EnsEMBL::GlyphSet::fg_wiggle;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet_wiggle_and_block);

sub draw_features {
 my ($self, $wiggle)= @_;
 my $Config = $self->{'config'};

  if ($Config->{'focus'}) {
    # first draw wiggle if data
    if ($Config->{'focus'}->{'data'}->{'wiggle_features'}){
      my $feature_set_data = $Config->{'focus'}->{'data'}->{'wiggle_features'};
      $self->process_wiggle_data($feature_set_data);  
    }
    # draw block features data if any
    if ($Config->{'focus'}->{'data'}->{'block_features'}){
      my $feature_set_data = $Config->{'focus'}->{'data'}->{'block_features'};
      $self->draw_blocks($feature_set_data, 'Core Evidence'); 
    }
  }  
  if ($Config->{'attribute'}) {
    my %histone_mod;
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
        $label = 'Histone ' . substr($_,1,1);
      }
      $self->draw_blocks($block_data, $label);          
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
  my ($self, $fs_data, $display_label) = @_; 
  $self->draw_track_name($display_label, 'black', -118, 10);
  foreach my $f_set (sort { $a cmp $b  } keys %$fs_data){ 
    my $colour = $self->my_colour($f_set);
    my $features = $fs_data->{$f_set};
    $self->draw_block_features ($features, $colour);
    $self->draw_track_name($f_set, $colour);  
    $self->draw_space_glyph();
  }   
  $self->draw_space_glyph();
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
  return;
}

sub render_text {
  my ($self, $display_label, $wiggle) = @_;
  
}

1;
