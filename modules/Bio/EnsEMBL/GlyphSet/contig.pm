package Bio::EnsEMBL::GlyphSet::contig;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;
  
  return $self->render_text if $self->{'text_export'};
  
  # only draw contigs once - on one strand
  if ($self->species_defs->NO_SEQUENCE) {
    $self->errorTrack('Clone map - no sequence to display');
    return;
  }
  
  my ($fontname, $fontsize) = $self->get_font_details('innertext');
  my $container  = $self->{'container'};
  my $length     = $container->length;
  my $h          = [ $self->get_text_width(0, 'X', '', font => $fontname, ptsize => $fontsize) ]->[3];
  my $box_h      = $self->my_config('h');
  my $pix_per_bp = $self->scalex;
  my $features   = $self->features;
  
  if (!$box_h) {
    $box_h = $h + 4;
  } elsif ($box_h < $h + 4) {
    $h = 0;
  }
  
  foreach (0, $box_h) {
    $self->push($self->Rect({
      x         => 0,
      y         => $_,
      width     => $length,
      height    => 0,
      colour    => 'grey50',
      absolutey => 1,
    }));
  }
  
  if (scalar @$features) {
    $self->init_contigs($h, $box_h, $fontname, $fontsize, $features);
  } else {
    $self->errorTrack($container->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice') && $self->get_parameter('compara') ne 'primary' ? 'Alignment gap - no contigs to display' : 'Golden path gap - no contigs to display');
  }
}

sub init_contigs {
  my ($self, $h, $box_h, $fontname, $fontsize, $contig_tiling_path) = @_;
  my $length               = $self->{'container'}->length;
  my $pix_per_bp           = $self->scalex;
  my $threshold_navigation = ($self->my_config('threshold_navigation') || 2e6) * 1001;
  my $navigation           = $self->my_config('navigation') || 'on';
  my $show_navigation      = $length < $threshold_navigation && $navigation eq 'on';
  my $species              = $self->species;
  my @colours              = ([ 'contigblue1', 'contigblue2' ], [ 'lightgoldenrod1', 'lightgoldenrod3' ]);
  my @label_colours        = qw(white black);
  
  # Draw the Contig Tiling Path
  foreach (sort { $a->{'from_start'} <=> $b->{'from_start'} } @$contig_tiling_path) {
    my $strand = $_->strand;
    my $rend   = $_->{'from_end'};
    my $rstart = $_->{'from_start'};
    my $region = $_->{'name'};
    my $i      = $_->get_all_Attributes('hap_contig')->[0]{'value'} ? 1 : 0; # if this is a haplotype contig then need a different pair of colours for the contigs
    
    # AlignSlice segments can be on different strands - hence need to check if start & end need a swap
    ($rstart, $rend) = ($rend, $rstart) if $rstart > $rend;
    $rstart = 1 if $rstart < 1;
    $rend   = $length if $rend > $length;
    
    $self->push($self->Rect({
      x         => $rstart - 1,
      y         => 0,
      width     => $rend - $rstart + 1,
      height    => $box_h,
      colour    => $colours[$i]->[0],
      absolutey => 1,
      title     => $region,
      href      => $show_navigation && $species ne 'ancestral_sequences' ? $self->href($_) : ''
    }));

    push @{$colours[$i]}, shift @{@colours[$i]};

    if ($h) {
      my @res = $self->get_text_width(($rend - $rstart) * $pix_per_bp, $self->feature_label($_), $strand > 0 ? '>' : '<', font => $fontname, ptsize => $fontsize);
      
      if ($res[0]) {
        $self->push($self->Text({
          x         => ($rend + $rstart - $res[2] / $pix_per_bp) / 2,
          height    => $res[3],
          width     => $res[2] / $pix_per_bp,
          textwidth => $res[2],
          y         => ($h - $res[3]) / 2,
          font      => $fontname,
          ptsize    => $fontsize,
          colour    => $label_colours[$i],
          text      => $res[0],
          absolutey => 1
        }));
      }
    }
  }
}

sub render_text {
  my $self = shift;
  
  return if $self->species_defs->NO_SEQUENCE;
  
  my $export;  
  
  foreach (@{$self->features}) {
    $export .= $self->_render_text($_, 'Contig', { headers => [ 'id' ], values => [ $_->{'name'} ] }, {
      seqname => $_->seq_region_name,
      start   => $_->start, 
      end     => $_->end, 
      strand  => $_->strand
    });
  }
  
  return $export;
}

sub features {
  my $self      = shift;
  my $container = $self->{'container'};
  my $adaptor   = $container->adaptor;
  my @features;
  
  foreach (@{$container->project('seqlevel') || []}) {
    my $ctg_slice     = $_->to_Slice;
    my $name          = $ctg_slice->coord_system->name eq 'ancestralsegment' ? $ctg_slice->{'_tree'} : $ctg_slice->seq_region_name; # This is a Slice of Ancestral sequences: display the tree instead of the ID
    my $feature_slice = $adaptor ? $adaptor->fetch_by_region('seqlevel', $name)->project('toplevel')->[0]->to_Slice : $ctg_slice;
    
    $feature_slice->{'from_start'} = $_->from_start;
    $feature_slice->{'from_end'}   = $_->from_end;
    $feature_slice->{'name'}       = $name;
    
    push @features, $feature_slice;
  }
  
  return \@features;
}

sub href {
  my ($self, $f) = @_;
  
  return $self->_url({
    species => $self->species,
    type    => 'Location',
    action  => 'Contig',
    region  => $f->{'name'},
    r       => undef
  });
}

sub feature_label {
  my ($self, $f) = @_;
  return $f->strand == 1 ? "$f->{'name'} >" : "< $f->{'name'}";
}

1;
