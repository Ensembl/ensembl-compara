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

sub init_label {
  my ($self) = @_;
  return if( defined $self->{'config'}->{'_no_label'} );
  my $HELP_LINK = $self->check();
  if ($self->my_config('label') eq 'Conservation') {
    $self->bumped( $self->{'config'}->get($HELP_LINK, 'compact') ? 'no' : 'yes' ); # makes track expandable
  }
  $self->init_label_text( $self->my_config('label')||'---', 'compara_alignment' );
}

sub colour   { return $_[0]->{'feature_colour'}, $_[0]->{'label_colour'}, $_[0]->{'part_to_colour'}; }


sub draw_features {

  ### Called from {{ensembl-draw/modules/Bio/EnsEMBL/GlyphSet/wiggle_and_block.pm}}
  ### Arg 2 : draws wiggle plot if this is true
  ### Returns 0 if all goes well.  
  ### Returns error message to print if there are features missing (string)

  my ($self, $db, $wiggle) = @_;
  my $type = $self->check();
  return unless defined $type;  ## No defined type arghhh!!

  my $strand = $self->strand;
  my $Config = $self->{'config'};
  my $strand_flag    = $Config->get($type, 'str');
  return if( $strand_flag eq 'r' && $strand != -1 || $strand_flag eq 'f' && $strand != 1 );
  my $drawn_block    = 0;
  my $container      = $self->{'container'};
  my $caption        = $Config->get($type,'title')||$Config->get($type,'label')||'Comparative alignment';
  my %highlights;
  @highlights{$self->highlights()} = ();
  my $length         = $container->length;
  my $pix_per_bp     = $Config->transform()->{'scalex'};
  my $DRAW_CIGAR     = $pix_per_bp > 0.2 ;
  my $feature_colour = $Config->get($type, 'col');
  my $h              = $Config->get('_settings','opt_halfheight') ? 4 : 8;
  my $chr       = $self->{'container'}->seq_region_name;
  my $other_species  = $Config->get($type, 'species' );
  my $short_other    = $Config->species_defs->ENSEMBL_SHORTEST_ALIAS->{ $other_species };
  my $self_species   = $container->{_config_file_name_};
  my $short_self     = $Config->species_defs->ENSEMBL_SHORTEST_ALIAS->{ $self_species };
  my $jump_to_alignslice = $Config->get($type, 'jump_to_alignslice');

  my $METHOD_ID         = $Config->get($type, 'method_id' );

  my $ALIGNSLICEVIEW_TEXT_LINK = 'Jump to AlignSliceView';

  my( $T,$C1,$C) = (0, 0, 0 ); ## Diagnostic counters....
  my $X = -1e8;

  my @T = sort { $a->[0] <=> $b->[0] }
    map { [$_->{start}, $_ ] }
    grep { !( ($strand_flag eq 'b' && $strand != $_->{strand}) ||
              ($_->{start} > $length) ||
              ($_->{end} < 1)
	      ) } @{$self->features( $other_species, $METHOD_ID, $db )};

  foreach (@T) {
    $drawn_block = 1;
    my $f       = $_->[1];
    my $START   = $_->[0];
    my $END     = $f->{end};
    ($START,$END) = ($END, $START) if $END<$START; # Flip start end YUK!
    my( $rs, $re ) = ($f->{hstart}, $f->{hend});
    $START      = 1 if $START < 1;
    $END        = $length if $END > $length;

    next if int( $END * $pix_per_bp ) == int( $X * $pix_per_bp );
    $X = $START;

    my $TO_PUSH;
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
      $TO_PUSH = $self->Composite({
        'href'  => $href,
        'zmenu' => $zmenu,
        'x'     => $START-1,
        'width' => 0,
        'y'     => 0
      });
      $self->draw_cigar_feature($TO_PUSH, $f, $h, $feature_colour, 'black', $pix_per_bp, 1 );
      $TO_PUSH->bordercolour($feature_colour);
    } else {
      $TO_PUSH = $self->Rect({
        'x'          => $START-1,
        'y'          => 0,
        'width'      => $END-$START+1,
        'height'     => $h,
        'colour'     => $feature_colour,
        'absolutey'  => 1,
        '_feature'   => $f, 
        'href'  => $href,
        'zmenu' => $zmenu,
      });
    }
    $self->push( $TO_PUSH );
  }
  $self->_offset($h);
  $self->render_track_name($caption, $feature_colour) if $drawn_block;

  my $drawn_wiggle = $wiggle ? $self->wiggle_plot($db): 1;
  return 0 if $drawn_block && $drawn_wiggle;

  # Work out error message if some data is missing
  my $error;
  my $track = $self->{'config'}->get($type, 'label');

  if (!$drawn_block) {
    my $block_name =  $self->my_config('block_name') ||  $self->my_config('label');
    $error .= $track eq 'Conservation' ? $block_name: $track;
  }

  if ($wiggle && !$drawn_wiggle) {
    $error .= " and ". $self->my_config('wiggle_name');
  }
  return $error;
}




