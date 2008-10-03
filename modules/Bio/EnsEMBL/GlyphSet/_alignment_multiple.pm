package Bio::EnsEMBL::GlyphSet::_alignment_multiple;

=head1 NAME

EnsEMBL::Web::GlyphSet::multiple_alignment;

=head1 SYNOPSIS

The multiple_alignment object handles the display of multiple alignment regions in contigview.

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Eugene Kulesha - ek@ebi.ac.uk
Fiona Cunningham - fc1@sanger.ac.uk

=cut

use strict;

use Sanger::Graphics::Bump;
use Bio::EnsEMBL::DnaDnaAlignFeature;

use Time::HiRes qw(time);

use base qw(Bio::EnsEMBL::GlyphSet_wiggle_and_block );

sub colour   { return $_[0]->{'feature_colour'}, $_[0]->{'label_colour'}, $_[0]->{'part_to_colour'}; }


sub draw_features {

  ### Called from {{ensembl-draw/modules/Bio/EnsEMBL/GlyphSet_wiggle_and_block.pm}}
  ### Arg 2 : draws wiggle plot if this is true
  ### Returns 0 if all goes well.  
  ### Returns error message to print if there are features missing (string)

  my( $self, $wiggle ) = @_;

  my $strand = $self->strand;
  my $strand_flag    = $self->my_config( 'strand' );
  my $drawn_block    = 0;
  my $caption        = $self->my_config('caption');
  my %highlights;      @highlights{$self->highlights()} = ();
  my $length         = $self->{'container'}->length;
  my $pix_per_bp     = $self->scalex;
  my $DRAW_CIGAR     = $pix_per_bp > 0.2 ;

  my $feature_type   = $self->my_config( 'constrained_element' ) ?  'element' : 'feature';

  my $feature_colour = $self->my_colour( $feature_type );
  my $feature_text   = $self->my_colour( $feature_type, 'text' );
  my $name           = $self->my_config('short_name') || $self->my_config('name');
     $feature_text   =~ s/\[\[name\]\]/$name/;
  my $h              = $self->get_parameter( 'opt_halfheight') ? 4 : 8;
  my $chr            = $self->{'container'}->seq_region_name;
  my $other_species  = $self->my_config( 'species' );
  my $short_other    = $self->species_defs->ENSEMBL_SHORTEST_ALIAS->{ $other_species };
  my $self_species   = $self->species;
  my $short_self     = $self->species_defs->ENSEMBL_SHORTEST_ALIAS->{ $self_species };
  my $jump_to_alignslice = $self->my_config( 'jump_to_alignslice');

  my $METHOD_ID      = $self->my_config( 'method_link_species_set_id' );

  my $ALIGNSLICEVIEW_TEXT_LINK = 'Jump to AlignSliceView';

  my $C = 0;
  my $X = -1e8;

  $self->timer_push('setup');
unless( $wiggle eq 'wiggle' ) {
  my $els = $self->element_features;
  $self->timer_push('got features',undef,'fetch');
  my @T = 
    sort { $a->[0] <=> $b->[0] }
    map {
      ( $strand_flag ne 'b' || $strand == $_->{strand} ) && $_->{start} <= $length && $_->{end}>=1 ?
      [ $_->{start}, $_ ] : ()
    } @$els;
  $self->timer_push('sorted features');

  foreach (@T) {
    my($START,$f) = @$_;
    my $END       = $f->{end};
    ($START,$END) = ($END, $START) if $END<$START; # Flip start end YUK!
    my( $rs,$re ) = ($f->{hstart}, $f->{hend});
    $START        = 1 if $START < 1;
    $END          = $length if $END > $length;

    next if int( $END * $pix_per_bp ) == int( $X * $pix_per_bp );
    $drawn_block = 1;
    $X = $START;

    my $href  = "/$short_self/alignsliceview?l=$chr:$rs-$re;align=opt_align_$METHOD_ID";

    my $zmenu = { 'caption'              => $caption};

    # Don't link to AlignSliceView from constrained elements!
    if ($jump_to_alignslice) {
      $zmenu->{"45:"} = '';
      $zmenu->{"50:$ALIGNSLICEVIEW_TEXT_LINK"} = $href;
    }
    $zmenu->{"01:Score = ".$f->{score}} = '' if $f->{score};

    my $id = 10; 
    my $max_contig = 250000;
    foreach my $species_name (sort keys %{$f->{fragments}}) {
      $zmenu->{"$id:$species_name"} = '';
      $id++;
      foreach my $fr (@{$f->{fragments}->{$species_name}}) {
        my $flength = abs($fr->[2] - $fr->[1]);
        (my $species = $species_name) =~ s/\s/\_/g;
        my $flink = sprintf("/%s/%s?l=%s:%d-%d", $species, $flength > $max_contig ? 'cytoview' : 'contigview', @$fr);
        my $key = sprintf("%d:&nbsp;%s: %d-%d", $id++, @$fr);
        $zmenu->{"$key"} = $flink;
        $C++;
      }
    }

    if($DRAW_CIGAR) {
      my $TO_PUSH = $self->Composite({
        'href'  => $href,
        'zmenu' => $zmenu,
        'x'     => $START-1,
        'width' => 0,
        'y'     => 0,
	'bordercolour' => $feature_colour
      });
      $self->draw_cigar_feature( $TO_PUSH, $f, $h, $feature_colour, 'black', $pix_per_bp, 1 );
      $self->push( $TO_PUSH );
    } else {
      $self->push( $self->Rect({
        'x'         => $START-1,
        'y'         => 0,
        'width'     => $END-$START+1,
        'height'    => $h,
        'colour'    => $feature_colour,
        'absolutey' => 1,
        '_feature'  => $f, 
        'href'      => $href,
        'zmenu'     => $zmenu,
      }));
    }
  }
  $self->timer_push( 'drawn features' );
  $self->_offset($h);
  $self->draw_track_name($feature_text, $feature_colour) if $drawn_block;
}
warn "WIGGLE $wiggle....";
  my $drawn_wiggle = $wiggle ? $self->wiggle_plot : 1;
  return 0 if $drawn_block && $drawn_wiggle;

  # Work out error message if some data is missing
  my @errors = ();

  push @errors, $self->my_colour($feature_type,'text' ) if !$drawn_block;
  push @errors, $self->my_colour('score',      'text' ) if $wiggle && !$drawn_wiggle;
  return join ' and ',@errors;
}

