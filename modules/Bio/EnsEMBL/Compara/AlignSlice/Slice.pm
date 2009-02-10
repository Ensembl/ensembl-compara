#
# Ensembl module for Bio::EnsEMBL::Compara::AlignSlice::Slice
#
# Original author: Javier Herrero <jherrero@ebi.ac.uk>
#
# Copyright EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself

# pod documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::AlignSlice::Slice - These objects contain all the information needed
for mapping features through genomic alignments

=head1 INHERITING

This module inherits methods and attributes from Bio::EnsEMBL::Slice module.

=head1 SYNOPSIS
  

SET VALUES

GET VALUES

=head1 OBJECT ATTRIBUTES

=over

=item attribute

Description

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


package Bio::EnsEMBL::Compara::AlignSlice::Slice;

use strict;
use Bio::EnsEMBL::Slice;
use Bio::EnsEMBL::CoordSystem;
use Bio::EnsEMBL::Compara::AlignSlice::Translation;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning info verbose);
use Scalar::Util qw(weaken);


our @ISA = qw(Bio::EnsEMBL::Slice);

## Creates a new coordinate system for creating gap Slices.
my $gap_coord_system = new Bio::EnsEMBL::CoordSystem(
        -NAME => 'gap',
        -VERSION => "none",
        -TOP_LEVEL => 0,
        -SEQUENCE_LEVEL => 1,
        -RANK => 1,
    );


=head2 new (CONSTRUCTOR)

  Arg[1]     : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : Bio::EnsEMBL::Compara::AlignSlice->_create_underlying_Slices()

=cut

sub new {
  my ($class, @args) = @_;

  my $self = {};
  bless $self,$class;

  my ($length, $requesting_slice, $align_slice, $method_link_species_set, $genome_db, $expanded) =
      rearrange([qw(
          LENGTH REQUESTING_SLICE ALIGN_SLICE METHOD_LINK_SPECIES_SET GENOME_DB EXPANDED
      )], @args);

  my $version = "";
  if ($requesting_slice and ref($requesting_slice) and
      $requesting_slice->isa("Bio::EnsEMBL::Slice")) {
    $self->{'requesting_slice'} = $requesting_slice;
    my $name = $requesting_slice->name;
    $name =~ s/\:/_/g;
    $version .= $name;
  }
  weaken($self->{_align_slice} = $align_slice) if ($align_slice);
  if ($method_link_species_set and ref($method_link_species_set) and
      $method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet")) {
    $self->{_method_link_species_set} = $method_link_species_set;
    $version .= "+".$method_link_species_set->method_link_type;
    my $species_set = $method_link_species_set->species_set();
    if ($species_set) {
      $species_set = [sort {$a->name cmp $b->name} @{$species_set}];
      $version .= "(\"".join("\"+\"", map {$_->name} @$species_set)."\")";
    }
    if ($expanded) {
      $version .= "+expanded";
    } else {
      $version .= "+condensed";
    }
  }
  my $coord_system = new Bio::EnsEMBL::CoordSystem(
          -NAME => 'align_slice',
          -VERSION => $version,
          -TOP_LEVEL => 0,
          -SEQUENCE_LEVEL => 1,
          -RANK => 1,
      );

  $self->{start} = 1;
  $self->{end} = $length;
  $self->{strand} = 1;
  $self->{adaptor} = undef;
  $self->{coord_system} = $coord_system;
  $self->genome_db($genome_db) if (defined($genome_db));
  $self->{seq_region_name} = (eval{$genome_db->name} or "FakeAlignSlice");
  $self->{display_Slice_name} = $self->{seq_region_name};
  $self->{display_Slice_name} =~ s/ /_/g;
  $self->{seq_region_length} = $length;
#   $self->{located_slices} = [];

  if (!$self->genome_db) {
    throw("You must specify a Bio::EnsEMBL::Compara::GenomeDB when\n".
        "creating a Bio::EnsEMBL::Compara::AlignSlice::Slice object");
  }

  return $self;
}


=head2 genome_db

  Arg[1]     : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Example    : $slice->genome_db($human_gdb);
  Description: getter/setter for the attribute genome_db
  Returntype : Bio::EnsEMBL::Compara::GenomeDB object
  Exceptions : This attribute should never be unset. Several methods
               rely on this attribute.
  Caller     : $object->methodname

=cut

sub genome_db {
  my ($self, $genome_db) = @_;

  if (defined($genome_db)) {
    throw("[$genome_db] must bu a Bio::EnsEMBL::Compara::GenomeDB object")
      unless ($genome_db and ref($genome_db) and $genome_db->isa("Bio::EnsEMBL::Compara::GenomeDB"));
    $self->{genome_db} = $genome_db;
  }

  return $self->{genome_db};
}


=head2 display_Slice_name

  Arg[1]     : string $name
  Example    : $slice->display_Slice_name("Homo_sapiens");
  Description: getter/setter for the attribute display_Slice_name
  Returntype : string
  Caller     : $object->methodname

=cut

sub display_Slice_name {
  my ($self, $display_slice_name) = @_;

  if (defined($display_slice_name)) {
    $self->{display_Slice_name} = $display_slice_name;
  }

  return $self->{display_Slice_name};
}


=head2 add_Slice_Mapper_pair

  Arg[1]     : Bio::EnsEMBL::Slice $slice
  Arg[2]     : Bio::EnsEMBL::Mapper $mapper
  Arg[3]     : integer $start
  Arg[4]     : integer $end
  Arg[5]     : integer $strand
  Example    : $slice->add_Slice_Mapper_pair($slice, $mapper, 124, 542, -1);
  Description: Attaches a pair of Slice and the corresponding Mapper
               to this Bio::EnsEMBL::Compara::AlginSlice::Slice
               object. The Mapper contains the information for
               mapping coordinates from (to) the Slice to (from) the
               Bio::EnsEMBL::Compara::AlignSlice. Start, end and strand
               locates the $slice in the AlignSlice::Slice.
               $start and $end refer to the Coordinate System. If you are using
               a sub_Slice, this method will be using the coordinates of the
               original Bio::EnsEMBL::Compara::AlignSlice::Slice object!
  Returntype : 
  Exceptions : throws if $slice is not a Bio::EnsEMBL::Slice object
  Exceptions : throws if $mapper is not a Bio::EnsEMBL::Mapper object

=cut

sub add_Slice_Mapper_pair {
  my ($self, $slice ,$mapper, $start, $end, $strand) = @_;

  if (!$slice or !ref($slice) or !$slice->isa("Bio::EnsEMBL::Slice")) {
    throw("[$slice] must be a Bio::EnsEMBL::Slice object");
  }
  if (!$mapper or !ref($mapper) or !$mapper->isa("Bio::EnsEMBL::Mapper")) {
    throw("[$slice] must be a Bio::EnsEMBL::Mapper object");
  }

  push(@{$self->{slice_mapper_pairs}}, {
          slice => $slice,
          mapper => $mapper,
          start => $start,
          end => $end,
          strand => $strand,
      });

  return $self->{slice_mapper_pairs};
}


=head2 get_all_Slice_Mapper_pair

  Arg[1]     : [optional] bool $get_gap_slices
  Example    : $slice_mapper_pairs = $slice->get_all_Slice_Mapper_pairs();
  Description: Returns all pairs of Slices and Mappers attached to this
               Bio::EnsEMBL::Compara::AlignSlice::Slice
               The $get_gap_slice flag is normally used internally to get the
               the gap slices. These are created when the alignment(s)
               underlying the AlignSlice correspond to gaps only in one or more
               species. These are used to tell the difference between gap due to
               lack of alignments and gaps due to the alignments. If you set this
               this flag to true you will get these gap slices back but it is your
               responsability to deal with these gap slices properly.
  Returntype : list ref of hashes which keys are "slice", "mapper", "start",
               "end" and "strand". Each hash corresponds to a pair of Slice
               and Mapper and the coordintes needed to locate the Slice in
               the AlignSlice::Slice.
               start and end refer to the Coordinate System. If you are using
               a sub_Slice, this method will be using the coordinates of the
               original Bio::EnsEMBL::Compara::AlignSlice::Slice object!
  Exceptions : return a ref to an empty list if no pairs have been attached
               so far.

=cut

sub get_all_Slice_Mapper_pairs {
  my ($self, $get_gap_slices) = @_;
  my $slice_mapper_pairs = ($self->{slice_mapper_pairs} or []);
  if (!$get_gap_slices) {
    $slice_mapper_pairs = [grep {$_->{slice}->coord_system_name ne "alignment"} @$slice_mapper_pairs];
  }

  return $slice_mapper_pairs;
}


=head2 get_all_Genes_by_type

  Arg [1]    : string $type
               The biotype of genes wanted.
  Arg [2]    : (optional) string $logic_name
  Arg [3]    : (optional) boolean $load_transcripts
               If set to true, transcripts will be loaded immediately rather
               than being lazy-loaded on request.  This will result in a
               significant speed up if the Transcripts and Exons are going to
               be used (but a slow down if they are not).
  Example    : @genes = @{$slice->get_all_Genes_by_type('protein_coding',
               'ensembl')};
  Description: Retrieves genes that overlap this slice of biotype $type.
               This is primarily used by the genebuilding code when several
               biotypes of genes are used.

               The logic name is the analysis of the genes that are retrieved.
               If not provided all genes will be retrieved instead.

               This methods overwrites the core one since it sends a warning
               message and return an empty array because this AlignSlice::Slice
               object has no adaptor. This implementation calls the
               get_all_Genes methdo elsewhere in this module to fulfil the
               query.

  Returntype : listref of Bio::EnsEMBL::Genes
  Exceptions : none
  Caller     : genebuilder, general
  Status     : Stable

=cut

sub get_all_Genes_by_type{
  my ($self, $type, $logic_name, $load_transcripts) = @_;

  my @out = grep { $_->biotype eq $type } 
    @{ $self->get_all_Genes($logic_name, undef, $load_transcripts)};

  return \@out;
}


=head2 get_all_Genes

  Arg [1]    : (optional) string $logic_name
               The name of the analysis used to generate the genes to retrieve
  Arg [2]    : (optional) string $dbtype
               The dbtype of genes to obtain.  This assumes that the db has
               been added to the DBAdaptor under this name (using the
               DBConnection::add_db_adaptor method).
  Arg [3]    : (optional) boolean $load_transcripts
               This option is always disabled for AlingSlices. It only exists for
               compatibility with the Bio::EnsEMBL::Slice objects.
  Example    : @genes = @{$slice->get_all_Genes};
  Description: Retrieves all genes that overlap this slice.
  Returntype : listref of Bio::EnsEMBL::Genes
  Exceptions : none
  Caller     : none

