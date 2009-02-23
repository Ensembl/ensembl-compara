#
# Ensembl module for Bio::EnsEMBL::Compara::AlignSlice
#
# Cared for by Javier Herrero <jherrero@ebi.ac.uk>
#
# Copyright EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself
#
# pod documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::AlignSlice - An AlignSlice can be used to map genes and features from one species onto another one

=head1 DESCRIPTION

INTRODUCTION

An AlignSlice is an object built with a reference Slice and the corresponding set of genomic alignments.
The genomic alignments are used to map features from one species onto another and viceversa.

STRUCTURE

Every Bio::EnsEMBL::Compara::AlignSlice contains a set of Bio::EnsEMBL::Compara::AlignSlice::Slice
objects, at least one by species involved in the alignments. For instance, if the reference Slice is a
human slice and the set of alignments corresponds to human-mouse BLASTZ_NET alignments, there will be at
least one Bio::EnsEMBL::Compara::AlignSlice::Slice for human and at least another one for mouse. The main
Bio::EnsEMBL::Compara::AlignSlice::Slice for the reference species will contain a single genomic sequence
whilst the other Bio::EnsEMBL::Compara::AlignSlice::Slice objects might be made of several pieces of
genomic sequences, depending on the set of alignments. Here is a graphical representation:

  ref.Slice    **************************************************************
  
  alignments    11111111111
                               2222222222222222
                                                     33333333333333333

  resulting Bio::EnsEMBL::Compara::AlignSlice:
  
  AS::Slice 1  **************************************************************
  AS::Slice 2  .11111111111....2222222222222222......33333333333333333.......

MODES

Two modes are currently available: condensed and expanded mode. The default mode is "condensed". In
condensed mode, no gaps are allowed in the reference Slice which means that information about deletions
in the reference species (i.e. insertions in the other species) are lost. On the other hand, the
first Bio::EnsEMBL::Compara::AlignSlice::Slice object corresponds to the original Bio::EnsEMBL::Slice.

In the expanded mode, the first Bio::EnsEMBL::Compara::AlignSlice::Slice is expanded in order to
accomodate the gaps corresponding to the deletions (insertions). Bear in mind that in expanded mode, the
length of the resulting AlignSlice will be most probably larger than the length of the reference
Bio::EnsEMBL::Slice.


OVERLAPPING ALIGNMENTS

No overlapping alignments are allowed by default. This means that if an alignment overlaps another one, the
second alignment is ignored. This is due to lack of information needed to reconciliate both alignment.
Here is a graphical example showing this problem:

  ALN 1:   Human (ref) CTGTGAAAA----CCCCATTAGG
           Mouse (1)     CTGAAAATTTTCCCC
  
  ALN 2:   Human (ref) CTGTGAAAA---CCCCATTAGG
           Mouse (1)         AAAGGGCCCCATTA

  Possible solution 1:
           Human (ref) CTGTGAAAA----CCCCATTAGG
           Mouse (1)     CTGAAAATTTTCCCC----
           Mouse (1)     ----AAA-GGGCCCCATTA

  Possible solution 2:
           Human (ref) CTGTGAAAA----CCCCATTAGG
           Mouse (1)     CTGAAAATTTTCCCC----
           Mouse (1)     ----AAAGGG-CCCCATTA

  Possible solution 3:
           Human (ref) CTGTGAAAA-------CCCCATTAGG
           Mouse (1)     CTGAAAATTTT---CCCC
           Mouse (1)         AAA----GGGCCCCATTA
  
There is no easy way to find which of these possible solution is the best without trying to realign the
three sequences together and this is far beyond the aim of this module. The best solution is to start with
multiple alignments instead of overlapping pairwise ones.

The third possibility is probably not the best alignment you can get although its implementation is
systematic (insert as many gaps as needed in order to accommodate the insertions and never ever overlap
them) and computationally cheap as no realignment is needed. You may ask this module to solve overlapping
alignments in this way using the "solve_overlapping" option.

RESULT

The AlignSlice results in a set of Bio::EnsEMBL::Compara::AlignSlice::Slice which are objects really
similar to the Bio::EnsEMBL::Slice. There are intended to be used just like the genuine
Bio::EnsEMBL::Slice but some methods do not work though. Some examples of non-ported methods are: expand()
and invert(). Some other methods work as expected (seq, subseq, get_all_Attributes,
get_all_VariationFeatures, get_all_RepeatFeatures...). All these Bio::EnsEMBL::Compara::AlignSlice::Slice
share the same fake coordinate system defined by the Bio::EnsEMBL::Compara::AlignSlice. This allows to
map features from one species onto the others.
  
=head1 SYNOPSIS
  
  use Bio::EnsEMBL::Compara::AlignSlice;
  
  ## You may create your own AlignSlice objects but if you are interested in
  ## getting AlignSlice built with data from an EnsEMBL Compara database you
  ## should consider using the Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor
  ## instead
  my $align_slice = new Bio::EnsEMBL::Compara::AlignSlice(
          -adaptor => $align_slice_adaptor,
          -reference_Slice => $reference_Slice,
          -method_link_species_set => $all_genomic_align_blocks,
          -genomicAlignBlocks => $all_genomic_align_blocks,
          -expanded => 1
          -solve_overlapping => 1
      );

  my $all_slices = $aling_slice->get_all_Slices();
  foreach my $this_slice (@$all_slices) {
    ## See also Bio::EnsEMBL::Compara::AlignSlice::Slice
    my $species_name = $this_slice->genome_db->name()
    my $all_mapped_genes = $this_slice->get_all_Genes();
  }

  my $simple_align = $align_slice->get_projected_SimpleAlign();

SET VALUES
  $align_slice->adaptor($align_slice_adaptor);
  $align_slice->reference_Slice($reference_slice);
  $align_slice->add_GenomicAlignBlock($genomic_align_block_1);
  $align_slice->add_GenomicAlignBlock($genomic_align_block_2);
  $align_slice->add_GenomicAlignBlock($genomic_align_block_3);

GET VALUES
  my $align_slice_adaptor = $align_slice->adaptor();
  my $reference_slice = $align_slice->reference_Slice();
  my $all_genomic_align_blocks = $align_slice->get_all_GenomicAlignBlock();
  my $mapped_genes = $align_slice->get_all_Genes_by_genome_db_id(3);
  my $simple_align = $align_slice->get_projected_SimpleAlign();

=head1 OBJECT ATTRIBUTES

=over

=item adaptor

Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor object to access DB

=item reference_slice

Bio::EnsEMBL::Slice object used to create this Bio::EnsEBML::Compara::AlignSlice object

=item all_genomic_align_blocks

a listref of Bio::EnsEMBL::Compara::GenomicAlignBlock objects found using the reference_Slice

=back

=head1 AUTHORS

Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

Copyright (c) 2004. EnsEMBL Team

You may distribute this module under the same terms as perl itself

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::AlignSlice;

use strict;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning info verbose);
use Bio::EnsEMBL::Compara::AlignSlice::Exon;
use Bio::EnsEMBL::Compara::AlignSlice::Slice;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::SimpleAlign;


## Creates a new coordinate system for creating empty Slices.
my $aligngap_coord_system = new Bio::EnsEMBL::CoordSystem(
        -NAME => 'alignment',
        -VERSION => "none",
        -TOP_LEVEL => 0,
        -SEQUENCE_LEVEL => 1,
        -RANK => 1,
    );

