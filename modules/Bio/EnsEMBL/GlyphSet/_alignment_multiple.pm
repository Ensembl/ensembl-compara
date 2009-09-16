package Bio::EnsEMBL::GlyphSet::_alignment_multiple;

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
  if ( $self->check() =~/constrained/) { $DRAW_CIGAR = undef;}

  my $feature_type   = $self->my_config( 'constrained_element' ) ?  'element' : 'feature';

  my $feature_colour = $self->my_colour( $feature_type );
  my $feature_text   = $self->my_colour( $feature_type, 'text' );
  my $name           = $self->my_config('short_name') || $self->my_config('name');
     $feature_text   =~ s/\[\[name\]\]/$name/;
  my $h              = $self->get_parameter( 'opt_halfheight') ? 4 : 8;
  my $chr            = $self->{'container'}->seq_region_name;
  my $chr_start      = $self->{'container'}->start;
  my $other_species  = $self->my_config( 'species' );
  my $short_other    = $self->species_defs->ENSEMBL_SHORTEST_ALIAS->{ $other_species };
  my $self_species   = $self->species;
  my $short_self     = $self->species_defs->ENSEMBL_SHORTEST_ALIAS->{ $self_species };
  my $jump_to_alignslice = $self->my_config( 'jump_to_alignslice');
  my $METHOD_ID      = $self->my_config( 'method_link_species_set_id' );
  my $zmenu = {
      'type'   => 'Location',
      'action' => 'Compara_Alignments',
      'align'  => $METHOD_ID,
  };

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

      # Don't link to AlignSliceView from constrained elements! - doesn't work in 51
      if ($jump_to_alignslice) {
        $zmenu->{'align'}  => $METHOD_ID,
      }

      my $block_start = $rs;
      my $block_end   = $re;

      #use 'score' param to identify constrained elements track - 
      #in which case we show coordinates just for the block
      if ($self->my_config('constrained_element')) {
          $zmenu->{'score'} = $f->{'score'};
          $zmenu->{'ftype'} = "ConstrainedElement";
          $zmenu->{'id'} = $f->{'dbID'};
          $block_start = $START+$chr_start-1;
          $block_end   = $END  +$chr_start-1;
      } else {
          my $class = $self->my_config( 'class' );
          $zmenu->{'ftype'} = "GenomicAlignBlock";
          $zmenu->{'id'} = $f->{'dbID'};
          $zmenu->{'ref_id'} = $f->{'ref_id'} if ($f->{'ref_id'});
      }
      $zmenu->{'r'}     = "$chr:$block_start-$block_end";

      my $id = 10; 
      my $max_contig = 250000;

      if($DRAW_CIGAR) {
        my $TO_PUSH = $self->Composite({
          'href'  => $self->_url($zmenu),
          'x'     => $START-1,
          'width' => 0,
          'y'     => 0,
          'bordercolour' => $feature_colour
        });
        
        $self->draw_cigar_feature({
          composite      => $TO_PUSH, 
          feature        => $f, 
          height         => $h, 
          feature_colour => $feature_colour, 
          delete_colour  => 'black', 
          scalex         => $pix_per_bp, 
          do_not_flip    => 1
        });
        
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
          'href'      => $self->_url($zmenu),
        }));
      }
    }
    $self->timer_push( 'drawn features' );
    $self->_offset($h);
    $self->draw_track_name($feature_text, $feature_colour) if $drawn_block;
  }
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
  my $features;
  if ($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $features = $slice->get_all_constrained_elements();
  } else {
$self->timer_push('STARTING_API_CALL',5,'fetch');
    my $db   = $self->dbadaptor( 'multi', $self->my_config('db') );
## Get the Elements
    if ($self->my_config('constrained_element')) {
      $features = $db->get_adaptor("ConstrainedElement")->fetch_all_by_MethodLinkSpeciesSet_Slice(
        $db->get_adaptor("MethodLinkSpeciesSet")->fetch_by_dbID(
          $self->my_config('constrained_element')),
          $slice
        )||[];
    } else {
      $features = $db->get_adaptor("GenomicAlignBlock")->fetch_all_by_MethodLinkSpeciesSet_Slice(
        $db->get_adaptor("MethodLinkSpeciesSet")->fetch_by_dbID(
          $self->my_config('method_link_species_set_id')),
          $slice
        )||[];
    }
$self->timer_push('ENDING_API_CALL',5,'fetch');
  }

  my $T = [];
  foreach my $feature (@$features) {
    my $fragments;
if(0){
    my $all_gas = $feature->get_all_GenomicAligns;
    foreach (@$all_gas) {
      push(@{$fragments->{$_->dnafrag->genome_db->name}}, [
        $_->dnafrag->name,
        $_->dnafrag_start,
        $_->dnafrag_end,
        $_->dnafrag_strand
      ]);
    }
}
    my ($rtype, $gpath, $rname, $rstart, $rend, $rstrand) = split(':',$feature->slice->name);
    push @$T, Bio::EnsEMBL::DnaDnaAlignFeature->new_fast ({
      'dbID'      => $feature->{dbID},
      'ref_id'    => $feature->{reference_genomic_align_id},

      'seqname'   => $feature->slice->name,
      'start'     => $feature->start,
      'end'       => $feature->end,
      'strand'    => 0,

      'hseqname'  => $rname,
      'hstart'    => $rstart,
      'hend'      => $rend,
      'hstrand'   => $rstrand,

      'score'     => $feature->score,
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

  $self->draw_space_glyph();
  my $min_score = 0;
  my $max_score = 0;
  foreach (@$features) {
    my $s = $_->score;
    $min_score = $s if $s < $min_score;
    $max_score = $s if $s > $max_score;
  }
  $self->draw_wiggle_plot(
    $features,                      ## Features array
    { 'min_score' => $min_score, 'max_score' => $max_score }
  );
  return 1;
  $self->timer_push( 'wiggle drawn');
}

sub export_feature {
  my $self = shift;
  my ($feature, $feature_type, $extra, $default) = @_;
  
  my $species = $self->species;
  my $sp = $self->species_defs->multi_hash->{'DATABASE_COMPARA'}{'ALIGNMENTS'}{$self->my_config('method_link_species_set_id')}{'species'};

  return $self->_render_text($feature, $feature_type, $extra, $default);
}

1;