=cut

sub get_all_Genes {
  my ($self, $logic_name, $dbtype, $load_transcripts, @parameters) = @_;

  $logic_name ||= "";
  $dbtype ||= "core";
  my ($max_repetition_length,
      $strict_order_of_exon_pieces,
      $strict_order_of_exons,
      $return_unmapped_exons) = rearrange([qw(
          MAX_REPETITION_LENGTH
          STRICT_ORDER_OF_EXON_PIECES
          STRICT_ORDER_OF_EXONS
          RETURN_UNMAPPED_EXONS
      )], @parameters);
  my $max_gap_length = 0;
  my $max_intron_length = 0;

  $max_repetition_length = 100 if (!defined($max_repetition_length));
  $strict_order_of_exon_pieces = 1 if (!defined($strict_order_of_exon_pieces));
  $strict_order_of_exons = 0 if (!defined($strict_order_of_exons));
  $return_unmapped_exons = 1 if (!defined($return_unmapped_exons));

  my $key = 'key_'.
      $dbtype.":".
      $logic_name.":".
      $max_repetition_length.":".
      $strict_order_of_exon_pieces.":".
      $strict_order_of_exons.":".
      $return_unmapped_exons;

  if (!defined($self->{$key})) {
    my $all_genes = [];

    my $all_pairs = $self->get_all_Slice_Mapper_pairs;
    return [] if (!$all_pairs or !@$all_pairs);

    ## Create larger Slices in order to speed up fetching of genes
    my $all_slices_coordinates;
    my $this_slice_coordinates;
    my $this_slice_adaptor = $all_pairs->[0]->{slice}->adaptor;
    foreach my $pair (sort {
            $a->{slice}->seq_region_name cmp $b->{slice}->seq_region_name or
            $a->{slice}->start <=> $b->{slice}->start } @$all_pairs) {
# print STDERR "Foreach pair ($pair)... $pair->{slice}->{seq_region_name} $pair->{slice}->{start}\n";
            
      my $this_slice = $pair->{slice};
      if ($this_slice_coordinates and
          ($this_slice_coordinates->{seq_region_name} eq $this_slice->seq_region_name) and
          (($this_slice->start - $this_slice_coordinates->{end}) < 10000000)) {
        ## lengthen current slice_coordinates
        $this_slice_coordinates->{end} = $this_slice->end;
      } else {
        ## save a deep copy (if needed) and reset current slice_coordinates
        if ($this_slice_coordinates->{seq_region_name}) {
          my $new_slice_coordinates = {
                  "coord_system_name" => $this_slice_coordinates->{coord_system_name},
                  "seq_region_name" => $this_slice_coordinates->{seq_region_name},
                  "start" => $this_slice_coordinates->{start},
                  "end" => $this_slice_coordinates->{end},
                  "pairs" => $this_slice_coordinates->{pairs}
              };
          push(@$all_slices_coordinates, $new_slice_coordinates);
        }
        $this_slice_coordinates->{coord_system_name} = $this_slice->coord_system_name;
        $this_slice_coordinates->{seq_region_name} = $this_slice->seq_region_name;
        $this_slice_coordinates->{start} = $this_slice->start;
        $this_slice_coordinates->{end} = $this_slice->end;
        $this_slice_coordinates->{pairs} = [];
      }
      ## Add this pair to the set of pairs of the current slice_coordinates
      push(@{$this_slice_coordinates->{pairs}}, $pair);
    }
    push(@$all_slices_coordinates, $this_slice_coordinates) if ($this_slice_coordinates);

    foreach $this_slice_coordinates (@$all_slices_coordinates) {
# print STDERR "Foreach this_slice_coordinates...\n";
      my $this_slice = $this_slice_adaptor->fetch_by_region(
              $this_slice_coordinates->{coord_system_name},
              $this_slice_coordinates->{seq_region_name},
              $this_slice_coordinates->{start},
              $this_slice_coordinates->{end}
          );

      ## Do not load transcripts immediately or the cache could produce
      ## some troubles in some special cases! Moreover, in this way we will have
      ## the genes, the transcripts and the exons in the same slice!!
      my $these_genes = $this_slice->get_all_Genes($logic_name, $dbtype);
      foreach my $pair (@{$this_slice_coordinates->{pairs}}) {
# print STDERR "Foreach pair ($pair)...\n";
        foreach my $this_gene (@$these_genes) {
# print STDERR "1. GENE: $this_gene->{stable_id} ($this_gene->{start} - $this_gene->{end})\n";
          my $mapped_gene = $self->_get_mapped_Gene($this_gene, $pair, $return_unmapped_exons);
# print STDERR "2. GENE: $mapped_gene->{stable_id} ($mapped_gene->{start} - $mapped_gene->{end})\n";
#           $mapped_gene = $self->_get_mapped_Gene($this_gene, $pair);
          if ($mapped_gene and @{$mapped_gene->get_all_Transcripts}) {
            push(@$all_genes, $mapped_gene);
          }
        }
      }
    }

    $all_genes = $self->_compile_mapped_Genes(
            $all_genes,
            $max_repetition_length,
            $max_gap_length,
            $max_intron_length,
            $strict_order_of_exon_pieces,
            $strict_order_of_exons
        );

    $self->{$key} = $all_genes;
  }

  return $self->{$key};
}


=head2 _get_mapped_Gene

  Arg[1]     : Bio::EnsEMBL::Gene $original_gene
  Arg[2]     : Bio::EnsEMBL::Compara::GenomicAlign $genomic_align
  Example    : my $mapped_gene = $align_slice->get_mapped_Gene($orignal_gene, $genomic_align);
  Description: returns a new Bio::EnsEMBL::Gene object. Mapping is based on exons.
               The object returned contains Bio::EnsEMBL::Transcripts objects. Those
               mapped transcripts contain Bio::EnsEMBL::Compara::AlignSlice::Exon objects.
               If no exon can be mapped, the returned object will contain an empty array of
               transcripts. Since mapped objects are not stored in the DB, they have no dbID
               and no adaptor.
  Returntype : Bio::EnsEMBL::Gene object. (new object)
  Exceptions : returns undef if no part of $original_gene can be mapped using this
               $genomic_align. This method assumes that the slices of all the exons got
               from that gene have the same coordinates as the gene slice. It will throw
               if this is not true.
  Caller     : get_all_Genes

=cut

sub _get_mapped_Gene {
  my ($self, $gene, $pair, $return_unmapped_exons) = @_;

  ## $range_start and $range_end are used to get rid of extra genes fetched because of the
  ## previous speed improvement where several slices are merged in order to access the DB
  ## a minimum number of times. $pair->{slice} correspond to the actual alignment while
  ## $gene->slice might be much larger and include several alignments. $range_start and
  ## $range_end are the coordinates (using $gene->slice as a ref.) where the alignment is.
  ## If the gene (or later on, the exon) falls outside of this range, it can be discarded
  ## as it will be impossible to map it with using $pair->mapper!
  my $range_start = $pair->{slice}->start - $gene->slice->start + 1;
  my $range_end = $pair->{slice}->end - $gene->slice->start + 1;
  return undef if (($gene->start > $range_end) or ($gene->end < $range_start));

  my $from_mapper = $pair->{mapper};
  my $to_mapper = $self->{to_mapper};

  my $these_transcripts = [];

  foreach my $this_transcript (@{$gene->get_all_Transcripts}) {
    my $these_exons = [];
    my $all_exons = $this_transcript->get_all_Exons;
    for (my $i=0; $i<@$all_exons; $i++){
      my $this_exon = $all_exons->[$i];
      throw("Oops, this method assumes that all the exons are defined on the same slice as the".
          " gene they belong to") if ($this_exon->slice->start != $gene->slice->start);
      if ($this_exon->start <= $range_end and $this_exon->end >= $range_start) {
        my $this_align_exon = new Bio::EnsEMBL::Compara::AlignSlice::Exon(
                -EXON => $this_exon,
                -ALIGN_SLICE => $self,
                -FROM_MAPPER => $from_mapper,
                -TO_MAPPER => $to_mapper,
                -ORIGINAL_RANK => $i + 1
            );
        if ($this_align_exon) {
          push(@{$these_exons}, $this_align_exon);
        } elsif ($return_unmapped_exons) {
          $this_align_exon = new Bio::EnsEMBL::Compara::AlignSlice::Exon(
                  -EXON => $this_exon,
                  -ORIGINAL_RANK => $i + 1
              );
          push(@{$these_exons}, $this_align_exon) if ($this_align_exon);
        }
      } elsif ($return_unmapped_exons) {
        my $this_align_exon = new Bio::EnsEMBL::Compara::AlignSlice::Exon(
                -EXON => $this_exon,
                -ORIGINAL_RANK => $i + 1
            );
        push(@{$these_exons}, $this_align_exon) if ($this_align_exon);
      }
    }
    if (grep {defined($_->start)} @$these_exons) { ## if any of the exons has been mapped
      my $new_transcript = $this_transcript->new(
              -dbID => $this_transcript->dbID,
              -adaptor => $this_transcript->adaptor,
              -stable_id => $this_transcript->stable_id,
              -version => $this_transcript->version,
              -external_db => $this_transcript->external_db,
              -external_name => $this_transcript->external_name,
              -external_status => $this_transcript->external_status,
              -display_xref => $this_transcript->display_xref,
              -analysis => $this_transcript->analysis,
              -status => $this_transcript->status,
              -biotype => $this_transcript->biotype,
              -exons => $these_exons,
          );
      if ($this_transcript->translation) {
        $new_transcript->translation($this_transcript->translation);
      }
      push(@{$these_transcripts}, $new_transcript);
    }
  }
  if (!@$these_transcripts) {
    return undef;
  }
  ## Create a new gene object. This is needed in order to avoid
  ## troubles with cache. Attach mapped transcripts.
  my $mapped_gene = $gene->new(
          -ANALYSIS => $gene->analysis,
          -SEQNAME => $gene->seqname,
          -STABLE_ID => $gene->stable_id,
          -VERSION => $gene->version,
          -EXTERNAL_NAME => $gene->external_name,
          -TYPE => $gene->biotype,
          -BIOTYPE => $gene->biotype,
          -STATUS => $gene->status,
          -EXTERNAL_DB => $gene->external_db,
          -EXTERNAL_STATUS => $gene->external_status,
          -DISPLAY_XREF => $gene->display_xref,
          -DESCRIPTION => $gene->description,
          -TRANSCRIPTS => $these_transcripts
      );

  return $mapped_gene;
}


