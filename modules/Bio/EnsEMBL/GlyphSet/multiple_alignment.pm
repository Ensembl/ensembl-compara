package Bio::EnsEMBL::GlyphSet::multiple_alignment;

=head1 NAME

EnsEMBL::Web::GlyphSet::multiple_alignment;

=head1 SYNOPSIS

The multiple_alignment object handles the display of multiple alignment regions in contigview.

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

Eugene Kulesha - ek3@sanger.ac.uk

=cut

use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Bump;
use Bio::EnsEMBL::DnaDnaAlignFeature;

@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
  my ($self) = @_;
  return if( defined $self->{'config'}->{'_no_label'} );
  $self->init_label_text( $self->my_config('label')||'---', 'compara_alignment' );
}

sub colour   { return $_[0]->{'feature_colour'}, $_[0]->{'label_colour'}, $_[0]->{'part_to_colour'}; }

sub _init {
  my ($self) = @_;
  my $type = $self->check();
  return unless defined $type;  ## No defined type arghhh!!

  my $strand = $self->strand;
  my $Config = $self->{'config'};
  my $strand_flag    = $Config->get($type, 'str');
  return if( $strand_flag eq 'r' && $strand != -1 || $strand_flag eq 'f' && $strand != 1 );

  $self->compact_init($type);
}


sub compact_init {
  my ($self,$type) = @_;
  my $WIDTH          = 1e5;
  my $container      = $self->{'container'};
  my $Config         = $self->{'config'};
  my $caption        = $Config->get($type,'title')||$Config->get($type,'label')||'Comparative alignment';
  my $strand         = $self->strand();
  my $strand_flag    = $Config->get($type, 'str');
  my %highlights;
  @highlights{$self->highlights()} = ();
  my $length         = $container->length;
  my $pix_per_bp     = $Config->transform()->{'scalex'};
  my $DRAW_CIGAR     = $pix_per_bp > 0.2 ;
  my $feature_colour = $Config->get($type, 'col');
  my $hi_colour      = $Config->get($type, 'hi');
  my $small_contig   = 0;
  my $dep            = $Config->get($type, 'dep');
  my $h              = $Config->get('_settings','opt_halfheight') ? 4 : 8;
  my $chr       = $self->{'container'}->seq_region_name;
  my $other_species  = $Config->get($type, 'species' );
  my $short_other    = $Config->species_defs->ENSEMBL_SHORTEST_ALIAS->{ $other_species };
  my $self_species   = $container->{_config_file_name_};
  my $short_self     = $Config->species_defs->ENSEMBL_SHORTEST_ALIAS->{ $self_species };
  my $jump_to_alignslice = $Config->get($type, 'jump_to_alignslice');

  my $METHOD         = $Config->get($type, 'method' );
  my $METHOD_ID         = $Config->get($type, 'method_id' );

  my $ALIGNSLICEVIEW_TEXT_LINK = 'Jump to AlignSliceView';

  my( $T,$C1,$C) = (0, 0, 0 ); ## Diagnostic counters....
  my $X = -1e8;

  my @T = sort { $a->[0] <=> $b->[0] }
    map { [$_->{start}, $_ ] }
    grep { !( ($strand_flag eq 'b' && $strand != $_->{strand}) ||
              ($_->{start} > $length) ||
              ($_->{end} < 1)
	      ) } @{$self->features( $other_species, $METHOD, $METHOD_ID )};

  foreach (@T) {
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

    my $id = 10; 
    my $max_contig = 250000;
    foreach my $fr (sort keys %{$f->{fragments}}) {
	$zmenu->{"$id:$fr"} = '';
	$id++;
	my $flength = abs($f->{fragments}->{$fr}->[2] - $f->{fragments}->{$fr}->[1]);
	(my $species = $fr) =~ s/\s/\_/g;
	my $flink = sprintf("/%s/%s?l=%s:%d-%d", $species, $flength > $max_contig ? 'cytoview' : 'contigview', @{$f->{fragments}->{$fr}});
	my $key = sprintf("%d:&nbsp;%s: %d-%d", $id++, @{$f->{fragments}->{$fr}});
	$zmenu->{"$key"} = $flink;
	$C++;
    }

    if($DRAW_CIGAR) {
      $TO_PUSH = new Sanger::Graphics::Glyph::Composite({
        'href'  => $href,
        'zmenu' => $zmenu,
        'x'     => $START-1,
        'width' => 0,
        'y'     => 0
      });
      $self->draw_cigar_feature($TO_PUSH, $f, $h, $feature_colour, 'black', $pix_per_bp, 1 );
      $TO_PUSH->bordercolour($feature_colour);
    } else {
      $TO_PUSH = new Sanger::Graphics::Glyph::Rect({
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
## No features show "empty track line" if option set....
  $self->errorTrack( "No ". $self->{'config'}->get($type,'label')." features in this region" ) unless( $C || $Config->get('_settings','opt_empty_tracks')==0 );
}

1;

use Time::HiRes qw(time);
sub features {
  my ($self, $species, $method, $method_id ) = @_;

  my $slice = $self->{'container'};
  my $genomic_align_blocks;
  if ($slice->isa("Bio::EnsEMBL::Compara::AlignSlice::Slice")) {
    $genomic_align_blocks = $slice->get_all_constrained_elements();
  } elsif ($method_id) {
    my $comparadb = $self->{'config'}->{_object}->database('compara');
    my $mlss_adaptor = $comparadb->get_adaptor("MethodLinkSpeciesSet");
    my $mlss = $mlss_adaptor->fetch_by_dbID($method_id);


## Get the GenomicAlignBlocks
    my $gab_adaptor = $comparadb->get_adaptor("GenomicAlignBlock");
    $genomic_align_blocks = $gab_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice);
  } else {
    return [];
  }

    my $T = [];
    foreach (@$genomic_align_blocks) {
	my $all_gas = $_->get_all_GenomicAligns;
	my $fragments;
	foreach my $this_genomic_align (@$all_gas) {
	    $fragments->{$this_genomic_align->dnafrag->genome_db->name} = [
		      $this_genomic_align->dnafrag->name,
		      $this_genomic_align->dnafrag_start,
		      $this_genomic_align->dnafrag_end,
		      $this_genomic_align->dnafrag_strand];
	}
	my ($rtype, $gpath, $rname, $rstart, $rend, $rstrand) = split(':',$_->reference_slice->name);
 
	push @$T, bless ({
	   'seqname' => $_->reference_slice->name,
	   'start' => $_->reference_slice_start,
	   'end' => $_->reference_slice_end,
	   'strand' => $_->reference_slice_strand,
	   'hstart' => $rstart,
	   'hend' => $rend,
	   'hstrand' => $rstrand,
	   'hseqname' => $rname,
	   'fragments' => $fragments
		   }, "Bio::EnsEMBL::DnaDnaAlignFeature");
    }

    return $T;
    

}

