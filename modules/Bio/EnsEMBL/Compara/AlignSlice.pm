=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::AlignSlice - An AlignSlice can be used to map genes and features from one species onto another one

=head1 DESCRIPTION

INTRODUCTION

An AlignSlice is an object built with a reference Slice and the corresponding set of genomic alignments.
The genomic alignments are used to map features from one species onto another and viceversa.

STRUCTURE

Every Bio::EnsEMBL::Compara::AlignSlice contains a set of Bio::EnsEMBL::Compara::AlignSlice::Slice
objects, at least one by species involved in the alignments. For instance, if the reference Slice is a
human slice and the set of alignments corresponds to human-mouse LASTZ_NET alignments, there will be at
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
second alignment is ignored. This is due to lack of information needed to reconciliate both alignments.
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
systematic (insert as many gaps as needed in order to accommodate the insertions and never overlap
them) and computationally cheap as no realignment is needed. You may ask this module to solve overlapping
alignments in this way set setting the "solve_overlapping" option to TRUE. 

Finally, it is also possible to merge the overlapping alignments by setting solve_overlapping to 'restrict'. 
The second overlapping alignment is restricted so that it will start at the end+1 of the first alignment.
eg
           Human (ref) CTGTGAAAA----CCCCATTAGG
           Mouse (1)     CTGAAAATTTTCCCC
           Mouse (1)                    ATTA

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

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::AlignSlice;

use strict;
use warnings;

use Scalar::Util qw(weaken);

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning info verbose stack_trace);
use Bio::EnsEMBL::Compara::AlignSlice::Exon;
use Bio::EnsEMBL::Compara::AlignSlice::Slice;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::SimpleAlign;