=head2 _compile_mapped_Genes

  Arg[1]     : listref of Bio::EnsEMBL::Gene $mapped_genes
  Arg[2]     : int $max_repetition_length
  Arg[3]     : int $max_gap_length
  Arg[4]     : int $max_intron_length
  Arg[5]     : int $strict_order_of_exon_pieces
  Arg[6]     : int $strict_order_of_exons
  Example    : my $compiled_genes = $align_slice->compile_mapped_Genes($mapped_genes,
                       100, 1000, 100000, 1, 0);
  Description: This method compiles all the pieces of gene mapped before into a list
               of Bio::EnsEMBL::Gene objects. It tries to merge pieces of the same
               exon, link them according to their original transcript and finally
               group the transcripts in Bio::EnsEMBL::Gene objects. Merging and
               linking of Exons is done according to some rules that can be changed
               with the parameters.
  Parameters:  They are sent as is to _separate_in_incompatible_sets_of_Exons() and
               _merge_Exons() methods. Please refer to them elsewhere in this
               document.
  Returntype : listref of Bio::EnsEMBL::Gene objects. (overrides $mapped_genes)
  Exceptions : none
  Caller     : $object->methodname

=cut

sub _compile_mapped_Genes {
  my ($self, $mapped_genes, $max_repetition_length, $max_gap_length, $max_intron_length, 
      $strict_order_of_exon_pieces, $strict_order_of_exons) = @_;

  my $verbose = verbose();
  verbose(0); # Avoid warnings when mapped transcripts are not in the same strand
  
  ## Compile genes: group transcripts by gene->stable_id
  my $gene_by_gene_stable_id;
  my $transcripts_by_gene_stable_id;
  foreach my $mapped_gene (@$mapped_genes) {
# print STDERR "1. GENE:$mapped_gene->{stable_id} ", join(" - ", map {$_->stable_id} @{$mapped_gene->get_all_Transcripts}), "\n";
    if (!$gene_by_gene_stable_id->{$mapped_gene->stable_id}) {
      $gene_by_gene_stable_id->{$mapped_gene->stable_id} = $mapped_gene;
    }
    ## Group all the transcripts by gene stable_id...
    push(@{$transcripts_by_gene_stable_id->{$mapped_gene->stable_id}},
        @{$mapped_gene->get_all_Transcripts});
  }
#   $mapped_genes = [values %$genes_by_stable_id];

  ## Compile transcripts: group exons by transcript->stable_id
  while (my ($gene_stable_id, $set_of_transcripts) = each %$transcripts_by_gene_stable_id) {
    my $transcript_by_transcript_stable_id;
    my $exons_by_transcript_stable_id;
    foreach my $transcript (@{$set_of_transcripts}) {
      if (!$transcript_by_transcript_stable_id->{$transcript->stable_id}) {
        $transcript_by_transcript_stable_id->{$transcript->stable_id} = $transcript;
      }
      ## Group all the exons by the transcript stable_id...
# print STDERR "0. TRANS:$transcript->{stable_id} ", join(" - ", map {$_->stable_id} @{$transcript->get_all_Exons}), "\n";
      push(@{$exons_by_transcript_stable_id->{$transcript->stable_id}},
          @{$transcript->get_all_Exons});
    }

    ## Try to merge splitted exons whenever possible
    while (my ($transcript_stable_id, $set_of_exons) = each %$exons_by_transcript_stable_id) {
# print STDERR "1. ", join(" - ", map {$_->stable_id} @{$set_of_exons}), "\n";
      $exons_by_transcript_stable_id->{$transcript_stable_id} = _merge_Exons(
              $set_of_exons,
              $max_repetition_length,
              $max_gap_length, 
              $strict_order_of_exon_pieces
          );
# print STDERR "2. ", join(" - ", map {$_->stable_id} @{$exons_by_transcript_stable_id->{$transcript_stable_id}}), "\n";
    }
    my $all_transcripts;
    while (my ($transcript_stable_id, $set_of_exons) = each %$exons_by_transcript_stable_id) {
#       my $sets_of_compatible_exons = [$set_of_exons];
      my $sets_of_compatible_exons = _separate_in_incompatible_sets_of_Exons(
              $set_of_exons,
              $max_repetition_length,
              $max_intron_length,
              $strict_order_of_exons
          );

      my $old_transcript = $transcript_by_transcript_stable_id->{$transcript_stable_id};
#       # Save first set of exons in the 
#       my $first_set_of_compatible_exons = shift(@{$sets_of_compatible_exons});
#       my $first_transcript = $transcript_by_transcript_stable_id->{$transcript_stable_id};
#       $first_transcript->flush_Exons();
#       foreach my $exon (@$first_set_of_compatible_exons) {
#         $first_transcript->add_Exon($exon);
#       }
#       push(@$all_transcripts, $first_transcript);

      foreach my $this_set_of_compatible_exons (@{$sets_of_compatible_exons}) {
        my $new_transcript = $old_transcript->new(
                -dbID => $old_transcript->dbID,
                -adaptor => $old_transcript->adaptor,
                -stable_id => $old_transcript->stable_id,
                -version => $old_transcript->version,
                -external_db => $old_transcript->external_db,
                -external_name => $old_transcript->external_name,
                -external_status => $old_transcript->external_status,
                -display_xref => $old_transcript->display_xref,
                -analysis => $old_transcript->analysis,
                -status => $old_transcript->status,
                -biotype => $old_transcript->biotype,
                -EXONS => $this_set_of_compatible_exons
            );
        ## $old_transcript->translation is the original Bio::EnsEMBL::Translation!
        if ($old_transcript->translation) {
          my $start_exon;
          my $seq_start;
          my $end_exon;
          my $seq_end;
          my $all_start_codon_mappings;
          my $all_end_codon_mappings;
          my @sorted_exons;
          if ($new_transcript->strand == 1) {
            @sorted_exons = @{$new_transcript->get_all_Exons};
          } else {
            @sorted_exons = reverse @{$new_transcript->get_all_Exons};
          }
          my $coding = 0;
          foreach my $this_exon (@sorted_exons) {
            if ($old_transcript->translation->start_Exon->stable_id eq $this_exon->stable_id) {
              $coding = 1;
            }
            if ($coding and $this_exon->start) {
              if (!$start_exon) {
                if ($old_transcript->translation->start_Exon->stable_id eq $this_exon->stable_id) {
                  if ($old_transcript->translation->start_Exon->strand == 1) {
                    $all_start_codon_mappings = $self->map_original_Slice(
                        $this_exon->exon->slice->sub_Slice(
                          $old_transcript->coding_region_start,
                          $old_transcript->coding_region_start + 2));
                  } else {
                    $all_start_codon_mappings = $self->map_original_Slice(
                        $this_exon->exon->slice->sub_Slice(
                          $old_transcript->coding_region_end-2,
                          $old_transcript->coding_region_end));
                 }
                  $seq_start = _map_position_using_cigar_line($this_exon->cigar_line,
                      $old_transcript->translation->start, $this_exon->exon->length, 1);
                  if ($seq_start <= $this_exon->length) {
                    $start_exon = $this_exon;
                  }
                } else {
                  $seq_start = 1;
                  $start_exon = $this_exon;
                }
              }
              if ($old_transcript->translation->end_Exon->stable_id eq $this_exon->stable_id) {
                if ($old_transcript->translation->end_Exon->strand == 1) {
                  $all_end_codon_mappings = $self->map_original_Slice(
                      $this_exon->exon->slice->sub_Slice($old_transcript->coding_region_end - 2,$old_transcript->coding_region_end));
                } else {
                  $all_end_codon_mappings = $self->map_original_Slice(
                      $this_exon->exon->slice->sub_Slice(
                       $old_transcript->coding_region_start,
                        $old_transcript->coding_region_start + 2));
                }
                $seq_end = _map_position_using_cigar_line($this_exon->cigar_line,
                    $old_transcript->translation->end, $this_exon->exon->length, 0);
                $seq_end = $this_exon->length if ($seq_end > $this_exon->length);
                if ($seq_end >= 1) {
                  $end_exon = $this_exon;
                } else {
                  ## Set $seq_end to previous value
                  $seq_end = $end_exon->length if ($end_exon);
                }
              } else {
                $end_exon = $this_exon;
                $seq_end = $end_exon->length;
              }
	    }
            if ($old_transcript->translation->end_Exon->stable_id eq $this_exon->stable_id) {
              $coding = 0;
              last;
            }
          }
          if ($start_exon and $end_exon) {
            $new_transcript->translation(new Bio::EnsEMBL::Compara::AlignSlice::Translation(
                    -start_exon => $start_exon,
                    -end_exon => $end_exon,
                    -seq_start => $seq_start,
                    -seq_end => $seq_end,
                    -stable_id => $old_transcript->translation->stable_id,
                    -version => $old_transcript->translation->version,
                    -created_date => ($old_transcript->translation->created_date or undef),
                    -modified_date =>$old_transcript->translation->modified_date,
                ));
          } else {
            ## Translation cannot be mapped. In this case we should return a translation outside
            ## of the coordinate system (negative coding_region_start and coding_region_end).
            $new_transcript->translation(new Bio::EnsEMBL::Compara::AlignSlice::Translation(
                    -stable_id => $old_transcript->translation->stable_id,
                    -version => $old_transcript->translation->version,
                    -created_date => ($old_transcript->translation->created_date or undef),
                    -modified_date =>$old_transcript->translation->modified_date,
                ));
            $new_transcript->coding_region_start(-10000000000);
            $new_transcript->coding_region_end(-10000000000);
          }

          $new_transcript->translation->all_start_codon_mappings($all_start_codon_mappings);
          $new_transcript->translation->all_end_codon_mappings($all_end_codon_mappings);
        }
        push(@$all_transcripts, $new_transcript);
      }
    }

    $gene_by_gene_stable_id->{$gene_stable_id}->{'_transcript_array'} = $all_transcripts;
    # adjust start, end, strand and slice
    $gene_by_gene_stable_id->{$gene_stable_id}->recalculate_coordinates;
  }
  verbose($verbose);

  return [values %$gene_by_gene_stable_id];
}


