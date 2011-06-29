package Bio::EnsEMBL::GlyphSet::_flat_file;

use strict;

use EnsEMBL::Web::Text::FeatureParser;
use EnsEMBL::Web::TmpFile::Text;
use EnsEMBL::Web::Tools::Misc;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(Bio::EnsEMBL::GlyphSet::_alignment Bio::EnsEMBL::GlyphSet_wiggle_and_block);

sub feature_group { my ($self, $f) = @_; return $f->id; }
sub feature_label { my ($self, $f) = @_; return $f->id; }

sub draw_features {
  my ($self, $wiggle) = @_; 
 
  my %data = $self->features;
  
  return 0 unless keys %data;
  
  if ($wiggle) {
    foreach my $key ($self->sort_features_by_priority(%data)) {
      my ($features, $config)     = @{$data{$key}};
      my ($min_score, $max_score) = split ':', $config->{'viewLimits'};
      
      $min_score = $config->{'min_score'} unless $min_score;
      $max_score = $config->{'max_score'} unless $max_score;
      
      my $graph_type = 'bar';
         $graph_type = 'points' if ($config->{'useScore'} && $config->{'useScore'} == 4) || ($config->{'graphType'} && $config->{'graphType'} eq 'points');
      
      $self->draw_wiggle_plot($features, { 
        min_score    => $min_score,
        max_score    => $max_score, 
        score_colour => $config->{'color'},
        axis_colour  => 'black',
        description  => $config->{'description'},
        graph_type   => $graph_type,
      });
    }
  }
  
  return 1;
}

sub features {
  my $self         = shift;
  my $container    = $self->{'container'};
  my $species_defs = $self->species_defs;
  my $sub_type     = $self->my_config('sub_type');
  my $parser       = new EnsEMBL::Web::Text::FeatureParser($species_defs);
  my $features     = [];
  my %results;
  
  $self->{'_default_colour'} = $self->SUPER::my_colour($sub_type);
  
  $parser->filter($container->seq_region_name, $container->start, $container->end);
  
  $self->{'parser'} = $parser;
  
  if ($sub_type eq 'url') {
    my $response = EnsEMBL::Web::Tools::Misc::get_url_content($self->my_config('url'));
    
    if (my $data = $response->{'content'}) {
      $parser->parse($data, $self->my_config('format'));
    } else {
      warn "!!! $response->{'error'}";
    }
  } else {
    my $file = new EnsEMBL::Web::TmpFile::Text(filename => $self->my_config('file'));
    
    return $self->errorTrack(sprintf 'The file %s could not be found', $self->my_config('caption')) if !$file->exists && $self->strand < 0;

    my $data = $file->retrieve;
    
    return [] unless $data;

    $parser->parse($data, $self->my_config('format'));
  }

  ## Now we translate all the features to their rightful co-ordinates
  while (my ($key, $T) = each (%{$parser->{'tracks'}})) {
    $_->map($container) for @{$T->{'features'}};
    
    ## Set track depth a bit higher if there are lots of user features
    $T->{'config'}{'dep'} = scalar @{$T->{'features'}} > 20 ? 20 : scalar @{$T->{'features'}};

    ### ensure the display of the VEP features using colours corresponding to their consequence
    if ($self->my_config('format') eq 'SNP_EFFECT') {
      my %overlap_cons = %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;      
      my %cons = map { $overlap_cons{$_}{'display_term'} => $overlap_cons{$_}{'rank'} } keys %overlap_cons;
      
      @{$T->{'features'}} = sort {$cons{$a->consequence} <=> $cons{$b->consequence}} @{$T->{'features'}};
      
      my $colours = $species_defs->colour('variation');
      
      $T->{'config'}{'itemRgb'} = 'on';
      
      foreach (@{$T->{'features'}}) {
        $_->external_data->{'item_colour'}[0] = $colours->{lc $_->consequence}->{'default'};
        $_->external_data->{'Type'}[0]        = $_->consequence;
      }
    }

    $results{$key} = [$T->{'features'}, $T->{'config'}];
  }
  
  return %results;
}

sub feature_title {
  my ($self, $f, $db_name) = @_;
  
  my @strand_name = qw(- Forward Reverse);
  my $title       = sprintf(
    '%s: %s; Start: %d; End: %d; Strand: %s',
    $self->{'track_key'},
    $f->id,
    $f->seq_region_start,
    $f->seq_region_end,
    $strand_name[$f->seq_region_strand]
  );

  $title .= '; Hit start: '  . $f->hstart  if $f->hstart;
  $title .= '; Hit end: '    . $f->hend    if $f->hend;
  $title .= '; Hit strand: ' . $f->hstrand if $f->hstrand;
  $title .= '; Score: '      . $f->score   if $f->score;
  
  my %extra = $f->extra_data && ref $f->extra_data eq 'HASH' ? %{$f->extra_data} : ();
  
  foreach my $k (sort keys %extra) {
    next if $k eq '_type';
    next if $k eq 'item_colour';
    $title .= "; $k: " . join ', ', @{$extra{$k}};
  }
  
  return $title;
}

sub href {
  ### Links to /Location/Genome
  
  my ($self, $f) = @_;
  my $href = $self->{'parser'}{'tracks'}{$self->{'track_key'}}{'config'}{'url'};
     $href =~ s/\$\$/$f->id/e;
  return $href;
}

# Stupid function is stupid
sub colour_key {
  my ($self, $k) = @_;
  return $k;
}

sub my_colour {
  my ($self, $k, $v) = @_;
  my $c = $self->{'parser'}{'tracks'}{$self->{'track_key'}}{'config'}{'color'} || $self->{'_default_colour'};
  return $v eq 'join' ?  $self->{'config'}->colourmap->mix($c, 'white', 0.8) : $c;
}

1;
