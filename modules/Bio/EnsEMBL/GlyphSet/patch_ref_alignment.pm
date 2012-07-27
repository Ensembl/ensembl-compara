package Bio::EnsEMBL::GlyphSet::patch_ref_alignment;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;

  return $self->render_text if $self->{'text_export'};

  my $container   = $self->{'container'};
  my $length      = $container->length;
  my $pix_per_bp  = $self->scalex;
  my $features    = $self->features;
  my $join_colour = $self->my_colour(lc $self->{'container'}->assembly_exception_type, 'join'); 

  foreach (0, 8) {
    $self->push($self->Rect({
      x         => 0,
      y         => $_,
      width     => $length,
      height    => 0,
      colour    => $join_colour,
      absolutey => 1,
    }));
  }

  if (scalar @$features) {
    $self->init_alignment($features);
  } else {
    $self->errorTrack('No alignments to display') if $self->{'config'}->get_option('opt_empty_tracks') == 1;
  }
}

sub init_alignment {
  my ($self, $features) = @_;
  my $length               = $self->{'container'}->length;
  my $pix_per_bp           = $self->scalex;
  my $threshold_navigation = ($self->my_config('threshold_navigation') || 2e6) * 1001;
  my $navigation           = $self->my_config('navigation') || 'on';
  my $show_navigation      = $length < $threshold_navigation && $navigation eq 'on';
  my $species              = $self->species;
  my $base_colour          = $self->my_colour(lc $self->{'container'}->assembly_exception_type);
  my $alt_colour           = $self->{'config'}->colourmap->mix($base_colour, 'white', 0.45);
  my @colours              =  ([$base_colour, $alt_colour]);

  # Draw the Contig Tiling Path
  foreach (sort { $a->{'start'} <=> $b->{'start'} } @$features) {
    my $strand = $_->strand;
    my $rend   = $_->{'end'}; 
    my $rstart = $_->{'start'}; 
    my $region = $_->{'name'};
    my $i      = 0;#$_->get_all_Attributes('hap_contig')->[0]{'value'} ? 1 : 0; # if this is a haplotype contig then need a different pair of colours for the contigs

    # AlignSlice segments can be on different strands - hence need to check if start & end need a swap
    ($rstart, $rend) = ($rend, $rstart) if $rstart > $rend;
    $rstart = 1 if $rstart < 1;
    $rend   = $length if $rend > $length;

    $self->push($self->Rect({
      x         => $rstart - 1,
      y         => 0,
      width     => $rend - $rstart + 1,
      height    => 8,
      colour    => $colours[$i]->[0],
      absolutey => 1,
      href      => $self->href($_)
    }));

    push @{$colours[$i]}, shift @{@colours[$i]};

  }
}


sub features {
  my $self = shift;
  my $method       = 'get_all_' . ($self->my_config('object_type') || 'DnaAlignFeature') . 's';
  my $db           = $self->my_config('db');
  my @logic_names  = @{$self->my_config('logic_names') || []};
  my @results = @{$self->{'container'}->$method($logic_names[0], undef, $db) || ()};

  return \@results;
}

sub href {
  ### Links to /Location/Genome

  my ($self, $f) = @_;
  my $ln     = $f->can('analysis') ? $f->analysis->logic_name : '';
  my $id     = $f->display_id;
     $id     = $f->dbID if $ln eq 'alt_seq_mapping';

  return $self->_url({
    species => $self->species,
    action  => $self->my_config('zmenu') ? $self->my_config('zmenu') : 'Genome',
    ftype   => $self->my_config('object_type') || 'DnaAlignFeature',
    db      => $self->my_config('db'),
    r       => $f->seq_region_name . ':' . $f->seq_region_start . '-' . $f->seq_region_end,
    id      => $id,
    ln      => $ln,
  });
}
 
1;