=head2 _map_position_using_cigar_line

  Arg[1]     : string $cigar_line
  Arg[2]     : int $original_position
  Arg[3]     : int $original_length
  Arg[4]     : bool $start
  Example    : my $mapped_start_position = _map_position_using_cigar_line(
                   "16M4I", 10, 20, 1);
  Example    : my $mapped_end_position = _map_position_using_cigar_line(
                   "16M4I", 10, 20, 1);
  Description: This method is used to locate the start or the end position of
               a Translation on the Bio::EnsEMBL::Compara::AlignSlice::Exon object
               using the cigar_line of the object. As the Bio::EnsEMBL::Compara::
               AlignSlice::Exon object may result from the fusion of the same
               Bio::EnsEMBL::Exon object several times, this method returns the
               best mapping among all the available possibilities. When the original
               position maps on an insertion in the Bio::EnsEMBL::Compara::
               AlignSlice::Exon object, the resulting mapped start position is the
               next one to the latest mapped one.
  Returntype : int $mapped_position
  Exceptions : returns 0 when the end position cannot be mapped.
  Exceptions : returns a number larger than the length of the Bio::EnsEMBL::Compara::
               AlignSlice::Exon when the start position cannot be mapped.

=cut

sub _map_position_using_cigar_line {
  my ($cigar_line, $original_pos, $original_length, $start) = @_;
  my $mapped_pos = 0;


  my @cigar = grep {$_} split(/(\d*[GIDM])/, $cigar_line);
  my $original_count = 0;
  my $mapped_count = 0;
  my $pending_count = 0;

  foreach my $cigar_piece (@cigar) {
    my ($num, $mode) = $cigar_piece =~ /(\d*)([GIDM])/;
    $num = 1 if ($num eq "");
    if ($mode eq "D" or $mode eq "G") {
      $pending_count += $num;
    } elsif ($mode eq "I") {
      $original_count += $num;
    } elsif ($mode eq "M") {
      if ($pending_count) {
        $mapped_count += $pending_count;
        $pending_count = 0;
      }
      if ($original_count + $num < $original_pos) {
        $original_count += $num;
        $mapped_count += $num;
      } else {
        $mapped_count += ($original_pos - $original_count);
        $original_count += ($original_pos - $original_count);
        $mapped_pos = $mapped_count;
        last;
      }
    }
    if ($original_count >= $original_pos and $mode eq "I") {
      ## This position matches in an insertion.
      ## If we are mapping the end position we will prefer the first match in an insertion
      ## rather than the following ones (except if the following matches in a "M" region).
      ## On the other hand, if we are mapping the start position, we will prefer the last
      ## match in an insertion
      if ($start or !$mapped_pos) {
        if ($start and $pending_count) {
          ## $pending_count corresponds to deletion and needs to be added when mapping the
          ## start position (we will want the position AFTER the deletion) but not when
          ## mapping the end position (we will want the position BEFORE the deletion)
          $mapped_count += $pending_count;
          $pending_count = 0;
        }
        $mapped_pos = $mapped_count;
        ## When matching the start position, add 1 as the mapped start will be just after
        ## this position. If this position appears after the end of the mapped exon, this
        ## means we fail to map the start position
        $mapped_pos ++ if ($start);
      }
      ## Try to look further. A second match may happen if this exon is the result of a fusion process
      $original_pos += $original_length;
    }
  }

  return $mapped_pos;
}


=head2 _merge_Exons

  Arg[1]     : listref of Bio::EnsEMBL::Compara::AlignSlice::Exon $set_of_exons
  Arg[2]     : int $max_repetition_length
  Arg[3]     : int $max_gap_length
  Arg[4]     : int $strict_order_of_exon_pieces
  Example    : my $merged_exons = _merge_Exons($exons_to_be_merged, 100, 1000, 1);
  Description: Takes a list of Bio::EnsEMBL::Compara::AlignSlice::Exon objects and
               tries to merge them according to exon stable_id and some rules that can
               be tunned using some optional parameters. This method can overwrite some
               of the exon in the $set_of_exons.
  Parameters:  MAX_REPETITION_LENGTH. In principle you want to merge together pieces
                   of an exon which do not overlap (the beginning and the end of the
                   exon). With this flag you can to set up what amount of the original
                   exon is allowed on two aligned exons to be merged.
               MAX_GAP_LENGTH. If the distance between two pieces of exons in the
                   aligned slice is larger than this parameter, they will not be
                   merged. Setting this parameter to -1 will
                   avoid any merging event.
               STRICT_ORDER_OF_EXON_PIECES. This flag allows you to decide whether two
                   pieces of an exon should be merged or not if they are not in the
                   right order, for instance if the end of the original exon will
                   appear before the start on the merged exon.
  Returntype : lisref of Bio::EnsEMBL::Compara::AlignSlice::Exon objects.
  Exceptions : none
  Caller     : methodname

=cut

sub _merge_Exons {
  my ($set_of_exons, $max_repetition_length, $max_gap_length, $strict_order_of_exon_pieces) = @_;
  my $merged_exons = []; # returned value

  my $exon_by_stable_id;
  # Group exons by stable_id
  foreach my $exon (@$set_of_exons) {
    push(@{$exon_by_stable_id->{$exon->stable_id}}, $exon);
  }
      
  # Merge compatible pieces of exons
  foreach my $these_exons (values %$exon_by_stable_id) {

    if (!grep {defined($_->start)} @$these_exons) {
      push(@$merged_exons, $these_exons->[0]);
      next;
    }

    # Sort exons according to 
    $these_exons= [sort {($a->start or 0) <=> ($b->start or 0)} @$these_exons];
  
    while (my $first_exon = shift @$these_exons) {
      if (!defined($first_exon->start)) {
#         push(@$merged_exons, $first_exon);
        next;
      }
      for (my $count=0; $count<@$these_exons; $count++) {
        my $second_exon = $these_exons->[$count];
        # Check strands
        next if ($first_exon->strand != $second_exon->strand);

        my $gap_between_pieces_of_exon = $second_exon->start - $first_exon->end - 1;
        # Check whether both mapped parts do not overlap
        next if ($gap_between_pieces_of_exon < 0);

        # Check maximum gap between both pieces of exon
        next if ($max_gap_length and $gap_between_pieces_of_exon > $max_gap_length);

        # Check whether both mapped parts are in the right order
        if ($strict_order_of_exon_pieces) {
          if ($first_exon->strand == 1) {
            next if ($first_exon->get_aligned_start > $second_exon->get_aligned_start);
          } else {
            next if ($first_exon->get_aligned_end < $second_exon->get_aligned_end);
          }
        }

        # Check maximum overlapping within original exon, i.e. how much of the
        # same exon can be mapped twice
        my $repetition_length;
        if ($first_exon->strand == 1) {
          $repetition_length = $first_exon->get_aligned_end - $second_exon->get_aligned_start + 1;
        } else {
          $repetition_length = $second_exon->get_aligned_end - $first_exon->get_aligned_start + 1;
        }
        next if ($repetition_length > $max_repetition_length);

        ## Merge exons!!
        $second_exon = splice(@$these_exons, $count, 1); # remove exon from the list
        $count-- if (@$these_exons);
        $first_exon->end($second_exon->end);
        if ($first_exon->strand == 1) {
          $first_exon->append_Exon($second_exon, $gap_between_pieces_of_exon);
        } else {
          $first_exon->prepend_Exon($second_exon, $gap_between_pieces_of_exon);
        }
      }
      push(@$merged_exons, $first_exon);
    }
  }

  return $merged_exons;
}


=head2 _separate_in_incompatible_sets_of_Exons

  Arg[1]     : listref of Bio::EnsEMBL::Compara::AlignSlice::Exon $set_of_exons
  Arg[2]     : int $max_repetition_length
  Arg[3]     : int $max_intron_length
  Arg[4]     : int $strict_order_of_exons
  Example    : my $sets_of_exons = _separate_in_incompatible_sets_of_Exons(
                   $set_of_exons, 100, 100000, 0);
  Description: Takes a list of Bio::EnsEMBL::Compara::AlignSlice::Exon and separate
               them in sets of comaptible exons. Compatibility is defined taking into
               account 5 parameters:
                 - exons must be in the same strand
                 - exons cannot overlap on the align_slice
                 - distance between exons cannot be larger than MAX_INTRON_LENGTH
                 - two exons with the same stable_id can belong to the same transcript
                   only if they represent diferent parts of the original exon. Some
                   overlapping is allowed (see MAX_REPETITION_LENGTH parameter).
                 - exons must be in the same order as in the original transcript
                   if the STRICT_ORDER_OF_EXONS parameter is true.
  Parameters:  MAX_REPETITION_LENGTH. In principle you want to link together pieces
                   of an exon which do not overlap (the beginning and the end of the
                   exon). With this flag you can to set up what amount of the original
                   exon is allowed on two aligned exons to be linked.
               MAX_INTRON_LENGTH. If the distance between two exons in the aligned slice
                   is larger than this parameter, they will not be linked.
               STRICT_ORDER_OF_EXONS. This flag allows you to decide whether two
                   exons should be linked or not if they are not in the
                   original order.
  Returntype : listref of lisrefs of Bio::EnsEMBL::Compara::AlignSlice::Exon objects.
  Exceptions : none
  Caller     : methodname

=cut

