package Bio::EnsEMBL::GlyphSet::_alignment_multiple;

use strict;

use Time::HiRes qw(time);

use Sanger::Graphics::Bump;

use Bio::EnsEMBL::DnaDnaAlignFeature;

use base qw(Bio::EnsEMBL::GlyphSet_wiggle_and_block);

sub colour { return $_[0]->{'feature_colour'}, $_[0]->{'label_colour'}, $_[0]->{'part_to_colour'}; }


sub draw_features {

  ### Called from {{ensembl-draw/modules/Bio/EnsEMBL/GlyphSet_wiggle_and_block.pm}}
  ### Arg 2 : draws wiggle plot if this is true
  ### Returns 0 if all goes well.  
  ### Returns error message to print if there are features missing (string)

  my ($self, $wiggle) = @_;
  my $strand              = $self->strand;
  my $strand_flag         = $self->my_config('strand');
  my $drawn_block         = 0;
  my $caption             = $self->my_config('caption'); 
  my $length              = $self->{'container'}->length;
  my $pix_per_bp          = $self->scalex;
  my $draw_cigar          = $self->type =~ /constrained/ ? undef : $pix_per_bp > 0.2;
  my $name                = $self->my_config('short_name') || $self->my_config('name');
  my $constrained_element = $self->my_config('constrained_element');
  my $feature_type        = $constrained_element ?  'element' : 'feature';
  my $feature_colour      = $self->my_colour($feature_type);
  my $feature_text        = $self->my_colour($feature_type, 'text' );
     $feature_text        =~ s/\[\[name\]\]/$name/;
  my $h                   = $self->get_parameter('opt_halfheight') ? 4 : 8;
  my $chr                 = $self->{'container'}->seq_region_name;
  my $chr_start           = $self->{'container'}->start;
  my $method_id           = $self->my_config('method_link_species_set_id');
  my $jump_to_alignslice  = $self->my_config('jump_to_alignslice');
  my $class               = $self->my_config('class');
  my $x                   = -1e8;
  my $zmenu               = {
    type   => 'Location',
    action => 'MultipleAlignment',
    align  => $method_id,
  };
  
  if ($wiggle ne 'wiggle') {
    foreach (sort { $a->[0] <=> $b->[0] } map { ($strand_flag ne 'b' || $strand == $_->{'strand'}) && $_->{'start'} <= $length && $_->{'end'} >= 1 ? [ $_->{'start'}, $_ ] : () } @{$self->element_features}) {
      my ($start, $f) = @$_;
      my $end         = $f->{'end'};
      my ($rs, $re)   = ($f->{'hstart'}, $f->{'hend'});
      ($start, $end)  = ($end, $start) if $end < $start; # Flip start end YUK!
      $start          = 1 if $start < 1;
      $end            = $length if $end > $length;

      next if int($end * $pix_per_bp) == int($x * $pix_per_bp);
      
      $drawn_block = 1;
      $x           = $start;

      # Don't link to AlignSliceView from constrained elements! - doesn't work in 51
      $zmenu->{'align'} = $method_id if $jump_to_alignslice;

      my $block_start = $rs;
      my $block_end   = $re;
      my $id          = 10; 
      my $max_contig  = 250000;
      
      # use 'score' param to identify constrained elements track - 
      # in which case we show coordinates just for the block
      if ($constrained_element) {
        $zmenu->{'score'} = $f->{'score'};
        $zmenu->{'ftype'} = 'ConstrainedElement';
        $zmenu->{'id'}    = $f->{'dbID'};

        $block_start = $start + $chr_start - 1;
        $block_end   = $end   + $chr_start - 1;
      } else {
        $zmenu->{'ftype'}  = 'GenomicAlignBlock';
        $zmenu->{'id'}     = $f->{'dbID'};
        $zmenu->{'ref_id'} = $f->{'ref_id'} if $f->{'ref_id'};
      }
      
      $zmenu->{'r'} = "$chr:$block_start-$block_end";
      
      if ($draw_cigar) {
        my $to_push = $self->Composite({
          href         => $self->_url($zmenu),
          x            => $start - 1,
          width        => 0,
          y            => 0,
          bordercolour => $feature_colour
        });
        
        $self->draw_cigar_feature({
          composite      => $to_push, 
          feature        => $f, 
          height         => $h, 
          feature_colour => $feature_colour, 
          delete_colour  => 'black', 
          scalex         => $pix_per_bp
        });
        
        $self->push($to_push);
      } else {
        $self->push($self->Rect({
          x         => $start - 1,
          y         => 0,
          width     => $end - $start + 1,
          height    => $h,
          colour    => $feature_colour,
          absolutey => 1,
          _feature  => $f, 
          href      => $self->_url($zmenu),
        }));
      }
    }
    
    $self->_offset($h);
    $self->draw_track_name($feature_text, $feature_colour) if $drawn_block;
  }
  
  my $drawn_wiggle = $wiggle ? $self->wiggle_plot : 1;
  
  return 0 if $drawn_block && $drawn_wiggle;

  # Work out error message if some data is missing
  my @errors;

  push @errors, $self->my_colour($feature_type, 'text') if !$drawn_block;
  push @errors, $self->my_colour('score',       'text') if $wiggle && !$drawn_wiggle;
  
  s/\[\[name\]\]/$feature_text/ for @errors;
  
  return join ' and ', @errors;
}