sub features {

  ### Retrieves block features for constrained elements
  ### Returns arrayref of features

  my ($self, $species, $method_id, $db ) = @_;

  my $slice = $self->{'container'};
  my $genomic_align_blocks;
  if ($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $genomic_align_blocks = $slice->get_all_constrained_elements();
  } elsif ($method_id) {
    my $mlss_adaptor = $db->get_adaptor("MethodLinkSpeciesSet");
    my $mlss = $mlss_adaptor->fetch_by_dbID($method_id);


## Get the GenomicAlignBlocks
    my $gab_adaptor = $db->get_adaptor("GenomicAlignBlock");
    $genomic_align_blocks = $gab_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice);
  } else {
    return [];
  }

    my $T = [];
    foreach (@$genomic_align_blocks) {
	my $all_gas = $_->get_all_GenomicAligns;
	my $fragments;
	foreach my $this_genomic_align (@$all_gas) {
          push(@{$fragments->{$this_genomic_align->dnafrag->genome_db->name}},
              [
		$this_genomic_align->dnafrag->name,
		$this_genomic_align->dnafrag_start,
		$this_genomic_align->dnafrag_end,
		$this_genomic_align->dnafrag_strand
              ]);
	}
	my ($rtype, $gpath, $rname, $rstart, $rend, $rstrand) = split(':',$_->reference_slice->name);
 
	push @$T, Bio::EnsEMBL::DnaDnaAlignFeature->new_fast ({
	   'seqname' => $_->reference_slice->name,
	   'start' => $_->reference_slice_start,
	   'end' => $_->reference_slice_end,
	   'strand' => $_->reference_slice_strand,
	   'hstart' => $rstart,
	   'hend' => $rend,
	   'hstrand' => $rstrand,
	   'hseqname' => $rname,
	   'score' => $_->score,
	   'fragments' => $fragments
       });
    }

    return $T;
}

sub wiggle_plot {

  ### Wiggle_plot
  ### Description: gets features for wiggle plot and passes to render_wiggle_plot
  ### Returns 1 if draws wiggles. Returns 0 if no wiggles drawn

  my ( $self, $db ) = @_;
  return 0 unless  $self->my_config('label') eq 'Conservation';
  return 0 unless $db;

  $self->render_space_glyph();
  my $display_size = $self->{'config'}->get('_settings','width') || 700;
  my $colour = "pink3";
  my $display_label = "GERP scores";

  my $slice = $self->{'container'};
  my $wiggle_adaptor   = $db->get_ConservationScoreAdaptor();
  if (!$wiggle_adaptor) {
    warn ("Cannot get get adaptors: $wiggle_adaptor");
    return 0;
  }
  my $method_link_species_set = $db->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID(50005);

# warn "WIGGLE $method_link_species_set , $slice, $display_size";
  my $features = $wiggle_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $slice, $display_size) || [];
#   warn ">>>> @$features";
  return 0 unless scalar @$features;

  @$features   = sort { $a->score <=> $b->score  } @$features;
  my ($min_score, $max_score) = ($features->[0]->score || 0, $features->[-1]->score|| 0);#($features->[0]->y_axis_min || 0, $features->[0]->y_axis_min || 0);
  $self->render_wiggle_plot($features, $colour, $min_score, $max_score, $display_label);

  return 1;
}
1;