sub _separate_in_incompatible_sets_of_Exons {
  my ($set_of_exons, $max_repetition_length, $max_intron_length, $strict_order_of_exons) = @_;
  my $sets_of_exons = [];

  my $last_exon;
  my $this_set_of_exons = [];

  ###################################################################
  ##
  ##  Return all the exons by strand.
  ##   - A given exon can be mapped partially on both strands!
  ##
  if (grep {$_->strand and $_->strand == 1} @$set_of_exons and grep {$_->strand and $_->strand == -1} @$set_of_exons) {
    ## Keep track of the exons that have been mapped by strand
    my $indexes;
    foreach my $exon (@$set_of_exons) {
      if ($exon->strand) {
        $indexes->{$exon->strand}->{$exon->original_rank} = 1;
      }
    }

    my $forward_stranded_set_of_exons; # set of exons to be returned in the forward strand
    my $reverse_stranded_set_of_exons; # set of exons to be returned in the reverse strand
    foreach my $exon (@$set_of_exons) {
      my $new_exon = $exon->copy();
      if ($exon->strand) {
        if ($exon->strand == 1) {
          if ($indexes->{"-1"}->{$exon->original_rank}) {
            ## This exon has been mapped on the reverse strand as well
            push(@$forward_stranded_set_of_exons, $exon);
            next;
          } else {
            ## Undef coordinates of the new exon before adding it to the set
            ## of reverse stranded exons
            $new_exon->start(undef);
            $new_exon->end(undef);
            $new_exon->strand(undef);
          }
        } else {
          if ($indexes->{"1"}->{$exon->original_rank}) {
            ## This exon has been mapped on the forward strand as well
            push(@$reverse_stranded_set_of_exons, $new_exon);
            next;
          } else {
            ## Undef coordinates of the new exon before adding it to the set
            ## of forward stranded exons
            $exon->start(undef);
            $exon->end(undef);
            $exon->strand(undef);
          }
        }
      }
      push(@$forward_stranded_set_of_exons, $exon);
      push(@$reverse_stranded_set_of_exons, $new_exon);
    }
    push(@$sets_of_exons, @{_separate_in_incompatible_sets_of_Exons($reverse_stranded_set_of_exons,
        $max_repetition_length, $max_intron_length, $strict_order_of_exons)});
    $set_of_exons = $forward_stranded_set_of_exons;
  }
  ##
  ###################################################################

  my $transcript_strand = 1;
  if (grep {$_->strand and $_->strand == -1} @$set_of_exons) {
    $transcript_strand = -1;
  }
  foreach my $this_exon (_sort_Exons(@$set_of_exons)) {
    if (!defined($this_exon->start)) {
      if ($transcript_strand == -1) {
        ## Insert this exon in the right place
        my $inserted = 0;
        for (my $i=0; $i<@$this_set_of_exons; $i++) {
          if ($this_set_of_exons->[$i]->original_rank == $this_exon->original_rank - 1) {
            splice(@$this_set_of_exons, $i, 0, $this_exon);
            $inserted = 1;
            last;
          }
        }
        if (!$inserted) {
          push(@$this_set_of_exons, $this_exon);
        }
      } else {
        ## Append this exon
        push(@$this_set_of_exons, $this_exon);
      }
      next;
    }
    if ($last_exon) {
      # Calculate intron length
      my $intron_length = $this_exon->start - $last_exon->end - 1;
      # Calculate whether both mapped parts are in the right order
      my $order_is_ok = 1;
      if ($strict_order_of_exons) {
        if ($this_exon->strand == $this_exon->exon->strand) {
          $order_is_ok = 0 if ($this_exon->exon->start < $last_exon->exon->start);
        } else {
          $order_is_ok = 0 if ($this_exon->exon->start > $last_exon->exon->start);
        }
      }
      my $repetition_length = 0;
      if ($last_exon->stable_id eq $this_exon->stable_id) {
        if ($this_exon->strand == 1) {
          $repetition_length = $last_exon->get_aligned_end - $this_exon->get_aligned_start + 1;
        } else {
          $repetition_length = $this_exon->get_aligned_end - $last_exon->get_aligned_start + 1;
        }
      }

      if (($last_exon->strand != $this_exon->strand) or
          ($intron_length < 0) or
          ($max_intron_length and ($intron_length > $max_intron_length)) or
          (!$order_is_ok) or
          ($repetition_length > $max_repetition_length)) {
        # this_exon and last_exon should be in separate sets. Save current
        # set_of_exons and start a new set_of_exons
        push(@$sets_of_exons, $this_set_of_exons);
        $this_set_of_exons = [];
      }
    }
    push(@$this_set_of_exons, $this_exon);
    $last_exon = $this_exon;
  }
  push(@$sets_of_exons, $this_set_of_exons);

  return $sets_of_exons;
}

sub _sort_Exons {
  my @exons = @_;
  my @sorted_exons = ();

  my $transcript_strand = 1;
  if (grep {$_->strand and $_->strand == -1} @exons) {
    $transcript_strand = -1;
  }

  my @mapped_exons = grep {defined($_->start)} @exons;
  my @unmapped_exons = grep {!defined($_->start)} @exons;

  @mapped_exons = sort {$a->start <=> $b->start} @mapped_exons;
  my $sorted_exons_by_rank;
  foreach my $mapped_exon (@mapped_exons) {
    my $rank = $mapped_exon->original_rank;
    # the same exon can be mapped twice!
    push(@{$sorted_exons_by_rank->{$rank}}, $mapped_exon);
  }

  @unmapped_exons = sort {$a->original_rank <=> $b->original_rank} @unmapped_exons;
  foreach my $unmapped_exon (@unmapped_exons) {
    my $rank = $unmapped_exon->original_rank;
    do {
      if (defined($sorted_exons_by_rank->{$rank})) {
        push(@{$sorted_exons_by_rank->{$rank}}, $unmapped_exon);
        $rank = 0;
      } elsif ($rank == 1) {
        if ($transcript_strand == 1) {
          push(@{$sorted_exons_by_rank->{$rank}}, $unmapped_exon);
        } else {
          $rank++ while(!defined($sorted_exons_by_rank->{$rank}));
          splice(@{$sorted_exons_by_rank->{$rank}}, 1, 0, $unmapped_exon);
        }
        $rank = 0;
      }
      $rank--;
    } while ($rank > 0);
  }

  foreach my $exons (sort {
            if (defined($a->[0]->start) and defined($b->[0]->start)) {
              $a->[0]->start <=> $b->[0]->start;
            } else {
              $a->[0]->original_rank <=> $b->[0]->original_rank;
            }
        } values %$sorted_exons_by_rank) {
    push(@sorted_exons, @{$exons});
  }

  return @sorted_exons;
}

=head2 OVERWRITEN METHODS FROM Bio::EnsEMBL::Slice module

=head2 WARNING - WARNING - WARNING - WARNING - WARNING - WARNING - WARNING

 All the methods that need acces to the database (the adaptor) and which
 are not listed here are not supported!!

=head2 WARNING - WARNING - WARNING - WARNING - WARNING - WARNING - WARNING

=head2 invert (not supported)

Maybe at some point...

This method returns undef

=cut

sub invert {
  warning("Cannot invert a Bio::EnsEMBL::Compara::AlignSlice::Slice object"); 
  return undef;
}


=head2 sub_Slice

  Arg   1    : int $start
  Arg   2    : int $end
  Arge [3]   : int $strand
  Example    : none
  Description: Makes another Slice that covers only part of this slice
               If a slice is requested which lies outside of the boundaries
               of this function will return undef.  This means that
               behaviour will be consistant whether or not the slice is
               attached to the database (i.e. if there is attached sequence
               to the slice).  Alternatively the expand() method or the
               SliceAdaptor::fetch_by_region method can be used instead.
  Returntype : Bio::EnsEMBL::Slice or undef if arguments are wrong
  Exceptions : return undef if $start and $end define a region outside
               of actual Slice.
  Caller     : general
  Status     : Testing

=cut

sub sub_Slice {
  my ( $self, $start, $end, $strand ) = @_;

  if( $start < 1 || $start > $self->{'end'} ) {
    # throw( "start argument not valid" );
    return undef;
  }

  if( $end < $start || $end > $self->{'end'} ) {
    # throw( "end argument not valid" )
    return undef;
  }

  my ($new_start, $new_end, $new_strand);
  if (!defined($strand)) {
    $strand = 1;
  }

  if( $self->{'strand'} == 1 ) {
    $new_start = $self->{'start'} + $start - 1;
    $new_end = $self->{'start'} + $end - 1;
    $new_strand = $strand;
  } else {
    $new_start = $self->{'end'} - $end + 1;;
    $new_end = $self->{'end'} - $start + 1;
    $new_strand = -$strand;
  }

  #fastest way to copy a slice is to do a shallow hash copy
  my %new_slice = %$self;

  ## Delete cached genes
  foreach my $key (grep {/^key_/} keys %new_slice) {
    delete($new_slice{$key});
  }
  $new_slice{'seq'} = undef;
  $new_slice{'start'} = int($new_start);
  $new_slice{'end'}   = int($new_end);
  $new_slice{'strand'} = $new_strand;

  return bless \%new_slice, ref($self);
}

=head2 seq

  Arg [1]    : none
  Example    : print "SEQUENCE = ", $slice->seq();
  Description: Returns the sequence of the region represented by this
               slice formatted as a string.
               This Slice is made of several Bio::EnsEMBL::Slices mapped
               on it with gaps inside and regions with no matching
               sequence. The resulting string might contain gaps and/or
               dots as padding characters. If several Slices map on the
               same positions, the last one will override the positions.
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub seq {
  my $self = shift;
  my $start = 1;
  my $end = $self->length;
  my $strand = 1; # strand is reversed in the subseq method if needed

  return $self->{seq} if (defined($self->{seq}));

  $self->{seq} = $self->subseq($start, $end, $strand);
  
  return $self->{seq};
}


=head2 subseq

  Arg  [1]   : int $startBasePair
               relative to start of slice, which is 1.
  Arg  [2]   : int $endBasePair
               relative to start of slice.
  Arg  [3]   : (optional) int $strand
               The strand of the slice to obtain sequence from. Default
               value is 1.
  Description: returns string of dna sequence
               This Slice is made of several Bio::EnsEMBL::Slices mapped
               on it with gaps inside and regions with no matching
               sequence. The resulting string might contain gaps and/or
               dots as padding characters. If several Slices map on the
               same positions, the last one will override the positions.
  Returntype : txt
  Exceptions : end should be at least as big as start
               strand must be set
  Caller     : general

=cut