## Now generate the feature array refs...

sub element_features {
  ### Retrieves block features for constrained elements
  ### Returns arrayref of features
  
  my $self  = shift;
  my $slice = $self->{'container'};
  my ($features, @rtn);
  
  if ($slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice')) {
    return $slice->{'_align_slice'}->get_all_ConstrainedElements;
  } else {
    my $db                  = $self->dbadaptor('multi', $self->my_config('db'));
    my $constrained_element = $self->my_config('constrained_element');
    my $adaptor             = $db->get_adaptor($constrained_element ? 'ConstrainedElement' :  'GenomicAlignBlock');
    my $id                  = $constrained_element || $self->my_config('method_link_species_set_id');
    $features = $adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($db->get_adaptor('MethodLinkSpeciesSet')->fetch_by_dbID($id), $slice) || [];
  }
  
  foreach my $feature (@$features) {
    my ($rtype, $gpath, $rname, $rstart, $rend, $rstrand) = split ':', $feature->slice->name;
    
    push @rtn, Bio::EnsEMBL::DnaDnaAlignFeature->new_fast({
      dbID      => $feature->{'dbID'},
      ref_id    => $feature->{'reference_genomic_align_id'},
      seqname   => $feature->slice->name,
      start     => $feature->start,
      end       => $feature->end,
      strand    => 0,
      hseqname  => $rname,
      hstart    => $rstart,
      hend      => $rend,
      hstrand   => $rstrand,
      score     => $feature->score,
    });
  }
  
  return \@rtn;
}

sub score_features {
  my $self  = shift;
  my $slice = $self->{'container'};

  return $slice->display_Slice_name eq $slice->{'web_species'} ? $slice->{'_align_slice'}->get_all_ConservationScores($self->image_width) : [] if $slice->isa('Bio::EnsEMBL::Compara::AlignSlice::Slice');
  
  my $K  = $self->my_config('conservation_score');
  my $db = $self->dbadaptor('multi', $self->my_config('db'));
  
  return [] unless $K && $db;
  
  my $method_link_species_set = $db->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($K);
  
  return [] unless $method_link_species_set;

  return $db->get_ConservationScoreAdaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $self->{'container'}, $self->image_width) || [];
}

sub wiggle_plot {
  ### Wiggle_plot
  ### Description: gets features for wiggle plot and passes to render_wiggle_plot
  ### Returns 1 if draws wiggles. Returns 0 if no wiggles drawn
  
  my $self     = shift;
  my $features = $self->score_features;
  
  return 0 unless scalar @$features;

  $self->draw_space_glyph;
  
  my $min_score = 0;
  my $max_score = 0;
  
  foreach (@$features) {
    my $s = $_->score;
    $min_score = $s if $s < $min_score;
    $max_score = $s if $s > $max_score;
  }
  
  $self->draw_wiggle_plot($features, { min_score => $min_score, max_score => $max_score });
  
  return 1;
}

1;