=head2 new (CONSTRUCTOR)

  Arg[1]     : a reference to a hash where keys can be:
                 -adaptor
                 -reference_slice
                 -genomic_align_blocks
                 -method_link_species_set
                 -expanded
                 -solve_overlapping
                 -preserve_blocks
    -adaptor:  the Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor
    -reference_slice:
               Bio::EnsEMBL::Slice, the guide slice for this align_slice
    -genomic_align_blocks:
               listref of Bio::EnsEMBL::Compara::GenomicAlignBlock
               objects containing to the alignments to be used for this
               align_slice
    -method_link_species_set;
               Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object for
               all the previous genomic_align_blocks. At the moment all
               the blocks should correspond to the same MethodLinkSpeciesSet
    -expanded: boolean flag. If set to true, the AlignSlice will insert all
               the gaps requiered by the alignments in the reference_slice
               (see MODES elsewhere in this document)
    -solve_overlapping:
               boolean flag. If set to true, the AlignSlice will allow
               overlapping alginments and solve indeterminations according
               to the method described in OVERLAPPING ALIGNMENTS elsewhere
               in this document
    -preserve_blocks:
               boolean flag. By default the AlignSlice trim the alignments
               in order to fit the reference_slice. This flags tell the
               AlignSlice to use the alignment block as they are (usually
               this is only used by the AlignSliceAdaptor, use with care)
  Example    : my $align_slice =
                   new Bio::EnsEMBL::Compara::AlignSlice(
                       -adaptor => $align_slice_adaptor,
                       -reference_slice => $reference_slice,
                       -method_link_species_set => $method_link_species_set,
                       -genomic_align_blocks => [$gab1, $gab2],
                       -expanded => 1
                   );
  Description: Creates a new Bio::EnsEMBL::Compara::AlignSlice object
  Returntype : Bio::EnsEMBL::Compara::AlignSlice object
  Exceptions : none
  Caller     : general

=cut

sub new {
  my ($class, @args) = @_;

  my $self = {};
  bless $self,$class;

  my ($adaptor, $reference_slice, $genomic_align_blocks, $genomic_align_trees,
      $method_link_species_set, $expanded, $solve_overlapping, $preserve_blocks,
      $species_order) =
      rearrange([qw(
          ADAPTOR REFERENCE_SLICE GENOMIC_ALIGN_BLOCKS GENOMIC_ALIGN_TREES
          METHOD_LINK_SPECIES_SET EXPANDED SOLVE_OVERLAPPING PRESERVE_BLOCKS
          SPECIES_ORDER
      )], @args);

  $self->adaptor($adaptor) if (defined ($adaptor));
  $self->reference_Slice($reference_slice) if (defined ($reference_slice));
  if (defined($genomic_align_blocks)) {  
    foreach my $this_genomic_align_block (@$genomic_align_blocks) {
      $self->add_GenomicAlignBlock($this_genomic_align_block);
    }
  }
  $self->{_method_link_species_set} = $method_link_species_set if (defined($method_link_species_set));

  $self->{expanded} = 0;
  if ($expanded) {
    $self->{expanded} = 1;
  }

  $self->{solve_overlapping} = 0;
  if ($solve_overlapping) {
    $self->{solve_overlapping} = $solve_overlapping;
  }

  if ($genomic_align_trees) {
    $self->_create_underlying_Slices($genomic_align_trees, $self->{expanded},
        $self->{solve_overlapping}, $preserve_blocks, $species_order);

    #Awful hack to store the _alignslice_from and _alignslice_to on the 
    #GenomicAlignBlock for use in get_all_ConservationScores which uses 
    #GenomicAlignBlock and not GenomicAlignTree
    foreach my $tree (@$genomic_align_trees) {
        foreach my $block (@$genomic_align_blocks) {
            my $gab_id = $tree->get_all_leaves->[0]->genomic_align_group->get_all_GenomicAligns->[0]->genomic_align_block_id;
            if ($gab_id == $block->dbID) {
                $block->{_alignslice_from} = $tree->{_alignslice_from};
                $block->{_alignslice_to} = $tree->{_alignslice_to};
            }
        }
    }

  } else {
    $self->_create_underlying_Slices($genomic_align_blocks, $self->{expanded},
        $self->{solve_overlapping}, $preserve_blocks, $species_order);
  }

  return $self;
}


=head2 sub_AlignSlice

  Arg 1      : int $start
  Arg 2      : int $end
  Example    : my $sub_align_slice = $align_slice->sub_AlignSlice(10, 50);
  Description: Creates a new Bio::EnsEMBL::Compara::AlignSlice object
               corresponding to a sub region of this one
  Returntype : Bio::EnsEMBL::Compara::AlignSlice object
  Exceptions : return undef if no internal slices can be created (see
               Bio::EnsEMBL::Compara::AlignSlice::Slice->sub_Slice)
  Caller     : $align_slice
  Status     : Testing

=cut

sub sub_AlignSlice {
  my ($self, $start, $end) = @_;
  my $sub_align_slice = {};

  throw("Must provide START argument") if (!defined($start));
  throw("Must provide END argument") if (!defined($end));

  bless $sub_align_slice, ref($self);

  $sub_align_slice->adaptor($self->adaptor);
  $sub_align_slice->reference_Slice($self->reference_Slice);
  foreach my $this_genomic_align_block (@{$self->get_all_GenomicAlignBlocks()}) {
    $sub_align_slice->add_GenomicAlignBlock($this_genomic_align_block);
  }
  $sub_align_slice->{_method_link_species_set} = $self->{_method_link_species_set};

  $sub_align_slice->{expanded} = $self->{expanded};

  $sub_align_slice->{solve_overlapping} = $self->{solve_overlapping};

  foreach my $this_slice (@{$self->get_all_Slices}) {
    my $new_slice = $this_slice->sub_Slice($start, $end);
    push(@{$sub_align_slice->{_slices}}, $new_slice) if ($new_slice);
  }
  return undef if (!$sub_align_slice->{_slices});

  return $sub_align_slice;
}


=head2 adaptor

  Arg[1]     : (optional) Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor $align_slice_adaptor
  Example    : my $align_slice_adaptor = $align_slice->adaptor
  Example    : $align_slice->adaptor($align_slice_adaptor)
  Description: getter/setter for the adaptor attribute
  Returntype : Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor object
  Exceptions : throw if arg is not a Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor
  Caller     : $object->methodname

=cut