sub subseq {
  my ($self, $start, $end, $strand) = @_;

  $start = 1 if (!defined($start));
  $end ||= $self->length;
  $strand ||= 1;

  ## Fix coordinates (needed for sub_Slices)
  if ($self->strand == -1) {
    $strand = -$strand;
    my $aux = $start;
    $start = $self->start + ($self->length - $end);
    $end = $self->start + ($self->length - $aux);
  } else {
    $start += $self->start - 1;
    $end += $self->start - 1;
  }

  my $length = ($end - $start + 1);
  my $seq = "." x $length;

  foreach my $pair (sort {$a->{start} <=> $b->{start}} @{$self->get_all_Slice_Mapper_pairs()}) {
    my $this_slice = $pair->{slice};
    my $mapper = $pair->{mapper};
    my $slice_start = $pair->{start};
    my $slice_end = $pair->{end};
    next if ($slice_start > $end or $slice_end < $start);
    my $this_slice_seq = $this_slice->seq();

    # Set slice_start and slice_end in "subseq" coordinates (0 based, for compliance wiht substr() perl func) and trim them
    $slice_start -= $start; # $slice_start is now in subseq coordinates
    $slice_start = 0 if ($slice_start < 0);
    $slice_end -= $start; # $slice_end is now in subseq coordinates
    $slice_end = $length if ($slice_end > $length);

    # Invert start and end for the reverse strand
    if ($strand == -1) {
      my $aux = $slice_end;
      $slice_end = $length - $slice_start;
      $slice_start = $length - $aux;
    }

    my @sequence_coords = $mapper->map_coordinates(
            'alignment',
            $start,
            $end,
            $strand,
            'alignment'
        );

    #####################
    # $this_pos refers to the starting position of the subseq if requesting the forward strand
    # or the ending position of the subseq if the reverse strand has been requested:
    #
    # FORWARD STRAND (1)
    # $this_pos = 0
    #      |
    #      ---------------------------------------------------------------------->
    #      <----------------------------------------------------------------------
    #
    # REVERSE STRAND (-1)
    #      ---------------------------------------------------------------------->
    #      <----------------------------------------------------------------------
    #                                                                            |
    #                                                                      $this_pos = 0
    #
    # All remaining coordinates work in the same way except the start and end position
    # of the gaps which correspond to the coordinates in the original Slice...
    #
    my $this_pos = 0;
    foreach my $sequence_coord (@sequence_coords) {
      ## $sequence_coord refer to genomic_align (a slice in the [+] strand)

      if ($sequence_coord->isa("Bio::EnsEMBL::Mapper::Coordinate")) {
        my $subseq;
        if ($this_slice->strand == 1) {
          $subseq = substr($this_slice_seq,
              $sequence_coord->start - $this_slice->start,
              $sequence_coord->length);
          if ($sequence_coord->strand * $pair->{strand} == -1) {
            $subseq = reverse($subseq);
            $subseq =~ tr/ACGTacgt/TGCAtgca/;
          }
        } else {
          $subseq = substr($this_slice_seq,
              $this_slice->end - $sequence_coord->end,
              $sequence_coord->length);
          if ($sequence_coord->strand * $pair->{strand} == -1) {
            $subseq = reverse($subseq);
            $subseq =~ tr/ACGTacgt/TGCAtgca/;
          }
        }
        substr($seq, $this_pos, $sequence_coord->length, $subseq);

      } else {  ## Gap or sequence outside of any alignment
        ############
        # Get the start and end positions of this gap in "subseq" coordinates
        my $this_original_start = $sequence_coord->start - $start;
        my $this_original_end = $sequence_coord->end - $start;
        if ($strand == -1) {
          my $aux = $this_original_end;
          $this_original_end = $length - $this_original_start;
          $this_original_start = $length - $aux;
        }
        if ($this_original_start <= $slice_end and $this_original_end >= $slice_start) {
          ## This is a gap
          my $start_position_of_gap_seq = $this_pos;
          my $end_position_of_gap_seq = $this_pos + $sequence_coord->length;
          if ($start_position_of_gap_seq < $slice_start) {
            $start_position_of_gap_seq = $slice_start;
          }
          if ($end_position_of_gap_seq > $slice_end + 1) {
            $end_position_of_gap_seq = $slice_end + 1;
          }
          my $length_of_gap_seq = $end_position_of_gap_seq - $start_position_of_gap_seq;
          substr($seq, $start_position_of_gap_seq, $length_of_gap_seq, "-" x $length_of_gap_seq)
              if ($length_of_gap_seq > 0);
        }
      }
      $this_pos += $sequence_coord->length;
    }
  }
  return $seq;
}


=head2 get_cigar_line

  Arg        : -none-
  Description: returns a cigar_line describing the gaps in the mapped sequence
               This Slice is made of several Bio::EnsEMBL::Slices mapped
               on it with gaps inside and regions with no matching
               sequence. The resulting cigar line corresponds to the mapping
               of all the nucleotides that can be mapepd. If several Slices map
               on the same positions, the behaviour is undefined.
               The cigar_line includes 3 types of regions: M for matches/mismatches,
               D for alignment gaps (formerly known as deletions) and G for
               gaps between alignment blocks.
  Returntype : txt
  Exceptions :
  Caller     : general

=cut

sub get_cigar_line {
  my ($self, $start, $end, $strand) = @_;

  $start = $self->start;
  $end = $self->end;
  $strand ||= 1;

  ## Fix coordinates (needed for sub_Slices)
  if ($self->strand == -1) {
    $strand = -$strand;
    my $aux = $start;
    $start = $self->start + ($self->length - $end);
    $end = $self->start + ($self->length - $aux);
  } else {
    $start += $self->start - 1;
    $end += $self->start - 1;
  }

  my $length = ($end - $start + 1);
  my $seq = "." x $length;
  foreach my $pair (sort {$a->{start} <=> $b->{start}} @{$self->get_all_Slice_Mapper_pairs("get_gap_slices")}) {
    my $this_slice = $pair->{slice};
    my $mapper = $pair->{mapper};
    my $slice_start = $pair->{start};
    my $slice_end = $pair->{end};
    next if ($slice_start > $end or $slice_end < $start);

    # Set slice_start and slice_end in "subseq" coordinates (0 based, for compliance wiht substr() perl func) and trim them
    $slice_start -= $start; # $slice_start is now in subseq coordinates
    $slice_start = 0 if ($slice_start < 0);
    $slice_end -= $start; # $slice_end is now in subseq coordinates
    $slice_end = $length if ($slice_end > $length);

    # Invert start and end for the reverse strand
    if ($strand == -1) {
      my $aux = $slice_end;
      $slice_end = $length - $slice_start;
      $slice_start = $length - $aux;
    }

    my @sequence_coords = $mapper->map_coordinates(
            'alignment',
            $start,
            $end,
            $strand,
            'alignment'
        );
    #####################
    # $this_pos refers to the starting position of the subseq if requesting the forward strand
    # or the ending position of the subseq if the reverse strand has been requested:
    #
    # FORWARD STRAND (1)
    # $this_pos = 0
    #      |
    #      ---------------------------------------------------------------------->
    #      <----------------------------------------------------------------------
    #
    # REVERSE STRAND (-1)
    #      ---------------------------------------------------------------------->
    #      <----------------------------------------------------------------------
    #                                                                            |
    #                                                                      $this_pos = 0
    #
    # All remaining coordinates work in the same way except the start and end position
    # of the gaps which correspond to the coordinates in the original Slice...
    #
    my $this_pos = 0;
    foreach my $sequence_coord (@sequence_coords) {
      ## $sequence_coord refer to genomic_align (a slice in the [+] strand)

      if ($sequence_coord->isa("Bio::EnsEMBL::Mapper::Coordinate")) {
        my $subseq = "N" x ($sequence_coord->length);
        substr($seq, $this_pos, $sequence_coord->length, $subseq);

      } else {  ## Gap or sequence outside of any alignment
        ############
        # Get the start and end positions of this gap in "subseq" coordinates
        my $this_original_start = $sequence_coord->start - $start;
        my $this_original_end = $sequence_coord->end - $start;
        if ($strand == -1) {
          my $aux = $this_original_end;
          $this_original_end = $length - $this_original_start;
          $this_original_start = $length - $aux;
        }
        if ($this_original_start <= $slice_end and $this_original_end >= $slice_start) {
          ## This is a gap
          my $start_position_of_gap_seq = $this_pos;
          my $end_position_of_gap_seq = $this_pos + $sequence_coord->length;
          if ($start_position_of_gap_seq < $slice_start) {
            $start_position_of_gap_seq = $slice_start;
          }
          if ($end_position_of_gap_seq > $slice_end + 1) {
            $end_position_of_gap_seq = $slice_end + 1;
          }
          my $length_of_gap_seq = $end_position_of_gap_seq - $start_position_of_gap_seq;
          substr($seq, $start_position_of_gap_seq, $length_of_gap_seq, "-" x $length_of_gap_seq)
              if ($length_of_gap_seq > 0);
        }
      }
      $this_pos += $sequence_coord->length;
    }
  }
  my $cigar_line = "";

  my @pieces = split(/(\-+|\.+)/, $seq);
  foreach my $piece (@pieces) {
    my $mode;
    if ($piece =~ /\./) {
      $mode = "G"; # D for gaps (deletions)
    } elsif ($piece =~ /\-/) {
      $mode = "D"; # D for gaps (deletions)
    } else {
      $mode = "M"; # M for matches/mismatches
    }
    if (length($piece) == 1) {
      $cigar_line .= $mode;
    } elsif (length($piece) > 1) { #length can be 0 if the sequence starts with a gap
      $cigar_line .= length($piece).$mode;
    }
  }

  return $cigar_line;
}


=head2 get_all_underlying_Slices

  Arg  [1]   : int $startBasePair
               relative to start of slice, which is 1.
  Arg  [2]   : int $endBasePair
               relative to start of slice.
  Arg  [3]   : (optional) int $strand
               The strand of the slice to obtain sequence from. Default
               value is 1.
  Description: This Slice is made of several Bio::EnsEMBL::Slices mapped
               on it with gaps inside and regions with no matching
               sequence. This method returns these Slices (or part of
               them) with the original coordinates and the gapped
               sequence attached to them. Additionally, extra Slices
               could be returned in order to fill in gaps between
               underlying Slices.
  Returntype : listref of Bio::EnsEMBL::Slice objects
  Exceptions : end should be at least as big as start
  Caller     : general

=cut