use Data::Dumper;
$Data::Dumper::Pad = '';

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
               If set to 0 only one of the overlapping alignments is returned.
               If set to 1 all overlapping alignments are returned according to 
               the method described in OVERLAPPING ALIGNMENTS section
               If set to 'restrict' the overlapping alignments are merged according to
               the method described in OVERLAPPING ALIGNMENTS section
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

            #my $gab_id = $tree->get_all_leaves->[0]->get_all_genomic_aligns_for_node->[0]->genomic_align_block_id;
	    #Hope always have a reference_genomic_align. The above doesn't work because only the reference species
	    #has the genomic_align_block_id set
            my $gab_id = $tree->reference_genomic_align->genomic_align_block_id;
	    my $block_id = $block->dbID;

	    #if the block has been restricted, need to look at original_dbID
	    if (!defined $block_id) {
		$block_id = $block->original_dbID;
	    }
	    my $tree_ref_ga = $tree->{reference_genomic_align};
	    my $block_ref_ga = $block->{reference_genomic_align};

	    #Need to check the ref_ga details not just the block id because
	    #the original_dbID is not unique for 2x genome blocks
            if ($gab_id == $block_id && 
		$tree_ref_ga->dnafrag_start == $block_ref_ga->dnafrag_start && 
		$tree_ref_ga->dnafrag_end == $block_ref_ga->dnafrag_end && 
		$tree_ref_ga->dnafrag_strand == $block_ref_ga->dnafrag_strand) {

                $block->{_alignslice_from} = $tree->{_alignslice_from};
                $block->{_alignslice_to} = $tree->{_alignslice_to};
	    }
        }
    }
  } elsif ($genomic_align_blocks) {
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
               understood as "Homo sapiens". However if the GenomeDB is found
               to already have _ defined in the name then this behaviour is
               disabled.
  Returntype : listref of Bio::EnsEMBL::Compara::AlignSlice::Slice
               objects.
  Exceptions : 
  Caller     : $object->methodname

=cut

sub get_all_Slices {
  my ( $self, @species_names ) = @_;
  my $slices = [];

  if (@species_names) {

    #Substitute _ for spaces & check if the current GenomeDB matches with any of them
    my %species_to_keep = ();
    foreach my $this_species_name (@species_names) {
      ( my $space_species_name = $this_species_name ) =~ s/_/ /g;
      $species_to_keep{$this_species_name} = 1;
      $species_to_keep{$space_species_name} = 1;
    }

    my %removed_species = ();
    $self->{_removed_species} = \%removed_species;
    foreach my $slice ( @{ $self->{_slices} } ) {
      if ($species_to_keep{$slice->genome_db->name}) {
        push @$slices, $slice;
      } else {
        $removed_species{$slice->genome_db->name} = 1;
      }
    }
  }
  else {
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

sub summary_as_hash {
  my ($self, $display_species_set, $mask) = @_;
  my $simple_align;

  my $genome_db_name_counter;

  my $alignment_summary;
  foreach my $slice (@{$self->get_all_Slices(@$display_species_set)}) {
      my $slice_mapper_pairs = $slice->get_all_Slice_Mapper_pairs();
      my $id;
      my $start;
      my $end;
      my $block_start;
      my $block_end;
      my $seq_region;
      my $length;
      my $strand;
      my $composite_length;
      my $species_name = $slice->genome_db->name;
      my $description = "";
      my $alignSeq;

      my @names;
      $composite_length = 0;
      my $prev_dnafrag_name;
      my $summary;

      #necessary to allow masking to take affect
      undef($slice->{seq});

      ## This is a composite segment.
      ## We need to fix the name and the length
      foreach my $slice_mapper_pair (@$slice_mapper_pairs) {
	push(@names, $slice_mapper_pair->{slice}->name);
	
	$seq_region = $slice_mapper_pair->{slice}{seq_region_name};
	$length = $slice_mapper_pair->{slice}{seq_region_length};
	$strand = $slice_mapper_pair->{slice}{strand};
	$start = $slice_mapper_pair->{slice}{start};
	$end = $slice_mapper_pair->{slice}{end};
	    
	#No repeat masking for ancestral sequences (to prevent warnings)
	if ($mask =~ /^soft/ && $seq_region !~ /Ancestor/) {
	  $slice_mapper_pair->{slice}{seq} = $slice_mapper_pair->{slice}->get_repeatmasked_seq(undef,1)->seq;
	} elsif ($mask =~ /^hard/ && $seq_region!~ /Ancestor/) {
	  $slice_mapper_pair->{slice}{seq} = $slice_mapper_pair->{slice}->get_repeatmasked_seq()->seq;
	}	
      }

      #multiple fragments within one species means that there are several values for seq_region, start and end
      #add a description line to fully describe the fragments
      if (@$slice_mapper_pairs > 1) {
	$start = 1;
	$end = $slice->length;
	$seq_region = "Composite";
	$description = "$seq_region is: " . join(" + ", @names);	
      } 

      %$summary = ('start' => $start,
		   'end'   => $end,
		   'strand' => $strand,
		   'species' => $species_name,
		   'seq_region' => $seq_region,
		   'description' => $description,
		   'seq' => $slice->seq);
      push @$alignment_summary, $summary;

    }
  
  return $alignment_summary;
}

=head2 get_SimpleAlign

  Arg[1]      : (optional) reference to an array of species to restrict the alignment to
  Arg[2]      : (optional) What detail to use for the ID field
                "full" => $species_name.$seq_region/$seq_region_start-$seq_region_end
                none => $slice->genome_db->name + counter/
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
  $simple_align->missing_char('.'); # only useful for Nexus files

  my $genome_db_name_counter;

  foreach my $slice (@{$self->get_all_Slices(@species)}) {
    my $seq = Bio::LocatableSeq->new(
            -SEQ    => $slice->seq,
            -START  => $slice->start,
            #-END    => $slice->end,
            -ID     => $slice->genome_db->name.($genome_db_name_counter->{$slice->genome_db->name} or ""),
            -STRAND => $slice->strand
        );
    # Avoid warning in BioPerl about len(seq) != end-start+1
    $seq->{end} = $slice->end;

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
                    $align_slice->get_all_ConservationScores(1000, "AVERAGE", 10);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::ConservationScore objects for the
               Bio::EnsEMBL::Compara::AlignSlice object. It calls either
               _get_expanded_conservation_scores if the AlignSlice has 
               "expanded" set or _get_condensed_conservation_scores for 
               condensed mode.
               It sets up the align_start, align_end and slice_length and map 
               the resulting objects onto the AlignSlice. 
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
   
  #Get scores in either expanded or condensed mode
  if ($self->{expanded}) {
      $all_conservation_scores = $self->_get_expanded_conservation_scores($conservation_score_adaptor, $display_size, $display_type, $window_size);
  } else {
      $all_conservation_scores = $self->_get_condensed_conservation_scores($conservation_score_adaptor, $display_size, $display_type, $window_size);
  }

  return $all_conservation_scores;
}

=head2 _get_expanded_conservation_scores

  Arg  1     : Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor
  Arg  2     : (opt) integer $display_size (default 700)
  Arg  3     : (opt) string $display_type (one of "AVERAGE" or "MAX") (default "MAX")
  Arg  4     : (opt) integer $window_size
  Example    : my $conservation_scores =
                    $self->_get_expanded_conservation_scores($cs_adaptor, 1000, "AVERAGE", 10);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::ConservationScore objects for the
               Bio::EnsEMBL::Compara::GenomicAlignBlock objects underlying
               this Bio::EnsEMBL::Compara::AlignSlice object. This method
               calls the Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor->
               fetch_all_by_GenomicAlignBlock() method. It sets up the align_start,
               align_end and slice_length and map the resulting objects onto
               the AlignSlice. $diaplay_slize, $display_type and $window_size
               are passed to the fetch_all_by_GenomicAlignBlock() method.
               Please refer to the documentation in
               Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor
               for more details.
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::ConservationScore 
               objects.
  Caller     : object::methodname
  Status     : At risk

=cut

sub _get_expanded_conservation_scores {
    my ($self, $conservation_score_adaptor, $display_size, $display_type, $window_size) = @_;
    my $y_axis_min;
    my $y_axis_max;

    my $all_conservation_scores = [];
    my $offset = 0; #the start of each gab in alignment coords
    my $prev_gab_end;
    foreach my $this_genomic_align_block (@{$self->get_all_GenomicAlignBlocks()}) {
	$this_genomic_align_block->restricted_aln_start($this_genomic_align_block->{_alignslice_from});
	$this_genomic_align_block->restricted_aln_end($this_genomic_align_block->{_alignslice_to});

	#Need to map the coords I get back from the conservation_score_adaptor onto the slice using the start position of the genomic_align_block
	my $all_these_conservation_scores = $conservation_score_adaptor->fetch_all_by_GenomicAlignBlock(
													$this_genomic_align_block, 1,$this_genomic_align_block->length, $self->get_all_Slices()->[0]->length, 
													$display_size, $display_type, $window_size);

	#Need to account for gaps between gabs which will be slice end - start on the reference slice.
	if ($prev_gab_end) {
	    my $gap = $this_genomic_align_block->reference_slice_start - $prev_gab_end - 1;
	    if ($gap)  {
		$offset += $gap;
	    }
	}
	$prev_gab_end = $this_genomic_align_block->reference_slice_end;

	foreach my $score (@$all_these_conservation_scores) {
	    $score->position($score->position + $offset);
	}

	#offset is the sum of preceding gab lengths
	$offset += ($this_genomic_align_block->restricted_aln_end - $this_genomic_align_block->restricted_aln_start + 1);

        #Check there are scores present.
        next unless (scalar @$all_these_conservation_scores);

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
	push (@$all_conservation_scores, @$all_these_conservation_scores);
    }
 
    #Check to see if there are any scores found
    if (@$all_conservation_scores) {
        #set overall min and max
        $all_conservation_scores->[0]->y_axis_min($y_axis_min);
        $all_conservation_scores->[0]->y_axis_max($y_axis_max);
    }
    return $all_conservation_scores;
}

=head2 _get_condensed_conservation_scores

  Arg  1     : Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor
  Arg  2     : (opt) integer $display_size (default 700)
  Arg  3     : (opt) string $display_type (one of "AVERAGE" or "MAX") (default "MAX")
  Arg  4     : (opt) integer $window_size
  Example    : my $conservation_scores =
                    $self->_get_expanded_conservation_scores($cs_adaptor, 1000, "AVERAGE", 10);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::ConservationScore objects for the
               reference Bio::EnsEMBL::Slice object of 
               this Bio::EnsEMBL::Compara::AlignSlice object. This method
               calls the Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor->
               fetch_all_by_MethodLinkSpeciesSet_Slice() method. It sets up 
               the align_start, align_end and slice_length and map the 
               resulting objects onto the AlignSlice. $display_slize, 
               $display_type and $window_size are passed to the 
               fetch_all_by_MethodLinkSpeciesSet_Slice() method.
               Please refer to the documentation in
               Bio::EnsEMBL::Compara::DBSQL::ConservationScoreAdaptor
               for more details.
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::ConservationScore 
               objects.
  Caller     : object::methodname
  Status     : At risk

=cut

sub _get_condensed_conservation_scores {
    my ($self, $conservation_score_adaptor, $display_size, $display_type, $window_size) = @_;

    my $all_conservation_scores = [];

    throw ("Must have method_link_species_set defined to retrieve conservation scores for a condensed AlignSlice") if (!defined $self->{_method_link_species_set});
    throw ("Must have reference slice defined to retrieve conservation scores for a condensed AlignSlice") if (!defined $self->{'reference_slice'});

    # select the conservation score mlss_id linked to the msa
    my $sql = 'SELECT method_link_species_set_id FROM method_link_species_set_tag JOIN method_link_species_set USING (method_link_species_set_id) JOIN method_link USING (method_link_id) WHERE type LIKE "%CONSERVATION\_SCORE" AND tag = "msa_mlss_id" AND value = ?';
    my $sth = $conservation_score_adaptor->prepare($sql);
    $sth->execute($self->{_method_link_species_set}->dbID);
    
    my ($cs_mlss_id) = @{$sth->fetchrow_arrayref};
    $sth->finish;

    throw ("Unable to find conservation score method_link_species_set for this multiple alignment " . $self->{_method_link_species_set}->dbID) if (!defined $cs_mlss_id);
    my $mlss_adaptor = $self->adaptor->db->get_MethodLinkSpeciesSetAdaptor();

    my $cs_mlss = $mlss_adaptor->fetch_by_dbID($cs_mlss_id);

    $all_conservation_scores = $conservation_score_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($cs_mlss, $self->{'reference_slice'}, $display_size, $display_type, $window_size);
    
    return $all_conservation_scores;
}


=head2 get_all_ConstrainedElements

  Arg  1     : (opt) string $method_link_type (default = GERP_CONSTRAINED_ELEMENT)
  Arg  2     : (opt) listref Bio::EnsEMBL::Compara::GenomeDB $species_set
               (default, the set of species from the MethodLinkSpeciesSet used
               to build this AlignSlice)
  Example    : my $constrained_elements =
                    $align_slice->get_all_ConstrainedElements();
  Description: Retrieve the corresponding constrained elements for these alignments.
               Objects will be located on this AlignSlice, i.e. the
               reference_slice, reference_slice_start, reference_slice_end
               and reference_slice_strand will refer to this AlignSlice
               object
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::ConstrainedElement
               objects.
  Caller     : object::methodname
  Status     : At risk

=cut

sub get_all_ConstrainedElements {
  my ($self, $method_link_type, $species_set) = @_;
  my $all_constrained_elements = [];

  $method_link_type ||= "GERP_CONSTRAINED_ELEMENT";
  $species_set      ||= $self->get_MethodLinkSpeciesSet->species_set->genome_dbs;

  my $key_cache = "_constrained_elements_".$method_link_type."::"
                    . join("-", sort map {my $s = $_; $s =~ s/\W/_/g; $s} map {$_->name} @$species_set);

  if (!defined($self->{$key_cache})) {
    my $method_link_species_set_adaptor = $self->adaptor->db->get_MethodLinkSpeciesSetAdaptor();
    my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs(
        $method_link_type, $species_set);

    if ($method_link_species_set) {
      my $constrained_element_adaptor = $self->adaptor->db->get_ConstrainedElementAdaptor();
      $all_constrained_elements = $constrained_element_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
          $method_link_species_set, $self->reference_Slice);
      my $big_mapper = $self->{_reference_Mapper};
      foreach my $this_constrained_element (@{$all_constrained_elements}) {
        my $reference_slice_start;
        my $reference_slice_end;
        my $reference_slice_strand;

        my @alignment_coords = $big_mapper->map_coordinates(
            "sequence", # $self->genomic_align->dbID,
            $this_constrained_element->start + $this_constrained_element->slice->start - 1,
            $this_constrained_element->end + $this_constrained_element->slice->start - 1,
            $this_constrained_element->strand,
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

        $this_constrained_element->slice($self);
        $this_constrained_element->start($reference_slice_start);
        $this_constrained_element->end($reference_slice_end);
        $this_constrained_element->strand($reference_slice_strand);
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
    $reference_genomic_align->genomic_align_block->start($align_slice_length + 1);
    $original_genomic_align_block->{_alignslice_start} = $align_slice_length;
    if ($expanded) {
      $align_slice_length += CORE::length($reference_genomic_align->aligned_sequence("+FAKE_SEQ"));
      $reference_genomic_align->genomic_align_block->end($align_slice_length);
      $big_mapper->add_Mapper($reference_genomic_align->get_Mapper(0));
    } else {
      $align_slice_length += $reference_genomic_align->dnafrag_end - $reference_genomic_align->dnafrag_start + 1;
      $reference_genomic_align->genomic_align_block->end($align_slice_length);
      $big_mapper->add_Mapper($reference_genomic_align->get_Mapper(0,1));
    }
    $reference_genomic_align->genomic_align_block->slice($self);

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
      my $new_slice = new Bio::EnsEMBL::Compara::AlignSlice::Slice(
              -length => $align_slice_length,
              -requesting_slice => $self->reference_Slice,
              -align_slice => $self,
              -method_link_species_set => $self->{_method_link_species_set},
              -genome_db => $species_def->{genome_db},
              -expanded => $expanded,
          );
      foreach my $this_genomic_align_id (@{$species_def->{genomic_align_ids}}) {
        $new_slice->{genomic_align_ids}->{$this_genomic_align_id} = 1;
      }
      push(@{$self->{slices}->{lc($genome_db_name)}}, $new_slice);
      push(@{$self->{_slices}}, $new_slice);
    }
  } else {
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
        foreach my $this_genomic_align (@{$this_genomic_align_node->get_all_genomic_aligns_for_node}) {
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

  # It is possible for the same region in the ref species (eg Gibbon) to align to 2 different blocks
  # (pairwise to human in the case of the EPO low coverage alignments). In this case, although the
  # incoming  $genomic_align_blocks will have 2 blocks, the $sorted_genomic_align_blocks will only
  # contain 1 of the blocks. It may happen that one species occurs in one block (eg gorilla) but not
  # in the other. However, the $species_order will contain gorilla but the $sorted_genomic_align_blocks
  # may not. This results in a slice being created for gorilla but it has no slice_mapper_pairs. Must
  # check the slices and remove any that have {'slice_mapper_pairs'} as undef (no alignment comes out
  # as a GAP).

  if ($species_order) {
      my $slices = $self->{_slices};
      for (my $i = (@$slices-1); $i >= 0; --$i) {
	  if (@{$slices->[$i]->get_all_Slice_Mapper_pairs()} == 0) {
	      #remove from {slices}
	      delete $self->{slices}->{$slices->[$i]->genome_db->name};
	      #remove from {_slices}
	      splice @$slices, $i, 1;
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

  my $this_block_start = $this_genomic_align_block->start;
  my $this_block_end = $this_genomic_align_block->end;
  my $this_core_slice = $this_genomic_align->get_Slice();
  if (!$this_core_slice) {
    $this_core_slice = new Bio::EnsEMBL::Slice(
          -coord_system => $aligngap_coord_system, #set coord_system_name to "alignment"
          -seq_region_name => "GAP",
          -start => $this_block_start,
          -end => $this_block_end,
          -strand => 0
        );
    $this_core_slice->{seq} = "." x ($this_block_end - $this_block_start + 1);
    $this_core_slice->{karyotype} = 0;
  }
  return if (!$this_core_slice); ## The restriction of the GenomicAlignBlock may return a void GenomicAlign

  ## This creates a link between the slice and the tree node. This is required to display
  ## the tree on the web interface.
  if ($this_genomic_align->genome_db->name eq "ancestral_sequences") {
    foreach my $genomic_align_node (@{$this_genomic_align_block->get_all_sorted_genomic_align_nodes}) {
      my $genomic_align_group = $genomic_align_node->genomic_align_group;
      next if (!$genomic_align_group);

      foreach my $genomic_align (@{$genomic_align_group->get_all_GenomicAligns}) {
        if ($this_genomic_align == $genomic_align) {
          my $simple_tree = $genomic_align_node->newick_format('simple');
          $simple_tree =~ s/\_[^\_]+\_\d+\_\d+\[[\+\-]\]//g;
          $simple_tree =~ s/\:[\d\.]+//g;
          $this_core_slice->{_tree} = $simple_tree;
          $this_core_slice->{_node_in_tree} = $genomic_align_node;
          weaken($this_core_slice->{_node_in_tree});
          last;
        }
      }
    }
  }


  my $this_mapper = $this_genomic_align->get_Mapper(0, !$expanded);
  # Fix block start and block end for composite segments (2X genomes)
  if ($this_genomic_align->cigar_line =~ /^(\d*)X/ or $this_genomic_align->cigar_line =~ /(\d*)X$/) {

    my $cigar_arrayref = $this_genomic_align->get_cigar_arrayref();
    my $matches = 0;
    for (my $i =0; $i<@$cigar_arrayref; $i++) {
      my $cigar_type = substr($cigar_arrayref->[$i], -1, 1);
      my $cigar_num = substr($cigar_arrayref->[$i], 0 , -1);
      $cigar_num = 1 if ($cigar_num eq "");

      if ($cigar_type eq "M") {
        $matches = 1;
        last;
      } elsif ($cigar_type =~ /[XD]/) {
        $this_block_start += $cigar_num;
      }
    }
    if ($matches) {
      for (my $j = @$cigar_arrayref - 1; $j>=0; $j--) {
        my $cigar_type = substr($cigar_arrayref->[$j], -1, 1);
        my $cigar_num = substr($cigar_arrayref->[$j], 0 , -1);
        $cigar_num = 1 if ($cigar_num eq "");

        if ($cigar_type eq "M") {
          last;
        } elsif ($cigar_type =~ /[XD]/) {
          $this_block_end -= $cigar_num;
        }
      }
    } else {
      $this_block_start = undef;
      $this_block_end = undef;
    }
  }

  #Skip if only have X and no sequence then $this_block_start and $this_block_end are undefined.
  if (!defined $this_block_start && !defined $this_block_end) {
      return;
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
    if (!$this_genomic_align->{_original_dbID} and $this_genomic_align->dbID) {
      $this_genomic_align->{_original_dbID} = $this_genomic_align->dbID;
    }
    foreach my $this_underlying_slice (@{$self->{slices}->{lc($species)}}) {
      if ($this_underlying_slice->{genomic_align_ids}->{$this_genomic_align->{_original_dbID}}) {
        $preset_underlying_slice = $this_underlying_slice;
        last;
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
  Example     : $sorted_gabs = _sort_and_restrict_GenomicAlignBlocks($gabs);
  Description : This method returns the original list of
                Bio::EnsEMBL::Compara::GenomicAlignBlock objects in order of dnafrag_start.
                It will merge overlapping blocks eg the region of B which overlaps with A will be removed
                to produce a contiguous sequence AB
                A  |-----------------|
                B           |*****************|
                AB <-----------------><*******>
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
    if (defined($last_end) && $this_genomic_align_block->reference_genomic_align->dnafrag_start <= $last_end) {
      if ($this_genomic_align_block->reference_genomic_align->dnafrag_end > $last_end) {
        $this_genomic_align_block = $this_genomic_align_block->restrict_between_reference_positions($last_end + 1, undef);

      } else {
	  warning("Ignoring GenomicAlignBlock because it overlaps".
             " previous GenomicAlignBlock " . $this_genomic_align_block->dbID);
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
    } #else {
      #	my $block_id;
      #	if (UNIVERSAL::isa($a, "Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
      #	    warning("Ignoring Bio::EnsEMBL::Compara::GenomicAlignBlock #".
      #		    ($this_genomic_align_block->dbID or "-unknown")." because it overlaps".
      #		    " previous Bio::EnsEMBL::Compara::GenomicAlignBlock");
      #	} else {
      #	    warning("Ignoring Bio::EnsEMBL::Compara::GenomicAlignTree #".
      #		    ($this_genomic_align_block->node_id or "-unknown")." because it overlaps".
      #		    " previous Bio::EnsEMBL::Compara::GenomicAlignTree");
      #	}
    #}
  }

  return $sorted_genomic_align_blocks;
}

sub _sort_gabs {

    if (UNIVERSAL::isa($a, "Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
	_sort_genomic_align_block();
    } else {
	_sort_genomic_align_tree();
    }
}

sub _sort_genomic_align_block {
    
    if ($a->reference_genomic_align->dnafrag_start == $b->reference_genomic_align->dnafrag_start) {
	## This may happen when a block has been split into small pieces and some of them contain
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
			  $b->get_all_non_reference_genomic_aligns->[$j]->dnafrag_start;
		    } else {
			return $b->get_all_non_reference_genomic_aligns->[$j]->dnafrag_start <=> 
			  $a->get_all_non_reference_genomic_aligns->[$i]->dnafrag_start;
		    }
		}
	    }
	}
    } else {
	return $a->reference_genomic_align->dnafrag_start <=> $b->reference_genomic_align->dnafrag_start
    }
}

sub _sort_genomic_align_tree {

    if ($a->reference_genomic_align->dnafrag_start == $b->reference_genomic_align->dnafrag_start) {
	## This may happen when a block has been split into small pieces and some of them contain
	## gaps only for the reference species. In this case, use another species for sorting these
	## genomic_align_blocks
	my $a_leaves = $a->get_all_leaves;
	my $b_leaves = $b->get_all_leaves;
	
	for (my $i = 0; $i < @$a_leaves; $i++) {
	    for (my $j = 0; $j < @$b_leaves; $j++) {
		#look at high coverage sequences only
		my $a_gas = $a_leaves->[$i]->get_all_genomic_aligns_for_node;
		next if (@$a_gas > 1);
		my $a_ga = $a_gas->[0];
		
		my $b_gas = $b_leaves->[$j]->get_all_genomic_aligns_for_node;
		next if (@$b_gas > 1);
		my $b_ga = $b_gas->[0];
		
		next if ($a_ga->dnafrag_id != $b_ga->dnafrag_id);
		if (($a_ga->dnafrag_start != $b_ga->dnafrag_start) and ($a_ga->dnafrag_strand == $b_ga->dnafrag_strand)) {
		    ## This other genomic_align is not a full gap and ca be used to sort these blocks
		    if ($a_ga->dnafrag_strand == 1) {
			return $a_ga->dnafrag_start <=> $b_ga->dnafrag_start;
		    } else {
			return $b_ga->dnafrag_start <=> $a_ga->dnafrag_start;
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
          if (@$this_set_of_genomic_align_blocks);
      $start_pos = $this_start_pos;
      $end_pos = $this_end_pos;
      $this_set_of_genomic_align_blocks = [];
    }
    push(@$this_set_of_genomic_align_blocks, $this_genomic_align_block);
  }
  push(@{$sets_of_genomic_align_blocks}, [$start_pos, $end_pos, $this_set_of_genomic_align_blocks])
        if (@$this_set_of_genomic_align_blocks);
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

  #18/6/2013 Commented out the line below because this causes a bug when the ref-strand on the overlapping blocks is different (eg 1 on pos strand and 1 on neg strand). Why do we have this blanket reverse_comeplement?
#  $all_genomic_align_blocks->[0]->reverse_complement;
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
            -visible => 1
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
          -level_id => 0
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