sub adaptor {
  my ($self, $adaptor) = @_;

  if (defined($adaptor)) {
    throw "[$adaptor] must be a Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor object"
        unless ($adaptor and $adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor"));
    $self->{'adaptor'} = $adaptor;
  }

  return $self->{'adaptor'};
}


=head2 get_all_Slices (experimental)

  Arg[1]     : [optional] string $species_name1
  Arg[2]     : [optional] string $species_name2
  Arg[...]   : [optional] string $species_nameN
  Example    : my $slices = $align_slice->get_all_Slices
  Description: getter for all the Slices in this AlignSlice. If a list
               of species is specified, returns only the slices for
               these species. The slices are returned in a "smart"
               order, i.e. the slice corresponding to the reference
               species is returned first and then the remaining slices
               depending on their phylogenetic distance to the first
               one.
               NB: You can use underscores instead of whitespaces for
               the name of the species, i.e. Homo_sapiens will be
               understood as "Homo sapiens".
  Returntype : listref of Bio::EnsEMBL::Compara::AlignSlice::Slice
               objects.
  Exceptions : 
  Caller     : $object->methodname

=cut

sub get_all_Slices {
  my ($self, @species_names) = @_;
  my $slices = [];

  if (@species_names) {
    foreach my $slice (@{$self->{_slices}}) {
      foreach my $this_species_name (@species_names) {
        $this_species_name =~ s/_/ /g; ## supports names containing underscores instead of whitespaces
        push(@$slices, $slice) if ($this_species_name eq $slice->genome_db->name);
      }
    }
  } else {
    $slices = $self->{_slices};
  }

  return $slices;
}


=head2 reference_Slice

  Arg[1]     : (optional) Bio::EnsEMBL::Slice $slice
  Example    : my $reference_slice = $align_slice->reference_slice
  Example    : $align_slice->reference_Slice($reference_slice)
  Description: getter/setter for the attribute reference_slice
  Returntype : Bio::EnsEMBL::Slice object
  Exceptions : throw if arg is not a Bio::EnsEMBL::Slice object
  Caller     : $object->methodname

=cut

sub reference_Slice {
  my ($self, $reference_slice) = @_;

  if (defined($reference_slice)) {
    throw "[$reference_slice] must be a Bio::EnsEMBL::Slice object"
        unless ($reference_slice and $reference_slice->isa("Bio::EnsEMBL::Slice"));
    $self->{'reference_slice'} = $reference_slice;
  }

  return $self->{'reference_slice'};
}


=head2 add_GenomicAlignBlock

  Arg[1]     : Bio::EnsEMBL::Compara::GenomicAlignBlock $genomicAlignBlock
  Example    : $align_slice->add_GenomicAlignBlock($genomicAlignBlock)
  Description: add a Bio::EnsEMBL::Compara::GenomicAlignBlock object to the array
               stored in the attribute all_genomic_align_blocks
  Returntype : none
  Exceptions : throw if arg is not a Bio::EnsEMBL::Compara::GenomicAlignBlock
  Caller     : $object->methodname

=cut

sub add_GenomicAlignBlock {
  my ($self, $genomic_align_block) = @_;

  if (!defined($genomic_align_block)) {
    throw "Too few arguments for Bio::EnsEMBL::Compara::AlignSlice->add_GenomicAlignBlock()";
  }
  if (!$genomic_align_block or !$genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
    throw "[$genomic_align_block] must be a Bio::EnsEMBL::Compara::GenomicAlignBlock object";
  }

  push(@{$self->{'all_genomic_align_blocks'}}, $genomic_align_block);
}


=head2 get_all_GenomicAlignBlocks

  Arg[1]     : none
  Example    : my $all_genomic_align_blocks = $align_slice->get_all_GenomicAlignBlocks
  Description: getter for the attribute all_genomic_align_blocks
  Returntype : listref of Bio::EnsEMBL::Compara::GenomicAlignBlock objects
  Exceptions : none
  Caller     : $object->methodname

=cut

sub get_all_GenomicAlignBlocks {
  my ($self) = @_;

  return ($self->{'all_genomic_align_blocks'} || []);
}


=head2 get_MethodLinkSpeciesSet

  Arg[1]     : none
  Example    : my $method_link_species_set = $align_slice->get_MethodLinkSpeciesSet
  Description: getter for the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
               used to create this object
  Returntype : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet
  Exceptions : none
  Caller     : $object->methodname

=cut

sub get_MethodLinkSpeciesSet {
  my ($self) = @_;

  return $self->{'_method_link_species_set'};
}


=head2 get_SimpleAlign

  Arg[1]      : none
  Example     : use Bio::AlignIO;
                my $out = Bio::AlignIO->newFh(-fh=>\*STDOUT, -format=> "clustalw");
                print $out $align_slice->get_SimpleAlign();
  Description : This method creates a Bio::SimpleAlign object using the
                Bio::EnsEMBL::Compara::AlignSlice::Slices underlying this
                Bio::EnsEMBL::Compara::AlignSlice object. The SimpleAlign
                describes the alignment where the first sequence
                corresponds to the reference Slice and the remaining
                correspond to the other species.
  Returntype  : Bio::SimpleAlign object
  Exceptions  : 
  Caller      : $object->methodname

=cut

sub get_SimpleAlign {
  my ($self, @species) = @_;
  my $simple_align;

  ## Create a single Bio::SimpleAlign for the projection  
  $simple_align = Bio::SimpleAlign->new();
  $simple_align->id("ProjectedMultiAlign");

  my $genome_db_name_counter;
  foreach my $slice (@{$self->get_all_Slices(@species)}) {
    my $seq = Bio::LocatableSeq->new(
            -SEQ    => $slice->seq,
            -START  => $slice->start,
            -END    => $slice->end,
            -ID     => $slice->genome_db->name.($genome_db_name_counter->{$slice->genome_db->name} or ""),
            -STRAND => $slice->strand
        );
    ## This allows to have several sequences for the same species. Bio::SimpleAlign complains
    ## about having the same ID, START and END for two sequences...
    if (!defined($genome_db_name_counter->{$slice->genome_db->name})) {
      $genome_db_name_counter->{$slice->genome_db->name} = 2;
    } else {
      $genome_db_name_counter->{$slice->genome_db->name}++;
    }

    $simple_align->add_seq($seq);
  }

  return $simple_align;
}


=head2 get_all_ConservationScores

  Arg  1     : (opt) integer $display_size (default 700)
  Arg  2     : (opt) string $display_type (one of "AVERAGE" or "MAX") (default "MAX")
  Arg  3     : (opt) integer $window_size
  Example    : my $conservation_scores =
                    $align_slice->get_all_ConservationScores(1000, "MAX", 10);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::ConservationScore objects for the
               Bio::EnsEMBL::Compara::GenomicAlignBlock objects underlying
               this Bio::EnsEMBL::Compara::AlignSlice object. This method
               calls the Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor->
               fetch_all_by_GenomicAlignBlock() method. It sets up the align_start,
               align_end and slice_length and map the resulting objects onto
               the AlignSlice. $diaplay_slize, $display_type and $window_size
               are passed as it to the fetch_all_by_GenomicAlignBlock() method.
               Please refer to the documentation in
               Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor
               for more details.
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::ConservationScore 
               objects.
  Caller     : object::methodname
  Status     : At risk

=cut

sub get_all_ConservationScores {
  my ($self, $display_size, $display_type, $window_size) = @_;
  my $all_conservation_scores = [];
  my $y_axis_min;
  my $y_axis_max;

  my $conservation_score_adaptor = $self->adaptor->db->get_ConservationScoreAdaptor();
  foreach my $this_genomic_align_block (@{$self->get_all_GenomicAlignBlocks()}) {
    my $all_these_conservation_scores = $conservation_score_adaptor->fetch_all_by_GenomicAlignBlock(
        $this_genomic_align_block, $this_genomic_align_block->{_alignslice_from},
        $this_genomic_align_block->{_alignslice_to}, $self->get_all_Slices()->[0]->length, 
        $display_size, $display_type, $window_size);
#     ## Debug
#     print "PARAMETERS FOR fetch_all_by_GenomicAlignBlock(): ", join(", ", 
#         $this_genomic_align_block->dbID, $this_genomic_align_block->{_alignslice_from},
#         $this_genomic_align_block->{_alignslice_to}, $self->get_all_Slices()->[0]->length), "\n";

    #initialise y axis min and max
    if (!defined $y_axis_max) {
	$y_axis_max = $all_these_conservation_scores->[0]->y_axis_max;
	$y_axis_min = $all_these_conservation_scores->[0]->y_axis_min;
    }
    #find overall min and max 
    if ($y_axis_min > $all_these_conservation_scores->[0]->y_axis_min) {
	$y_axis_min = $all_these_conservation_scores->[0]->y_axis_min;
    }
    if ($y_axis_max < $all_these_conservation_scores->[0]->y_axis_max) {
	$y_axis_max = $all_these_conservation_scores->[0]->y_axis_max;
    }

    foreach my $this_conservation_score (@$all_these_conservation_scores) {
      $this_conservation_score->position($this_conservation_score->position +
          $this_genomic_align_block->{_alignslice_from} - 1 +
          $this_genomic_align_block->{_alignslice_start});
      push (@$all_conservation_scores, $this_conservation_score);
    }
  }

  #set overall min and max
  $all_conservation_scores->[0]->y_axis_min($y_axis_min);
  $all_conservation_scores->[0]->y_axis_max($y_axis_max);

#   ## Debug
#   foreach my $this_conservation_score (@$all_conservation_scores) {
#     print "CONS_SCORE: ", join(" -- ",
#         "gab_id=".$this_conservation_score->genomic_align_block_id,
#         "pos=".$this_conservation_score->position,
#         "win_size=".$this_conservation_score->window_size,
#         "expect=".$this_conservation_score->expected_score,
#         "observ=".$this_conservation_score->observed_score,
#         "diff=".$this_conservation_score->diff_score,
#         ), "\n";
#   }

  return $all_conservation_scores;
}


=head2 get_all_constrained_elements

  Arg  1     : (opt) string $method_link_type (default = GERP_CONSTRAINED_ELEMENT)
  Arg  2     : (opt) listref Bio::EnsEMBL::Compara::GenomeDB $species_set
               (default, the set of species from the MethodLinkSpeciesSet used
               to build this AlignSlice)
  Example    : my $constrained_elements =
                    $align_slice->get_all_constrained_elements();
  Description: Retrieve the corresponding constrained elements for these alignments.
               Objects will be located on this AlignSlice, i.e. the
               reference_slice, reference_slice_start, reference_slice_end
               and reference_slice_strand will refer to this AlignSlice
               object
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignBlock
               objects.
  Caller     : object::methodname
  Status     : At risk

=cut

sub get_all_constrained_elements {
  my ($self, $method_link_type, $species_set) = @_;
  my $all_constrained_elements = [];

  $method_link_type ||= "GERP_CONSTRAINED_ELEMENT";
  my $key_cache = "_constrained_elements_".$method_link_type;
  if ($species_set) {
    $key_cache .= "::" . join("-", sort map {s/\W/_/g} map {$_->name} @$species_set);
  } else {
    $species_set = $self->{_method_link_species_set}->species_set;
  }

  if (!defined($self->{$key_cache})) {
    my $method_link_species_set_adaptor = $self->adaptor->db->get_MethodLinkSpeciesSetAdaptor();
    my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs(
        $method_link_type, $self->{_method_link_species_set}->species_set);

    if ($method_link_species_set) {
      my $genomic_align_block_adaptor = $self->adaptor->db->get_GenomicAlignBlockAdaptor();
      $all_constrained_elements = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
          $method_link_species_set, $self->reference_Slice);
      my $big_mapper = $self->{_reference_Mapper};
      foreach my $this_genomic_align_block (@{$all_constrained_elements}) {
        my $reference_slice_start;
        my $reference_slice_end;
        my $reference_slice_strand;

        my @alignment_coords = $big_mapper->map_coordinates(
            "sequence", # $self->genomic_align->dbID,
            $this_genomic_align_block->reference_slice_start + $this_genomic_align_block->reference_slice->start - 1,
            $this_genomic_align_block->reference_slice_end + $this_genomic_align_block->reference_slice->start - 1,
            $this_genomic_align_block->reference_slice_strand,
            "sequence" # $from_mapper->from
        );
        foreach my $alignment_coord (@alignment_coords) {
          next if (!$alignment_coord->isa("Bio::EnsEMBL::Mapper::Coordinate"));
          if (!defined($reference_slice_strand)) {
            $reference_slice_start = $alignment_coord->start;
            $reference_slice_end = $alignment_coord->end;
            $reference_slice_strand = $alignment_coord->strand;
          } else {
            if ($alignment_coord->start < $reference_slice_start) {
              $reference_slice_start = $alignment_coord->start;
            }
            if ($alignment_coord->end > $reference_slice_end) {
              $reference_slice_end = $alignment_coord->end;
            }
          }
        }
        $this_genomic_align_block->reference_slice($self);
        $this_genomic_align_block->reference_slice_start($reference_slice_start);
        $this_genomic_align_block->reference_slice_end($reference_slice_end);
        $this_genomic_align_block->reference_slice_strand($reference_slice_strand);
      }
    }
    $self->{$key_cache} = $all_constrained_elements;
  }

  return $self->{$key_cache};
}