sub get_all_underlying_Slices {
  my ($self, $start, $end, $strand) = @_;
  my $underlying_slices = [];

  $start = 1 if (!defined($start));
  $end ||= $self->length;
  $strand ||= 1;

  ## Fix coordinates (needed for sub_Slices)
  if ($self->strand == -1) {
    $strand = -$strand;
    my $aux = $start;
    $start = $self->start + ($self->length - $end);
    $end = $self->start + ($self->length - $aux);
  } else {
    $start += $self->start - 1;
    $end += $self->start - 1;
  }

  my $current_position;
#   if ($strand == 1) {
    $current_position = $start;
#   } else {
#     $current_position = $end;
#   }
  foreach my $pair (sort {$a->{start} <=> $b->{start}} @{$self->get_all_Slice_Mapper_pairs}) {
    my $this_slice = $pair->{slice};
    my $mapper = $pair->{mapper};
    my $slice_start = $pair->{start};
    my $slice_end = $pair->{end};
    next if ($slice_start > $end or $slice_end < $start);

    my @sequence_coords = $mapper->map_coordinates(
            'alignment',
            $start,
            $end,
            $strand,
            'alignment'
        );
    my $this_subseq_start;
    my $this_subseq_end;
    my $this_subseq_strand;
    foreach my $sequence_coord (@sequence_coords) {
      ## $sequence_coord refer to genomic_align (a slice in the [+] strand)
      if ($sequence_coord->isa("Bio::EnsEMBL::Mapper::Coordinate")) {
        $this_subseq_start = $sequence_coord->start
            if (!defined($this_subseq_start) or $this_subseq_start > $sequence_coord->start);
        $this_subseq_end = $sequence_coord->end
            if (!defined($this_subseq_end) or $this_subseq_end < $sequence_coord->end);
        $this_subseq_strand = $sequence_coord->strand
            if ($sequence_coord->isa("Bio::EnsEMBL::Mapper::Coordinate") and !defined($this_subseq_strand));
      }
    }
#     next if (!defined($this_subseq_start)); # if the whole requested region correspond to a gap
    my $start_position = ($start>$slice_start)?$start:$slice_start; # in AlignSlice coordinates
    my $end_position = ($end<$slice_end)?$end:$slice_end; # in AlignSlice coordinates
#     if ($strand == 1) {
      if ($start_position > $current_position) {
        my $this_underlying_slice = new Bio::EnsEMBL::Slice(
              -coord_system => $gap_coord_system,
              -seq_region_name => "GAP",
              -start => $current_position,
              -end => $start_position - 1,
              -strand => 0
            );
        $this_underlying_slice->{seq} = "." x ($start_position - $current_position);
        push(@$underlying_slices, $this_underlying_slice);
      }
#     } else {
#       if ($end_position < $current_position) {
#         my $this_underlying_slice = new Bio::EnsEMBL::Slice(
#               -seq_region_name => "GAP",
#               -start => $end_position + 1,
#               -end => $current_position,
#               -strand => 0
#             );
#         $this_underlying_slice->{seq} = "." x ($current_position - $end_position);
#         unshift(@$underlying_slices, $this_underlying_slice);
#       }
#     }
    $current_position = $end_position + 1;
    my $this_underlying_slice;
    if (!defined($this_subseq_start)) {
      $this_underlying_slice = new Bio::EnsEMBL::Slice(
              -coord_system => $gap_coord_system,
              -seq_region_name => "GAP",
              -start => $start_position,
              -end => $end_position,
              -strand => 0
          );
      $this_underlying_slice->{seq} = "-" x ($end_position - $start_position + 1);
    } else {
      $this_underlying_slice = new Bio::EnsEMBL::Slice(
              -coord_system => $this_slice->coord_system,
              -seq_region_name => $this_slice->seq_region_name,
              -start => $this_subseq_start,
              -end => $this_subseq_end,
              -strand => $this_subseq_strand
          );
      $this_underlying_slice->{seq} = $self->subseq($start_position, $end_position, $strand);
      $this_underlying_slice->{_tree} = $this_slice->{_tree} if (defined($this_slice->{_tree}));
    }
#     if ($strand == 1) {
      push(@$underlying_slices, $this_underlying_slice);
#     } else {
#       unshift(@$underlying_slices, $this_underlying_slice);
#     }
  }
  if ($end >= $current_position) {
    my $this_underlying_slice = new Bio::EnsEMBL::Slice(
          -coord_system => $gap_coord_system,
          -seq_region_name => "GAP",
          -seq_region_length => ($end - $current_position + 1),
          -start => $current_position,
          -end => $end,
          -strand => 0
        );
    $this_underlying_slice->{seq} = "." x ($end - $current_position + 1);
    push(@$underlying_slices, $this_underlying_slice);
  }
  if ($strand == -1) {
    @$underlying_slices = reverse(@$underlying_slices);
  }

  return $underlying_slices;
}

=head2 get_original_seq_region_position

  Arg  [1]   : int $position
               relative to start of slice, which is 1.
  Description: This Slice is made of several Bio::EnsEMBL::Slices mapped
               on it with gaps inside and regions with no matching
               sequence. This method returns the original seq_region_position
               in the original Slice of the requested position in AlignSlice
               coordinates
  Example    : my ($slice, $seq_region_position) = $as_slice->
                   get_original_seq_region_position(100);
  Returntype : ($slice, $seq_region_position), an array where the first
               element is a Bio::EnsEMBL::Slice and the second one is the
               requested seq_region_position.
  Exceptions : if the position corresponds to a gap, the slice will be a fake GAP
               slice and the position will be the requested one (in AlignSlice
               coordinates)
  Caller     : general

=cut

sub get_original_seq_region_position {
  my ($self, $position) = @_;
  my $underlying_slice = $self->get_all_underlying_Slices($position, $position, 1)->[0];

  return ($underlying_slice, $underlying_slice->start);
}


=head2 get_all_constrained_elements

  Arg  1     : (opt) string $method_link_type (default = GERP_CONSTRAINED_ELEMENT)
  Arg  2     : (opt) listref Bio::EnsEMBL::Compara::GenomeDB $species_set
               (default, the set of species from the MethodLinkSpeciesSet used
               to build this AlignSlice)
  Example    : my $constrained_elements =
                    $align_slice->get_all_constrained_elements();
  Description: Retrieve the corresponding constrained elements for these alignments.
               Objects will be mapped on this AlignSlice::Slice, i.e. the
               reference_slice, reference_slice_start, reference_slice_end
               and reference_slice_strand will refer to this AlignSlice::Slice
               object
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignBlock
               objects.
  Caller     : object::methodname
  Status     : At risk

=cut

sub get_all_constrained_elements {
  my ($self, $method_link_type, $species_set) = @_;
  my $all_constrained_elements = [];

  return [] if (!$self->{_align_slice});
  my $all_original_constrained_elements = $self->{_align_slice}->
      get_all_constrained_elements($method_link_type, $species_set);
  foreach my $this_constrained_element (@$all_original_constrained_elements) {
    foreach my $this_genomic_align (@{$this_constrained_element->get_all_GenomicAligns}) {
      if ($this_genomic_align->genome_db->name eq $self->genome_db->name) {
        my $constrained_slice = $this_genomic_align->get_Slice;
        my $slices = $self->map_original_Slice($constrained_slice);
        $this_constrained_element->reference_slice($self);
        $this_constrained_element->reference_slice_start($slices->[0]->start);
        $this_constrained_element->reference_slice_end($slices->[0]->end);
        $this_constrained_element->reference_slice_strand($slices->[0]->strand);
        push(@$all_constrained_elements, $this_constrained_element);
      }
    }
  }

  return $all_constrained_elements;
}


=head2 map_original_Slice

  Arg  [1]   : Bio::EnsEMBL::Slice $original_slice
  Description: This Slice is made of several Bio::EnsEMBL::Slices mapped
               on it with gaps inside and regions with no matching
               sequence. This method tries to map on this Slice the
               region(s) corresponding to the provided $original_slice
               NB: This method does not know how to project Slices onto
               other coordinate systems. It is your responsability to
               provide an original Slice on the same coordinate system
               as the underlying Bio::EnsEMBL::Slices
  Example    : my $slices = $as_slice->map_original_Slice($orginal_slice);
  Returntype : listref of Bio::EnsEMBL::Compara::AlignSlice::Slice objects
               which are the sub_Slices of this Bio::EnsEMBL::Compara::
               AlignSlice::Slice where the $original_slice maps
  Exceptions :

=cut

sub map_original_Slice {
  my ($self, $original_slice) = @_;
  my $mapped_slices = [];

  return $mapped_slices if (!defined($original_slice));

  foreach my $pair (@{$self->get_all_Slice_Mapper_pairs}) {
    my $this_slice = $pair->{slice};
    my $mapper = $pair->{mapper};
    my $slice_start = $pair->{start};
    my $slice_end = $pair->{end};
    next if (!$this_slice->coord_system->equals($original_slice->coord_system));
    next if ($this_slice->seq_region_name ne $original_slice->seq_region_name);

    next if ($this_slice->start > $original_slice->end or $this_slice->end < $original_slice->start);

    my @sequence_coords = $mapper->map_coordinates(
            'sequence',
            $original_slice->start,
            $original_slice->end,
            $original_slice->strand,
            'sequence'
        );
    my $mapped_start;
    my $mapped_end;
    my $mapped_strand;
    foreach my $sequence_coord (@sequence_coords) {
      if ($sequence_coord->isa("Bio::EnsEMBL::Mapper::Coordinate")) {
        if (!defined($mapped_start) or ($mapped_start > $sequence_coord->start)) {
          $mapped_start = $sequence_coord->start;
        }
        if (!defined($mapped_end) or ($mapped_end < $sequence_coord->end)) {
          $mapped_end = $sequence_coord->end;
        }
        if (!defined($mapped_strand)) {
          $mapped_strand = $sequence_coord->strand;
        } elsif ($mapped_strand != $sequence_coord->strand) {
          warning("strand inversion within a Slice-Mapper pair!");
          $mapped_start = undef;
          $mapped_end = undef;
          $mapped_strand = undef;
          last;
        }
      }
    }
    if (defined($mapped_start) and defined($mapped_end) and defined($mapped_strand)) {
      my $sub_slice = $self->sub_Slice($mapped_start, $mapped_end, $mapped_strand);
      push(@$mapped_slices, $sub_slice) if ($sub_slice);
    }
  }

  return $mapped_slices;
}


=head2 expand (not supported)

Expanding a Bio::EnsEMBL::Compara::AlignSlice::Slice object is not supported at the moment.
You could create a new Bio::EnsEMBL::Slice and fetch a new Bio::EnsEMBL::Compara::AlignSlice
from it. On the hand, if you only want to extend the sequence, you could use the subseq method
with a negatve start value or an end value larger than the end of this Slice.

This method returns undef

=cut

sub expand {
  my $self = shift;
  warning("Cannot expand a Bio::EnsEMBL::Compara::AlignSlice::Slice object"); 
  return undef;
}