## Now generate the feature array refs...

sub element_features {
  ### Retrieves block features for constrained elements
  ### Returns arrayref of features
  my $self = shift;

  my $slice = $self->{'container'};
  my $genomic_align_blocks;
  if ($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $genomic_align_blocks = $slice->get_all_constrained_elements();
  } else {
    my $db   = $self->dbadaptor( 'multi', $self->my_config('db') );
## Get the GenomicAlignBlocks
    $genomic_align_blocks = $db->get_adaptor("GenomicAlignBlock")->fetch_all_by_MethodLinkSpeciesSet_Slice(
      $db->get_adaptor("MethodLinkSpeciesSet")->fetch_by_dbID(
        $self->my_config('constrained_element')||
	$self->my_config('method_link_species_set_id')
      ),
      $slice
    )||[];
  }

  my $T = [];
  foreach my $block (@$genomic_align_blocks) {
    my $all_gas = $block->get_all_GenomicAligns;
    my $fragments;
    foreach (@$all_gas) {
      push(@{$fragments->{$_->dnafrag->genome_db->name}}, [
        $_->dnafrag->name,
        $_->dnafrag_start,
        $_->dnafrag_end,
        $_->dnafrag_strand
      ]);
    }
    my ($rtype, $gpath, $rname, $rstart, $rend, $rstrand) = split(':',$block->reference_slice->name);
 
    push @$T, Bio::EnsEMBL::DnaDnaAlignFeature->new_fast ({
      'seqname'   => $block->reference_slice->name,
      'start'     => $block->reference_slice_start,
      'end'       => $block->reference_slice_end,
      'strand'    => $block->reference_slice_strand,

      'hseqname'  => $rname,
      'hstart'    => $rstart,
      'hend'      => $rend,
      'hstrand'   => $rstrand,

      'score'     => $block->score,
      'fragments' => $fragments
    });
  }

  return $T;
}

sub score_features {
  my $self = shift;
  my $K  = $self->my_config('conservation_score');
  my $db = $self->dbadaptor( 'multi', $self->my_config('db') );
  return [] unless $K && $db;
  $self->timer_push( 'preped score fetch' );

  my $method_link_species_set = $db->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($K);
  return [] unless $method_link_species_set;
  $self->timer_push( 'got mlss' );

  return $db->get_ConservationScoreAdaptor()->fetch_all_by_MethodLinkSpeciesSet_Slice(
    $method_link_species_set,
    $self->{'container'},
    $self->image_width  ## bins - size of track in pixels!
  ) || [];

}

sub wiggle_plot {

  ### Wiggle_plot
  ### Description: gets features for wiggle plot and passes to render_wiggle_plot
  ### Returns 1 if draws wiggles. Returns 0 if no wiggles drawn
  my $self = shift;

  $self->timer_push( 'score prefetch',undef,'draw');
  my $features = $self->score_features;
  $self->timer_push( 'got score features',undef,'fetch');
  return 0 unless scalar @$features;

warn "GOT FEATURES";
  $self->draw_space_glyph();
warn "DRAWN SPACER";
  my $min_score = 0;
  my $max_score = 0;
warn "DRAWING FEATURES...";
  foreach (@$features) {
    my $s = $_->score;
    $min_score = $s if $s < $min_score;
    $max_score = $s if $s > $max_score;
  }
warn "YAY $min_score $max_score";
  $self->draw_wiggle_plot(
    $features,                      ## Features array
    { 'min_score' => $min_score, 'max_score' => $max_score }
  );
  return 1;
  $self->timer_push( 'wiggle drawn');
}
1;