=head2 _create_underlying_Slices (experimental)

  Arg[1]     : listref of Bio::EnsEMBL::Compara::GenomicAlignBlocks
               $genomic_align_blocks
  Arg[2]     : [optional] boolean $expanded (default = FALSE)
  Arg[3]     : [optional] boolean $solve_overlapping (default = FALSE)
  Arg[4]     : [optional] boolean $preserve_blocks (default = FALSE)
  Example    : 
  Description: Creates a set of Bio::EnsEMBL::Compara::AlignSlice::Slices
               and attach it to this object. 
  Returntype : 
  Exceptions : warns about overlapping GenomicAlignBlocks
  Caller     : 

=cut

sub _create_underlying_Slices {
  my ($self, $genomic_align_blocks, $expanded, $solve_overlapping, $preserve_blocks, $species_order) = @_;

  my $strand = $self->reference_Slice->strand;
  
  my $align_slice_length = 0;
  my $last_ref_pos;
  if ($strand == 1) {
    $last_ref_pos = $self->reference_Slice->start;
  } else {
    $last_ref_pos = $self->reference_Slice->end;
  }
  my $ref_genome_db = $self->adaptor->db->get_GenomeDBAdaptor->fetch_by_Slice($self->reference_Slice);
  my $big_mapper = Bio::EnsEMBL::Mapper->new("sequence", "alignment");

  my $sorted_genomic_align_blocks;
  if ($solve_overlapping eq "restrict") {
    $sorted_genomic_align_blocks = _sort_and_restrict_GenomicAlignBlocks($genomic_align_blocks);
  } elsif ($solve_overlapping) {
    $sorted_genomic_align_blocks = _sort_and_compile_GenomicAlignBlocks($genomic_align_blocks);
  } else {
    $sorted_genomic_align_blocks = _sort_GenomicAlignBlocks($genomic_align_blocks);
  }
  @$sorted_genomic_align_blocks = reverse(@$sorted_genomic_align_blocks) if ($strand == -1);
  foreach my $this_genomic_align_block (@$sorted_genomic_align_blocks) {
    my $original_genomic_align_block = $this_genomic_align_block;
    my ($from, $to);

    if ($preserve_blocks) {
      ## Don't restrict the block. Set from and to to 1 and length respectively
      $from = 1;
      $to = $this_genomic_align_block->length;
    } else {
	#need to check that the block is still overlapping the slice - it may
	#have already been restricted by the options above.
        if ($this_genomic_align_block->reference_genomic_align->dnafrag_start > $self->reference_Slice->end || $this_genomic_align_block->reference_genomic_align->dnafrag_end < $self->reference_Slice->start) {
            next;
        }
      ($this_genomic_align_block, $from, $to) = $this_genomic_align_block->restrict_between_reference_positions(
          $self->reference_Slice->start, $self->reference_Slice->end);
    }

    $original_genomic_align_block->{_alignslice_from} = $from;
    $original_genomic_align_block->{_alignslice_to} = $to;

    my $reference_genomic_align = $this_genomic_align_block->reference_genomic_align;

    #If I haven't needed to restrict, I don't gain this link so add it here
    if (!defined $reference_genomic_align->genomic_align_block->reference_genomic_align) {
	$reference_genomic_align->genomic_align_block($this_genomic_align_block);
    }

    my ($this_pos, $this_gap_between_genomic_align_blocks);
    if ($strand == 1) {
      $this_pos = $reference_genomic_align->dnafrag_start;
      $this_gap_between_genomic_align_blocks = $this_pos - $last_ref_pos;
    } else {
      $this_pos = $reference_genomic_align->dnafrag_end;
      $this_gap_between_genomic_align_blocks = $last_ref_pos - $this_pos;
    }
    if ($this_gap_between_genomic_align_blocks > 0) {
      ## Add mapper info for inter-genomic_align_block space
      if ($strand == 1) {
        $big_mapper->add_map_coordinates(
                'sequence',
                $last_ref_pos,
                $this_pos - 1,
                $strand,
                'alignment',
                $align_slice_length + 1,
                $align_slice_length + $this_gap_between_genomic_align_blocks,
            );
      } else {
        $big_mapper->add_map_coordinates(
                'sequence',
                $this_pos + 1,
                $last_ref_pos,
                $strand,
                'alignment',
                $align_slice_length + 1,
                $align_slice_length + $this_gap_between_genomic_align_blocks,
            );
      }
      $align_slice_length += $this_gap_between_genomic_align_blocks;
    }
    $reference_genomic_align->genomic_align_block->reference_slice_start($align_slice_length + 1);
    $original_genomic_align_block->{_alignslice_start} = $align_slice_length;
    if ($expanded) {
      $align_slice_length += CORE::length($reference_genomic_align->aligned_sequence("+FAKE_SEQ"));
      $big_mapper->add_Mapper($reference_genomic_align->get_Mapper(0));
    } else {
      $align_slice_length += $reference_genomic_align->dnafrag_end - $reference_genomic_align->dnafrag_start + 1;
      $big_mapper->add_Mapper($reference_genomic_align->get_Mapper(0,1));
    }
    $reference_genomic_align->genomic_align_block->reference_slice_end($align_slice_length);
    $reference_genomic_align->genomic_align_block->reference_slice($self);

    if ($strand == 1) {
      $last_ref_pos = $reference_genomic_align->dnafrag_end + 1;
    } else {
      $last_ref_pos = $reference_genomic_align->dnafrag_start - 1;
    }
  }
  my ($this_pos, $this_gap_between_genomic_align_blocks);
  if ($strand == 1) {
    $this_pos = $self->reference_Slice->end;
    $this_gap_between_genomic_align_blocks = $this_pos - ($last_ref_pos - 1);
  } else {
    $this_pos = $self->reference_Slice->start;
    $this_gap_between_genomic_align_blocks = $last_ref_pos + 1 - $this_pos;
  }
  ## $last_ref_pos is the next nucleotide position after the last mapped one.
  if ($this_gap_between_genomic_align_blocks > 0) {
    if ($strand == 1) {
      $big_mapper->add_map_coordinates(
              'sequence',
              $last_ref_pos,
              $this_pos,
              $strand,
              'alignment',
              $align_slice_length + 1,
              $align_slice_length + $this_gap_between_genomic_align_blocks,
          );
    } else {
      $big_mapper->add_map_coordinates(
              'sequence',
              $this_pos,
              $last_ref_pos,
              $strand,
              'alignment',
              $align_slice_length + 1,
              $align_slice_length + $this_gap_between_genomic_align_blocks,
          );
    }
    $align_slice_length += $this_gap_between_genomic_align_blocks;
  }

  if ($species_order) {
    foreach my $species_def (@$species_order) {
      my $genome_db_name = $species_def->{genome_db}->name;
# print STDERR "SPECIES:: ", $genome_db_name, "\n";
      my $new_slice = new Bio::EnsEMBL::Compara::AlignSlice::Slice(
              -length => $align_slice_length,
              -requesting_slice => $self->reference_Slice,
              -align_slice => $self,
              -method_link_species_set => $self->{_method_link_species_set},
              -genome_db => $species_def->{genome_db},
              -expanded => $expanded,
          );
      $new_slice->{genomic_align_ids} = $species_def->{genomic_align_ids};
      push(@{$self->{slices}->{lc($genome_db_name)}}, $new_slice);
      push(@{$self->{_slices}}, $new_slice);
    }
  } else {
# print STDERR "SPECIES:: ", $ref_genome_db->name, "\n";
    $self->{slices}->{lc($ref_genome_db->name)} = [new Bio::EnsEMBL::Compara::AlignSlice::Slice(
            -length => $align_slice_length,
            -requesting_slice => $self->reference_Slice,
            -align_slice => $self,
            -method_link_species_set => $self->{_method_link_species_set},
            -genome_db => $ref_genome_db,
            -expanded => $expanded,
        )];
    $self->{_slices} = [$self->{slices}->{lc($ref_genome_db->name)}->[0]];
  }

  $self->{slices}->{lc($ref_genome_db->name)}->[0]->add_Slice_Mapper_pair(
          $self->reference_Slice,
          $big_mapper,
          1,
          $align_slice_length,
          $self->reference_Slice->strand
      );
  $self->{_reference_Mapper} = $big_mapper;

  foreach my $this_genomic_align_block (@$sorted_genomic_align_blocks) {
    if (UNIVERSAL::isa($this_genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
      ## For trees, loop through all nodes (internal and leaves) to add the GenomicAligns
      foreach my $this_genomic_align_node (@{$this_genomic_align_block->get_all_nodes}) {
        # but we have to skip the reference node as this has already been added to the guide Slice
        next if ($this_genomic_align_node eq $this_genomic_align_block->reference_genomic_align_node);

        # For composite segments (2X genomes), the node will link to several GenomicAligns.
        # Add each of them to one of the AS:Slice objects
        foreach my $this_genomic_align (@{$this_genomic_align_node->get_all_GenomicAligns}) {
          # Link to genomic_align_block may have been lost during tree minimization
          $this_genomic_align->genomic_align_block_id(0);
          $this_genomic_align->genomic_align_block($this_genomic_align_block);
          $self->_add_GenomicAlign_to_a_Slice($this_genomic_align, $this_genomic_align_block,
              $species_order, $align_slice_length);
        }
      }
    } else {
      ## For plain alignments, just use all non-reference GenomicAlign objects
      foreach my $this_genomic_align
              (@{$this_genomic_align_block->get_all_non_reference_genomic_aligns}) {
        $self->_add_GenomicAlign_to_a_Slice($this_genomic_align, $this_genomic_align_block,
            $species_order, $align_slice_length);
      }
    }
  }

  return $self;
}

=head2 _add_GenomicAlign_to_a_Slice

=cut

sub _add_GenomicAlign_to_a_Slice {
  my ($self, $this_genomic_align, $this_genomic_align_block, $species_order, $align_slice_length) = @_;

  my $expanded = $self->{expanded};
  my $species = $this_genomic_align->dnafrag->genome_db->name;

  if (!defined($self->{slices}->{lc($species)})) {
    $self->{slices}->{lc($species)} = [new Bio::EnsEMBL::Compara::AlignSlice::Slice(
            -length => $align_slice_length,
            -requesting_slice => $self->reference_Slice,
            -align_slice => $self,
            -method_link_species_set => $self->{_method_link_species_set},
            -genome_db => $this_genomic_align->dnafrag->genome_db,
            -expanded => $expanded,
        )];
    push(@{$self->{_slices}}, $self->{slices}->{lc($species)}->[0]);
  }

  my $this_block_start = $this_genomic_align_block->reference_slice_start;
  my $this_block_end = $this_genomic_align_block->reference_slice_end;
  my $this_core_slice = $this_genomic_align->get_Slice();
  if (!$this_core_slice) {
    $this_core_slice = new Bio::EnsEMBL::Slice(
          -coord_system => $aligngap_coord_system,
          -seq_region_name => "GAP",
          -start => $this_block_start,
          -end => $this_block_end,
          -strand => 0
        );
    $this_core_slice->{seq} = "." x ($this_block_end - $this_block_start + 1);
  }
  return if (!$this_core_slice); ## The restriction of the GenomicAlignBlock may return a void GenomicAlign

  ## This creates a link between the slice and the tree node. This is required to display
  ## the tree on the web interface.
  if ($this_genomic_align->genome_db->name eq "Ancestral sequences") {
    foreach my $genomic_align_node (@{$this_genomic_align_block->get_all_sorted_genomic_align_nodes}) {
      my $genomic_align_group = $genomic_align_node->genomic_align_group;
      next if (!$genomic_align_group);

      foreach my $genomic_align (@{$genomic_align_group->get_all_GenomicAligns}) {
        if ($this_genomic_align == $genomic_align) {
          my $simple_tree = $genomic_align_node->newick_simple_format();
          $simple_tree =~ s/\_[^\_]+\_\d+\_\d+\[[\+\-]\]//g;
          $simple_tree =~ s/\:[\d\.]+//g;
          $this_core_slice->{_tree} = $simple_tree;
          last;
        }
      }
    }
  }

  my $this_mapper = $this_genomic_align->get_Mapper(0, !$expanded);
  # Fix block start and block end for composite segments (2X genomes)
  if ($this_genomic_align->cigar_line =~ /^(\d*)X/ or $this_genomic_align->cigar_line =~ /(\d*)X$/) {
    $this_block_start = undef;
    $this_block_end = undef;
    my @blocks = $this_mapper->map_coordinates("sequence", $this_genomic_align->dnafrag_start,
          $this_genomic_align->dnafrag_end, $this_genomic_align->dnafrag_strand, "sequence");
    foreach my $this_block (@blocks) {
      next if ($this_block->isa("Bio::EnsEMBL::Mapper::Gap"));
      $this_block_start = $this_block->start if (!defined($this_block_start) or $this_block->start < $this_block_start);
      $this_block_end = $this_block->end if (!defined($this_block_end) or $this_block->end > $this_block_end);
    }
  }

  # Choose the appropriate AS::Slice for adding this bit of the alignment
  my $this_underlying_slice = $self->_choose_underlying_Slice($this_genomic_align, $this_block_start,
      $this_block_end, $align_slice_length, $species_order);

  # Add a Slice, Mapper, and start-end-strand coordinates to an underlying AS::Slice
  $this_underlying_slice->add_Slice_Mapper_pair(
          $this_core_slice,
          $this_mapper,
          $this_block_start,
          $this_block_end,
          $this_genomic_align->dnafrag_strand
      );
  return;
}


sub _choose_underlying_Slice {
  my ($self, $this_genomic_align, $this_block_start, $this_block_end, $align_slice_length, $species_order) = @_;
  my $underlying_slice = undef;

  my $expanded = $self->{expanded};
  my $species = $this_genomic_align->dnafrag->genome_db->name;

  if (defined($this_genomic_align->{_temporary_AS_underlying_Slice})) {
    my $preset_underlying_slice = $this_genomic_align->{_temporary_AS_underlying_Slice};
    delete($this_genomic_align->{_temporary_AS_underlying_Slice});
    return $preset_underlying_slice;
  }

  if (!defined($self->{slices}->{lc($species)})) {
    ## No slice for this species yet. Create, store and return it
    $underlying_slice = new Bio::EnsEMBL::Compara::AlignSlice::Slice(
            -length => $align_slice_length,
            -requesting_slice => $self->reference_Slice,
            -align_slice => $self,
            -method_link_species_set => $self->{_method_link_species_set},
            -genome_db => $this_genomic_align->dnafrag->genome_db,
            -expanded => $expanded,
        );
    push(@{$self->{_slices}}, $underlying_slice);
    push(@{$self->{slices}->{lc($species)}}, $underlying_slice);
    return $underlying_slice;
  }

  if ($species_order) {
    my $preset_underlying_slice = undef;
    foreach my $this_underlying_slice (@{$self->{_slices}}) {
      if (!$this_genomic_align->{original_dbID} and $this_genomic_align->dbID) {
        $this_genomic_align->{original_dbID} = $this_genomic_align->dbID;
      }
      if (grep {$_ == $this_genomic_align->{original_dbID}}
          @{$this_underlying_slice->{genomic_align_ids}}) {
        $preset_underlying_slice = $this_underlying_slice;
      }
    }
    if ($preset_underlying_slice) {
      my $overlap = 0;
      my $slice_mapper_pairs = $preset_underlying_slice->get_all_Slice_Mapper_pairs();
      foreach my $slice_mapper_pair (@$slice_mapper_pairs) {
        my $block_start = $slice_mapper_pair->{start};
        my $block_end = $slice_mapper_pair->{end};
	#a block may not have a start and end if there is no sequence
	#eg the cigar_line looks like 139D17186X
	next if (!defined $this_block_start || !defined $this_block_end);
        if ($this_block_start <= $block_end and $this_block_end >= $block_start) {
          $overlap = 1;
          last;
        }
      }
      if (!$overlap) {
        ## This block does not overlap any previous block: add it!
        $underlying_slice = $preset_underlying_slice;
      }
    }
  }

  if (!$underlying_slice) {
    ## Try to add this alignment to an existing underlying Bio::EnsEMBL::Compara::AlignSlice::Slice
    SLICE: foreach my $this_underlying_slice (@{$self->{slices}->{lc($species)}}) {
      my $slice_mapper_pairs = $this_underlying_slice->get_all_Slice_Mapper_pairs();
      PAIRS: foreach my $slice_mapper_pair (@$slice_mapper_pairs) {
        my $block_start = $slice_mapper_pair->{start};
        my $block_end = $slice_mapper_pair->{end};
        if ($this_block_start <= $block_end and $this_block_end >= $block_start) {
          next SLICE; ## This block overlaps a previous block
        }
      }
      ## This block does not overlap any previous block: add it!
      $underlying_slice = $this_underlying_slice;
    }
  }

  if (!$underlying_slice) {
    ## This block overlaps at least one block in every available underlying
    ## Bio::EnsEMBL::Compara::AlignSlice::Slice. Create a new one!
    $underlying_slice = new Bio::EnsEMBL::Compara::AlignSlice::Slice(
            -length => $align_slice_length,
            -requesting_slice => $self->reference_Slice,
            -align_slice => $self,
            -method_link_species_set => $self->{_method_link_species_set},
            -genome_db => $this_genomic_align->dnafrag->genome_db,
            -expanded => $expanded,
        );
    push(@{$self->{_slices}}, $underlying_slice);
    push(@{$self->{slices}->{lc($species)}}, $underlying_slice);
  }

#   if ($this_genomic_align->cigar_line =~ /X/) {
#     ## This GenomicAlign is part of a composite alignment
#     my $genomic_align_group = $this_genomic_align->genomic_align_group_by_type("composite");
#     foreach my $this_genomic_align (@{$genomic_align_group->genomic_align_array}) {
#     #  next if ($this_genomic_align 
#     }
#   }

  return $underlying_slice;
}


=head2 _sort_and_restrict_GenomicAlignBlocks

  Arg[1]      : listref of Bio::EnsEMBL::Compara::GenomicAlignBlocks $gabs
  Example     : $sorted_gabs = _sort_GenomicAlignBlocks($gabs);
  Description : This method returns the original list of
                Bio::EnsEMBL::Compara::GenomicAlignBlock objects in order
  Returntype  : listref of Bio::EnsEMBL::Compara::GenomicAlignBlock objects
  Exceptions  : 
  Caller      : methodname()

=cut

sub _sort_and_restrict_GenomicAlignBlocks {
  my ($genomic_align_blocks) = @_;
  my $sorted_genomic_align_blocks = [];
  return $sorted_genomic_align_blocks if (!$genomic_align_blocks);

  my $last_end;
  foreach my $this_genomic_align_block (sort _sort_gabs @{$genomic_align_blocks}) {
    if (defined($last_end) and
        $this_genomic_align_block->reference_genomic_align->dnafrag_start <= $last_end) {
      if ($this_genomic_align_block->reference_genomic_align->dnafrag_end > $last_end) {
        $this_genomic_align_block = $this_genomic_align_block->restrict_between_reference_positions($last_end + 1, undef);
      } else {
        warning("Ignoring Bio::EnsEMBL::Compara::GenomicAlignBlock #".
                ($this_genomic_align_block->dbID or "-unknown")." because it overlaps".
                " previous Bio::EnsEMBL::Compara::GenomicAlignBlock");
        next;
      }
    }
    $last_end = $this_genomic_align_block->reference_genomic_align->dnafrag_end;
    push(@$sorted_genomic_align_blocks, $this_genomic_align_block);
  }

  return $sorted_genomic_align_blocks;
}

=head2 _sort_GenomicAlignBlocks

  Arg[1]      : listref of Bio::EnsEMBL::Compara::GenomicAlignBlocks $gabs
  Example     : $sorted_gabs = _sort_GenomicAlignBlocks($gabs);
  Description : This method returns the original list of
                Bio::EnsEMBL::Compara::GenomicAlignBlock objects in order
  Returntype  : listref of Bio::EnsEMBL::Compara::GenomicAlignBlock objects
  Exceptions  : 
  Caller      : methodname()

=cut

sub _sort_GenomicAlignBlocks {
  my ($genomic_align_blocks) = @_;
  my $sorted_genomic_align_blocks = [];
  return $sorted_genomic_align_blocks if (!$genomic_align_blocks);

  my $last_end;
  foreach my $this_genomic_align_block (sort _sort_gabs @{$genomic_align_blocks}) {
    if (!defined($last_end) or
        $this_genomic_align_block->reference_genomic_align->dnafrag_start > $last_end) {
      push(@$sorted_genomic_align_blocks, $this_genomic_align_block);
      $last_end = $this_genomic_align_block->reference_genomic_align->dnafrag_end;
    } else {
      warning("Ignoring Bio::EnsEMBL::Compara::GenomicAlignBlock #".
              ($this_genomic_align_block->dbID or "-unknown")." because it overlaps".
              " previous Bio::EnsEMBL::Compara::GenomicAlignBlock");
    }
  }

  return $sorted_genomic_align_blocks;
}

sub _sort_gabs {

  if ($a->reference_genomic_align->dnafrag_start == $b->reference_genomic_align->dnafrag_start) {
    ## This may happen when a block has been splitted into small pieces and some of them contain
    ## gaps only for the reference species. In this case, use another species for sorting these
    ## genomic_align_blocks
    for (my $i = 0; $i<@{$a->get_all_non_reference_genomic_aligns()}; $i++) {
      for (my $j = 0; $j<@{$b->get_all_non_reference_genomic_aligns()}; $j++) {
        next if ($a->get_all_non_reference_genomic_aligns->[$i]->dnafrag_id !=
            $b->get_all_non_reference_genomic_aligns->[$j]->dnafrag_id);
        if (($a->get_all_non_reference_genomic_aligns->[$i]->dnafrag_start !=
                $b->get_all_non_reference_genomic_aligns->[$j]->dnafrag_start) and
            ($a->get_all_non_reference_genomic_aligns->[$i]->dnafrag_strand ==
                $b->get_all_non_reference_genomic_aligns->[$j]->dnafrag_strand)) {
          ## This other genomic_align is not a full gap and ca be used to sort these blocks
          if ($a->get_all_non_reference_genomic_aligns->[$i]->dnafrag_strand == 1) {
            return $a->get_all_non_reference_genomic_aligns->[$i]->dnafrag_start <=> 
                $b->get_all_non_reference_genomic_aligns->[$j]->dnafrag_start
          } else {
            return $b->get_all_non_reference_genomic_aligns->[$j]->dnafrag_start <=> 
                $a->get_all_non_reference_genomic_aligns->[$i]->dnafrag_start
          }
        }
      }
    }
  } else {
    return $a->reference_genomic_align->dnafrag_start <=> $b->reference_genomic_align->dnafrag_start
  }
}

=head2 _sort_and_compile_GenomicAlignBlocks

  Arg[1]      : listref of Bio::EnsEMBL::Compara::GenomicAlignBlocks $gabs
  Example     : $sorted_fake_gabs = _sort_and_compile_GenomicAlignBlocks($gabs);
  Description : This method returns a list of
                Bio::EnsEMBL::Compara::GenomicAlignBlock objects sorted by
                position on the reference Bio::EnsEMBL::Compara::DnaFrag. If two
                or more Bio::EnsEMBL::Compara::GenomicAlignBlock objects
                overlap, it compile them, using the _compile_GenomicAlignBlocks
                method.
  Returntype  : listref of Bio::EnsEMBL::Compara::GenomicAlignBlock objects
  Exceptions  : 
  Caller      : methodname()

=cut

sub _sort_and_compile_GenomicAlignBlocks {
  my ($genomic_align_blocks) = @_;
  my $sorted_genomic_align_blocks = [];
  return $sorted_genomic_align_blocks if (!$genomic_align_blocks);

  ##############################################################################################
  ##
  ## Compile GenomicAlignBlocks in group of GenomicAlignBlocks based on reference coordinates
  ##
  my $sets_of_genomic_align_blocks = [];
  my $start_pos;
  my $end_pos;
  my $this_set_of_genomic_align_blocks = [];
  foreach my $this_genomic_align_block (sort _sort_gabs @$genomic_align_blocks) {
    my $this_start_pos = $this_genomic_align_block->reference_genomic_align->dnafrag_start;
    my $this_end_pos = $this_genomic_align_block->reference_genomic_align->dnafrag_end;
    if (defined($end_pos) and ($this_start_pos <= $end_pos)) {
      # this genomic_align_block overlaps previous one. Extend this set_of_coordinates
      $end_pos = $this_end_pos if ($this_end_pos > $end_pos);
    } else {
      # there is a gap between this genomic_align_block and the previous one. Close and save
      # this set_of_genomic_align_blocks (if it exists) and start a new one.
      push(@{$sets_of_genomic_align_blocks}, [$start_pos, $end_pos, $this_set_of_genomic_align_blocks])
          if (defined(@$this_set_of_genomic_align_blocks));
      $start_pos = $this_start_pos;
      $end_pos = $this_end_pos;
      $this_set_of_genomic_align_blocks = [];
    }
    push(@$this_set_of_genomic_align_blocks, $this_genomic_align_block);
  }
  push(@{$sets_of_genomic_align_blocks}, [$start_pos, $end_pos, $this_set_of_genomic_align_blocks])
        if (defined(@$this_set_of_genomic_align_blocks));
  ##
  ##############################################################################################

  foreach my $this_set_of_genomic_align_blocks (@$sets_of_genomic_align_blocks) {
    my $this_compiled_genomic_align_block;
    if (@$this_set_of_genomic_align_blocks == 1) {
      $this_compiled_genomic_align_block = $this_set_of_genomic_align_blocks->[0];
    } else {
      $this_compiled_genomic_align_block =
          _compile_GenomicAlignBlocks(@$this_set_of_genomic_align_blocks);
    }
    push(@{$sorted_genomic_align_blocks}, $this_compiled_genomic_align_block);
  }

  return $sorted_genomic_align_blocks;
}

=head2 _compile_GenomicAlignBlocks

  Arg [1]     : integer $start_pos (the start of the fake genomic_align)
  Arg [2]     : integer $end_pos (the end of the fake genomic_align)
  Arg [3]     : listref of Bio::EnsEMBL::Compara::GenomicAlignBlocks $set_of_genomic_align_blocks
                $all_genomic_align_blocks (the pairwise genomic_align_blocks used for
                this fake multiple genomic_aling_block)
  Example     : 
  Description : 
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Exceptions  : 
  Caller      : methodname

=cut

sub _compile_GenomicAlignBlocks {
  my ($start_pos, $end_pos, $all_genomic_align_blocks) = @_;

  ############################################################################################
  ##
  ## Change strands in order to have all reference genomic aligns on the forward strand
  ##
  my $strand;
  foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
    my $this_genomic_align = $this_genomic_align_block->reference_genomic_align;
    if (!defined($strand)) {
      $strand = $this_genomic_align->dnafrag_strand;
    } elsif ($strand != $this_genomic_align->dnafrag_strand) {
      $strand = 0;
    }
    if ($this_genomic_align->dnafrag_strand == -1) {

	if (UNIVERSAL::isa($this_genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
	    foreach my $this_node (@{$this_genomic_align_block->get_all_nodes}) {
		my $genomic_align_group = $this_node->genomic_align_group;
		next if (!$genomic_align_group);
		foreach my $genomic_align (@{$genomic_align_group->get_all_GenomicAligns}) {
		    $genomic_align->reverse_complement;
		}
	    }
	} else {
	    foreach my $genomic_align (@{$this_genomic_align_block->genomic_align_array}) {
		$genomic_align->reverse_complement;
	    }
	}
    }
  }
  ##
  ############################################################################################

  ## Nothing has to be compiled if there is one single GenomicAlignBlock!
  $all_genomic_align_blocks->[0]->reverse_complement;
  return $all_genomic_align_blocks->[0] if (scalar(@$all_genomic_align_blocks) == 1);

  ############################################################################################
  ##
  ## Fix all sequences
  ##
  foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
    my $this_genomic_align = $this_genomic_align_block->reference_genomic_align;
    my $this_start_pos = $this_genomic_align->dnafrag_start;
    my $this_end_pos = $this_genomic_align->dnafrag_end;
    my $starting_gap = $this_start_pos - $start_pos;
    my $ending_gap = $end_pos - $this_end_pos;

    my $this_cigar_line = $this_genomic_align->cigar_line;
    my $this_original_sequence = $this_genomic_align->original_sequence;
    $this_genomic_align->aligned_sequence("");
    if ($starting_gap) {
      $this_cigar_line = $starting_gap."M".$this_cigar_line;
      $this_original_sequence = ("N" x $starting_gap).$this_original_sequence;
    }
    if ($ending_gap) {
      $this_cigar_line .= $ending_gap."M";
      $this_original_sequence .= ("N" x $ending_gap);
    }
    $this_genomic_align->cigar_line($this_cigar_line);
    $this_genomic_align->original_sequence($this_original_sequence);
    
    foreach my $this_genomic_align (@{$this_genomic_align_block->get_all_non_reference_genomic_aligns}) {
      $this_genomic_align->aligned_sequence("");
      my $this_cigar_line = $this_genomic_align->cigar_line;
      $this_cigar_line = $starting_gap."D".$this_cigar_line if ($starting_gap);
      $this_cigar_line .= $ending_gap."D" if ($ending_gap);
      $this_genomic_align->cigar_line($this_cigar_line);
      $this_genomic_align->aligned_sequence(); # compute aligned_sequence using cigar_line
    }
  }
  ##
  ############################################################################################

  ############################################################################################
  ##
  ## Distribute gaps
  ##
  my $aln_pos = 0;
  my $gap;
  do {
    my $gap_pos;
    my $genomic_align_block;
    $gap = undef;

    ## Get the (next) first gap from all the alignments (sets: $gap_pos, $gap and $genomic_align_block_id)
    foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
      my $this_gap_pos = index($this_genomic_align_block->reference_genomic_align->aligned_sequence,
          "-", $aln_pos);
      if ($this_gap_pos > 0 and (!defined($gap_pos) or $this_gap_pos < $gap_pos)) {
        $gap_pos = $this_gap_pos;
        my $gap_string = substr($this_genomic_align_block->reference_genomic_align->aligned_sequence,
            $gap_pos);
        ($gap) = $gap_string =~ /^(\-+)/;
        $genomic_align_block = $this_genomic_align_block;
      }
    }

    ## If a gap has been found, apply it to the other GAB
    if ($gap) {
      $aln_pos = $gap_pos + length($gap);
      foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
        next if ($genomic_align_block eq $this_genomic_align_block); # Do not add gap to itself!!
	if (UNIVERSAL::isa($this_genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
	    foreach my $this_node (@{$this_genomic_align_block->get_all_nodes}) {
		my $genomic_align_group = $this_node->genomic_align_group;
		next if (!$genomic_align_group);
		foreach my $this_genomic_align (@{$genomic_align_group->get_all_GenomicAligns}) {
		    # insert gap in the aligned_sequence
		    my $aligned_sequence = $this_genomic_align->aligned_sequence;
		    substr($aligned_sequence, $gap_pos, 0, $gap);
		    $this_genomic_align->aligned_sequence($aligned_sequence);
		}
	    }
	} else {
	    foreach my $this_genomic_align (@{$this_genomic_align_block->genomic_align_array}) {
		# insert gap in the aligned_sequence
		my $aligned_sequence = $this_genomic_align->aligned_sequence;
		substr($aligned_sequence, $gap_pos, 0, $gap);
		$this_genomic_align->aligned_sequence($aligned_sequence);
	    }
	}
      }
    }
    
  } while ($gap); # exit loop if no gap has been found

  ## Fix all cigar_lines in order to match new aligned_sequences
  foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
    foreach my $this_genomic_align (@{$this_genomic_align_block->genomic_align_array}) {
      $this_genomic_align->cigar_line(""); # undef old cigar_line
      $this_genomic_align->cigar_line(); # compute cigar_line from aligned_sequence
    }
  }
  ##
  ############################################################################################

  ############################################################################################
  ##
  ##  Create the reference_genomic_align for this fake genomic_align_block
  ##
  ##  All the blocks have been edited and all the reference genomic_aling
  ##  should be equivalent. Here, we create a new one with no fixed sequence.
  ##  This permits to retrieve the real sequence when needed
  ##
  my $reference_genomic_align;
  if (@$all_genomic_align_blocks) {
    my $this_genomic_align = $all_genomic_align_blocks->[0]->reference_genomic_align;
    $reference_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
            -dbID => -1,
            -dnafrag => $this_genomic_align->dnafrag,
            -dnafrag_start => $start_pos,
            -dnafrag_end => $end_pos,
            -dnafrag_strand => 1,
            -cigar_line => $this_genomic_align->cigar_line,
            -method_link_species_set => $this_genomic_align->method_link_species_set,
            -level_id => 0
        );
  }
  ##
  ############################################################################################

  ## Create the genomic_align_array (the list of genomic_aling for this fake gab
  my $genomic_align_array = [$reference_genomic_align];
  foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
    foreach my $this_genomic_align (@{$this_genomic_align_block->get_all_non_reference_genomic_aligns}) {
      $this_genomic_align->genomic_align_block_id(0); # undef old genomic_align_block_id
      push(@$genomic_align_array, $this_genomic_align);
    }
  }
  
  ## Create the fake multiple Bio::EnsEMBL::Compara::GenomicAlignBlock
  my $fake_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -length => ($end_pos - $start_pos + 1),
          -genomic_align_array => $genomic_align_array,
          -reference_genomic_align => $reference_genomic_align,
      );

  if ($strand == -1) {
    $fake_genomic_align_block->reverse_complement;
  }

  return $fake_genomic_align_block;
}


sub DESTROY {
  my $self = shift;
  ## Remove circular reference in order to allow Perl to clear the object
  $self->{all_genomic_align_blocks} = undef;
}

1;