=head2 get_all_Attributes

  Arg [1]    : optional string $attrib_code
               The code of the attribute type to retrieve values for.
  Example    : ($htg_phase) = @{$slice->get_all_Attributes('htg_phase')};
               @slice_attributes    = @{$slice->get_all_Attributes()};
  Description: Gets a list of Attributes of all teh underlying slice''s
               seq_region. Optionally just get Attributes for given code.
               This Slice is made of several Bio::EnsEMBL::Slices mapped
               on it. This method go through all of them, retrieves the
               data and return them in order. There will be one set of
               Attributes by underlying slice.
  Returntype : listref Bio::EnsEMBL::Attribute
  Exceptions : warning if slice does not have attached adaptor
  Caller     : general

=cut

sub get_all_Attributes {
  my $self = shift;
  my $attributes = [];

  foreach my $pair (@{$self->get_all_Slice_Mapper_pairs}) {
    my $this_slice = $pair->{slice};
    push(@$attributes, @{$this_slice->get_all_Attributes(@_)});
  }
  return $attributes;
}


=head2 get_all_VariationFeatures

    Args       : none
    Description :returns all variation features on this slice. This function will only work 
                correctly if the variation database has been attached to the core database.
                This Slice is made of several Bio::EnsEMBL::Slices mapped on it. This
                method go through all of them, retrieves the data and maps them on this
                Bio::EnsEMBL::Compara::AlignSlice::Slice object.
    ReturnType : listref of Bio::EnsEMBL::Variation::VariationFeature
    Exceptions : none
    Caller     : contigview, snpview

=cut

sub get_all_VariationFeatures {
  my $self = shift;

  return $self->_method_returning_simple_features("get_all_VariationFeatures", @_)
}


=head2 get_all_genotyped_VariationFeatures

  Args       : none
  Function   : returns all variation features on this slice that have been genotyped. This
               function will only work correctly if the variation database has been
               attached to the core database.
               This Slice is made of several Bio::EnsEMBL::Slices mapped on it. This
               method go through all of them, retrieves the data and maps them on this
               Bio::EnsEMBL::Compara::AlignSlice::Slice object by changing start, end,
               strand and slice attributes.
  ReturnType : listref of Bio::EnsEMBL::Variation::VariationFeature
  Exceptions : none
  Caller     : contigview, snpview

=cut

sub get_all_genotyped_VariationFeatures {
  my $self = shift;

  return $self->_method_returning_simple_features("get_all_genotyped_VariationFeatures", @_)
}


=head2 get_all_RepeatFeatures

  Arg [1]    : (optional) string $logic_name
               The name of the analysis performed on the repeat features
               to obtain.
  Arg [2]    : (optional) string $repeat_type
               Limits features returned to those of the specified repeat_type
  Example    : @repeat_feats = @{$slice->get_all_RepeatFeatures(undef,'LTR')};
  Description: Retrieves the RepeatFeatures which overlap  with
               logic name $logic_name and with score above $score.  If 
               $logic_name is not defined features of all logic names are 
               retrieved.
               This Slice is made of several Bio::EnsEMBL::Slices mapped on it. This
               method go through all of them, retrieves the data and maps them on this
               Bio::EnsEMBL::Compara::AlignSlice::Slice object by changing start, end,
               strand and slice attributes.
  Returntype : listref of Bio::EnsEMBL::RepeatFeatures
  Exceptions : warning if slice does not have attached adaptor
  Caller     : general

=cut

sub get_all_RepeatFeatures {
  my $self = shift;

  return $self->_method_returning_simple_features("get_all_RepeatFeatures", @_)
}


=head2 project (testing)

  Arg [1]    : string $name
               The name of the coordinate system to project this slice onto
  Arg [2]    : string $version
               The version of the coordinate system (such as 'NCBI34') to
               project this slice onto
  Example    :
    my $clone_projection = $slice->project('clone');

    foreach my $seg (@$clone_projection) {
      my $clone = $segment->to_Slice();
      print $slice->seq_region_name(), ':', $seg->from_start(), '-',
            $seg->from_end(), ' -> ',
            $clone->seq_region_name(), ':', $clone->start(), '-',$clone->end(),
            $clone->strand(), "\n";
    }
  Description: This Slice is made of several Bio::EnsEMBL::Slices mapped on it. This
               method go through all of them, porject them and maps the projections
               on this Bio::EnsEMBL::Compara::AlignSlice::Slice object.
               The original 'project' method returns the results of 'projecting'
               a slice onto another coordinate system.  Projecting to a coordinate
               system that the slice is assembled from is analagous to retrieving a tiling
               path. The original method may also be used to 'project up' to a higher
               level coordinate system, however.

               This method returns a listref of triplets [start,end,slice]
               which represents the projection.  The start and end defined the
               region of this slice which is made up of the third value of
               the triplet: a slice in the requested coordinate system.

               Because of the gaps in the mapping of the Bio::EnsEMBL::Slices
               the lenght of the slice returned in the tripet may be different
               than the distance defined by the start and end of the
               Bio::EnsEMBL::ProjectionSegment object.
  Returntype : list reference of Bio::EnsEMBL::ProjectionSegment objects which
               can also be used as [$start,$end,$slice] triplets
  Exceptions : none
  Caller     : general

=cut

sub project {
  my $self = shift;
  my $cs_name = shift;
  my $cs_version = shift;
  my $projections = [];

  throw('Coord_system name argument is required') if(!$cs_name);

  foreach my $pair (@{$self->get_all_Slice_Mapper_pairs}) {
    my $this_slice = $pair->{slice};
    my $this_mapper = $pair->{mapper};
    my $this_projections = $this_slice->project($cs_name, $cs_version);
    foreach my $this_projection (@$this_projections) {
      my ($this_start, $this_end);
      if ($this_slice->strand == 1) {
        $this_start = $this_slice->start + $this_projection->from_start - 1;
        $this_end = $this_slice->start + $this_projection->from_end - 1;
      } else {
        $this_start = $this_slice->start + ($this_slice->length - $this_projection->from_start);
        $this_end = $this_slice->start + ($this_slice->length - $this_projection->from_end);
      }
      my $new_slice = $this_projection->to_Slice;
      my ($new_start, $new_end);
      my @alignment_coords = $this_mapper->map_coordinates(
              'sequence',
              $this_start,
              $this_start,
              1,
              'sequence'
          );
      foreach my $alignment_coord (@alignment_coords) {
        if ($alignment_coord->isa("Bio::EnsEMBL::Mapper::Coordinate")) {
          $new_start = $alignment_coord->start;
        }
      }
      next if (!defined($new_start));
      @alignment_coords = $this_mapper->map_coordinates(
              'sequence',
              $this_end,
              $this_end,
              1,
              'sequence'
          );
      foreach my $alignment_coord (@alignment_coords) {
        if ($alignment_coord->isa("Bio::EnsEMBL::Mapper::Coordinate")) {
          $new_end = $alignment_coord->start;
        }
      }
      next if (!defined($new_end));

      ## Truncate projection in order to fit into this AlignSlice
      if ($new_start > $self->end) {
        next; ## Maps outside of sub_AlignSlice
      } elsif ($new_start < $self->start) {
        if ($new_slice->strand == -1) {
          $new_slice = $new_slice->sub_Slice(1, $new_slice->length - ($self->start - $new_start));
        } else {
          $new_slice = $new_slice->sub_Slice($self->start - $new_start + 1, $new_slice->length);
        }
        $new_start = 1;
        $new_end = $new_slice->length;
      }

      ## Truncate projection in order to fit into this AlignSlice
      if ($new_end < $self->start) {
        next; ## Maps outside of sub_AlignSlice
      } elsif ($new_end > $self->length) {
        # We have to truncate this projection
        if ($new_slice->strand == -1) {
          $new_slice = $new_slice->sub_Slice(1 + $new_end - $self->length, $new_slice->length);
        } else {
          $new_slice = $new_slice->sub_Slice(1, $new_slice->length - ($new_end - $self->length));
        }
        $new_end = $self->length;
      }

      my $new_projection = bless([$new_start, $new_end, $new_slice],
                                "Bio::EnsEMBL::ProjectionSegment");
      push(@$projections, $new_projection);
    }
  }

  return $projections;
}


=head2 _method_returning_simple_features

  Args[1]     : method_name
  Description : This Slice is made of several Bio::EnsEMBL::Slices mapped on it. This
                method go through all of them, calls method_name and maps teh result on
                this Bio::EnsEMBL::Compara::AlignSlice::Slice object.
  ReturnType  : listref of Bio::EnsEMBL::Variation::VariationFeature
  Exceptions  : none
  Caller      : contigview, snpview

=cut

sub _method_returning_simple_features {
  my $self = shift;
  my $method = shift;
  my $ret = [];

  foreach my $pair (@{$self->get_all_Slice_Mapper_pairs}) {
    my $this_slice = $pair->{slice};
    my $this_mapper = $pair->{mapper};
    my $this_ret = $this_slice->$method(@_);
    foreach my $this_object (@$this_ret) {
      my ($this_start, $this_end);
      if ($this_slice->strand == 1) {
        $this_start = $this_object->slice->start + $this_object->start - 1;
        $this_end = $this_object->slice->start + $this_object->end - 1;
      } else {
        $this_start = $this_object->slice->start + ($this_object->slice->length - $this_object->end);
        $this_end = $this_object->slice->start + ($this_object->slice->length - $this_object->start);
      }
      my @alignment_coords = $this_mapper->map_coordinates(
              'sequence',
              $this_start,
              $this_end,
              $this_object->strand,
              'sequence'
          );
      my ($start, $end, $strand);
      foreach my $alignment_coord (@alignment_coords) {
        if ($alignment_coord->isa("Bio::EnsEMBL::Mapper::Coordinate")) {
          if (!defined($start) or $start > $alignment_coord->start) {
            $start = $alignment_coord->start;
          }
          if (!defined($end) or $end < $alignment_coord->end) {
            $end = $alignment_coord->end;
          }
          if (!defined($strand)) {
            $strand = $alignment_coord->strand * $this_slice->strand;
          }
        }
      }
      my $new_object;
      %$new_object = %$this_object;
      bless $new_object, ref($this_object);
      if (defined($start) and defined($end) and defined($strand)) {
        $new_object->{start} = $start - $self->start + 1;
        $new_object->{end} = $end - $self->start + 1;
        $new_object->{strand} = $strand;
        $new_object->{slice} = $self;
        # Skip this object if it maps outside of this AlignSlice
        next if ($new_object->{start} > $self->length or $new_object->{end} < 1);
        push(@$ret, $new_object);
      }
    }
  }
  return $ret;
}

1;
