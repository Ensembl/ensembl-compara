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

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::DnaAlignFeatureAdaptor

=head1 SYNOPSIS

$dafa = $compara_dbadaptor->get_DnaAlignFeatureAdaptor;
@align_features = @{$dafa->fetch_by_Slice_species($slice, $qy_species)};

=head1 DESCRIPTION

Retrieves alignments from a compara database in the form of DnaDnaAlignFeatures

=head1 CONTACT

Post questions to the EnsEMBL developer list: <http://lists.ensembl.org/mailman/listinfo/dev>

=cut


package Bio::EnsEMBL::Compara::DBSQL::DnaAlignFeatureAdaptor;

use strict;
use warnings;
use vars qw(@ISA);

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Cache; #CPAN LRU cache
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);
use Bio::EnsEMBL::DnaDnaAlignFeature;

use Bio::EnsEMBL::Utils::Exception;


@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

my $CACHE_SIZE = 4;

=head2 new

  Arg [1]    : list of args to super class constructor
  Example    : $dafa = new Bio::EnsEMBL::Compara::Genomi
  Description: Creates a new DnaAlignFeatureAdaptor.  The superclass
               constructor is extended to initialise an internal cache.  This
               class should be instantiated through the get method on the
               DBAdaptor rather than calling this method directory.
  Returntype : none
  Exceptions : none
  Caller     : Bio::EnsEMBL::DBSQL::DBConnection

=cut

sub new {
  my ($class, @args) = @_;

  my $self = $class->SUPER::new(@args);

  #initialize internal LRU cache
  tie(%{$self->{'_cache'}}, 'Bio::EnsEMBL::Utils::Cache', $CACHE_SIZE);

  return $self;
}



=head2 fetch_all_by_species_region

 Arg [1]    : string $cs_species
              e.g. "Homo sapiens"
 Arg [2]    : string $cs_assembly (can be undef)
              e.g. "NCBI_31" if undef the current will be taken
 Arg [3]    : string $qy_species
              e.g. "Mus musculus"
 Arg [4]    : string $qy_assembly (can be undef)
              e.g. "MGSC_3", if undef the current will be taken
 Arg [5]    : string $chromosome_name
              the name of the chromosome to retrieve alignments from (e.g. 'X')
 Arg [6]    : int start
 Arg [7]    : int end
 Arg [8]    : string $alignment_type
              The type of alignments to be retrieved
              e.g. WGA or WGA_HCR
 Example    : $gaa->fetch_all_by_species_region("Homo sapiens", "NCBI_31",
						"Mus musculus", "MGSC_3",
                                                "X", 250_000, 750_000,"WGA");
 Description: Retrieves alignments between the consensus and query species
              from a specified region of the consensus genome.
 Returntype : an array reference of Bio::EnsEMBL::DnaDnaAlignFeature objects
 Exceptions : returns a ref to an empty list if requested DnaFrag or MethodLinkSpeciesSet
              are not in the compara DB.
 Caller     : general

=cut

sub fetch_all_by_species_region {
  my ($self, $consensus_species, $consensus_assembly,
      $query_species, $query_assembly,
      $chromosome_name, $start, $end, $alignment_type, $limit,$dnafrag_type) = @_;

  $limit = 0 unless (defined $limit);

  #get the genome database for each species
  my $genome_db_adaptor = $self->db->get_GenomeDBAdaptor;
  my $consensus_genome_db = $genome_db_adaptor->fetch_by_name_assembly($consensus_species, $consensus_assembly);
  my $query_genome_db = $genome_db_adaptor->fetch_by_name_assembly($query_species, $query_assembly);

  #retrieve dna fragments from the subjects species region of interest
  my $dna_frag_adaptor = $self->db->get_DnaFragAdaptor;
  my $this_dnafrag = $dna_frag_adaptor->fetch_by_GenomeDB_and_name(
          $consensus_genome_db,
          $chromosome_name,
      );
  return [] if (!$this_dnafrag);

  # Get the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object corresponding to the alignment_type and
  # the couple of genomes
  my $method_link_species_set_adaptor = $self->db->get_MethodLinkSpeciesSetAdaptor;
  my $method_link_species_set;
  if ($consensus_genome_db->dbID == $query_genome_db->dbID) {
    # Allow to fetch the right method_link_species_set for self-comparisons!
    $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs(
        $alignment_type, [$consensus_genome_db]);
  } else {
    # Normal, pairwise comparisons...
    $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs(
          $alignment_type,
          [$consensus_genome_db, $query_genome_db]
      );
  }
  return [] if (!$method_link_species_set);

#   my $gaa = $self->db->get_GenomicAlignAdaptor;
  my $genomic_align_block_adaptor = $self->db->get_GenomicAlignBlockAdaptor;

  my @out = ();

  my $consensus_slice_adaptor = $consensus_genome_db->db_adaptor->get_SliceAdaptor;
  my $query_slice_adaptor;
  eval {
    $query_slice_adaptor = $query_genome_db->db_adaptor->get_SliceAdaptor;
  };
  #caclulate coords relative to start of dnafrag
  ## Bio::EnsEMBL::Compara::Dnafrag::start is always 1
  #     my $this_dnafrag_start = $start - $this_dnafrag->start + 1;
  #     my $this_dnafrag_end   = $end   - $this_dnafrag->start + 1;
  my $this_dnafrag_start = $start;
  my $this_dnafrag_end   = $end;

  #constrain coordinates so they are completely within the dna frag
  my $this_dnafrag_length = $this_dnafrag->length;
  $this_dnafrag_start = 1 unless (defined $this_dnafrag_start);
  $this_dnafrag_start = ($this_dnafrag_start < 1)  ? 1 : $this_dnafrag_start;

  $this_dnafrag_end = $this_dnafrag_length unless (defined $this_dnafrag_end);
  $this_dnafrag_end   = ($this_dnafrag_end > $this_dnafrag_length) ? $this_dnafrag_length : $this_dnafrag_end;

  #fetch all alignments in the region we are interested in
  my $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
          $method_link_species_set,
          $this_dnafrag,
          $this_dnafrag_start,
          $this_dnafrag_end,
          $limit
      );

  #convert genomic align blocks to dna align features
  my $dafs = _convert_GenomicAlignBlocks_into_DnaDnaAlignFeatures($genomic_align_blocks);

  # We need to attach slices of the entire seq region to the features.
  # The features come without any slices at all, but their coords are
  # relative to the beginning of the seq region.
  my $top_slice = $consensus_slice_adaptor->fetch_by_region($dnafrag_type, $chromosome_name);

  map {$_->slice($top_slice)} @$dafs;

  return $dafs;
}

=head2 fetch_all_by_Slice

 Arg [1]    : Bio::EnsEMBL::Slice
 Arg [2]    : string $qy_species
              The query species to retrieve alignments against
 Arg [3]    : string $qy_assembly
 Arg [4]    : string $$alignment_type
              The type of alignments to be retrieved
              e.g. WGA or WGA_HCR
 Arg [5]    : integer $limit_number [optional]
 Arg [6]    : integer $limit_index_start [optional]
 Arg [7]    : boolean $restrict_resulting_blocks [optional]

 Example    : $gaa->fetch_all_by_Slice($slice, "Mus musculus","WGA");
 Description: find matches of query_species in the region of a slice of a
              subject species
 Returntype : an array reference of Bio::EnsEMBL::DnaDnaAlignFeature objects
 Exceptions : none
 Caller     : general

=cut

sub fetch_all_by_Slice {
  my ($self, $orig_slice, $qy_species, $qy_assembly, $alignment_type,
      $limit, $limit_index_start, $restrict) = @_;

  assert_ref($orig_slice, 'Bio::EnsEMBL::Slice', 'orig_slice');

  unless($qy_species) {
    throw("Query species argument is required");
  }

  $limit = 0 unless (defined $limit);
  $restrict = 1 unless (defined $restrict); #Set the default to restrict the genomic_align_blocks to the limits of the slice

  my $genome_db_adaptor = $self->db->get_GenomeDBAdaptor();
  my $cs_genome_db = $genome_db_adaptor->fetch_by_Slice($orig_slice);
  #my $qy_genome_db = $genome_db_adaptor->fetch_by_registry_name($qy_species);

  my $qy_genome_db;
  if($qy_assembly) {
      $qy_genome_db = $genome_db_adaptor->fetch_by_name_assembly($qy_species, $qy_assembly);
  } else {
  	#Only use the registry if assembly was not defined.
  	$qy_genome_db = $genome_db_adaptor->fetch_by_registry_name($qy_species);
  }

  return [] if (!$cs_genome_db or !$qy_genome_db);

  my $method_link_species_set_adaptor = $self->db->get_MethodLinkSpeciesSetAdaptor();
  my $method_link_species_set;
  if ($cs_genome_db->dbID == $qy_genome_db->dbID) {
    $method_link_species_set = $method_link_species_set_adaptor->
        fetch_by_method_link_type_GenomeDBs($alignment_type, [$cs_genome_db]);
  } else {
    $method_link_species_set = $method_link_species_set_adaptor->
        fetch_by_method_link_type_GenomeDBs($alignment_type,
            [$cs_genome_db, $qy_genome_db]);
  }

  my $key = uc(join(':', $orig_slice->name,
                    $cs_genome_db->name, $qy_genome_db->name, $qy_genome_db->assembly, $alignment_type));

  if(exists $self->{'_cache'}->{$key}) {
    return $self->{'_cache'}->{$key};
  }

  my $genomic_align_block_adaptor = $self->db->get_GenomicAlignBlockAdaptor();
  my $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
      $method_link_species_set, $orig_slice, $limit, $limit_index_start, $restrict);
  my $dafs = _convert_GenomicAlignBlocks_into_DnaDnaAlignFeatures($genomic_align_blocks);

  #update the cache
  $self->{'_cache'}->{$key} = $dafs;
  return $dafs;
}

=head2 interpolate_best_location

  Arg [1]    : Bio::EnsEMBL::Slice $slice
  Arg [2]    : string $species
               e.g. "Mus musculus"
  Arg [3]    : string $alignment_type
               e.g. "LASTZ_NET"
  Arg [4]    : string $seq_region_name
               e.g. "6-COX"
  Example    :
  Description:
  Returntype : array with 3 elements
  Exceptions :
  Caller     :

=cut

sub interpolate_best_location {
  my ($self,$slice,$species,$alignment_type,$seq_region_name) = @_;

#warn $slice->name,"\t$species\t$alignment_type\t$seq_region_name";

  $| =1 ;
  my $max_distance_for_clustering = 10000;
  my $dafs = $self->fetch_all_by_Slice($slice, $species, undef, $alignment_type);
  my %name_strand_clusters;
  my $based_on_group_id = 1;
  foreach my $daf (@{$dafs}) {
    next if ($seq_region_name && $daf->hseqname ne $seq_region_name);
    if (defined $daf->group_id && $daf->group_id > 0 && $alignment_type ne "TRANSLATED_BLAT") {
      push @{$name_strand_clusters{$daf->group_id}}, $daf;
    } else {
      $based_on_group_id = 0 if ($based_on_group_id);
      push @{$name_strand_clusters{$daf->hseqname. "_" .$daf->hstrand}}, $daf;
    }
  }

  if ($based_on_group_id) {
    my @ordered_name_strands = sort {scalar @{$name_strand_clusters{$b}} <=> scalar @{$name_strand_clusters{$a}}} keys %name_strand_clusters;

    my @best_blocks = sort {$a->hstart <=> $b->hend} @{$name_strand_clusters{$ordered_name_strands[0]}||[]};

    return undef if( !@best_blocks );
    return ($best_blocks[0]->hseqname,
            $best_blocks[0]->hstart
            + int(($best_blocks[-1]->hend - $best_blocks[0]->hstart)/2),
            $best_blocks[0]->hstrand * $slice->strand,
            $best_blocks[0]->hstart,
            $best_blocks[-1]->hend);

  } else {

    my @refined_clusters;
    foreach my $name_strand (keys %name_strand_clusters) {
      # an array of arrayrefs
      # name, strand, start, end, nb of blocks
      my @sub_clusters;
      foreach my $block (sort {$a->hstart <=> $b->hstart} @{$name_strand_clusters{$name_strand}||[]}) {
        unless (scalar @sub_clusters) {
          push @sub_clusters, [$block->hseqname,$block->hstrand, $block->hstart, $block->hend, 1];
          next;
        }
        my $block_clustered = 0;
        foreach my $arrayref (@sub_clusters) {
          my ($n,$st,$s,$e,$c) = @{$arrayref};
          if ($block->hstart<=$e &&
              $block->hend>=$s) {
            # then overlaps.
            $arrayref->[2] = $block->hstart if ($block->hstart < $s);
            $arrayref->[3] = $block->hend if ($block->hend > $e);
            $arrayref->[4]++;
            $block_clustered = 1;
          } elsif ($block->hstart <= $e + $max_distance_for_clustering &&
                   $block->hstart > $e) {
            # then is downstream
            $arrayref->[3] = $block->hend;
            $arrayref->[4]++;
            $block_clustered = 1;
          } elsif ($block->hend >= $s - $max_distance_for_clustering &&
                   $block->hend < $s) {
            # then is upstream
            $arrayref->[2] = $block->hstart;
            $arrayref->[4]++;
            $block_clustered = 1;
          }
        }
        unless ($block_clustered) {
          # do not overlap anything already seen, so adding as new seeding cluster
          push @sub_clusters, [$block->hseqname,$block->hstrand, $block->hstart, $block->hend, 1];
        }
      }
      push @refined_clusters, @sub_clusters;
    }

    # sort by the max number of blocks desc
    @refined_clusters = sort {$b->[-1] <=> $a->[-1]} @refined_clusters;

    return undef if(!@refined_clusters);
    return ($refined_clusters[0]->[0], #hseqname,
            $refined_clusters[0]->[2]
            + int(($refined_clusters[0]->[3] - $refined_clusters[0]->[2])/2),
            $refined_clusters[0]->[1] * $slice->strand,
            $refined_clusters[0]->[2],
            $refined_clusters[0]->[3]);

  }
}


=head2 deleteObj

  Arg [1]    : none
  Example    : none
  Description: Called automatically by DBConnection during object destruction
               phase. Clears the cache to avoid memory leaks.
  Returntype : none
  Exceptions : none
  Caller     : none

=cut

sub deleteObj {
  my $self = shift;

  $self->SUPER::deleteObj;

  #clear the cache, removing references
  %{$self->{'_cache'}} = ();
}


=head2 deleteObj

  Arg [1]    : none
  Example    : none
  Description: Called automatically by DBConnection during object destruction
               phase. Clears the cache to avoid memory leaks.
  Returntype : none
  Exceptions : none
  Caller     : none

=cut

sub _convert_GenomicAlignBlocks_into_DnaDnaAlignFeatures {
  my ($genomic_align_blocks) = @_;
  my $dna_dna_align_features = [];

  my $query_slice_adaptor;

  foreach my $this_genomic_align_block (@$genomic_align_blocks) {
    ## KNOWN BUG: This will ignore third and following parts of a multiple alignment...
    ## This adaptor cannot deal with multiple alignments. Use the new
    ## Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor instead.
    my $consensus_genomic_align = $this_genomic_align_block->reference_genomic_align;
    my $query_genomic_align = $this_genomic_align_block->get_all_non_reference_genomic_aligns->[0];

    my $top_slice;
    if (!defined($query_slice_adaptor)) {
      $query_slice_adaptor = $query_genomic_align->get_Slice->adaptor;
    }
    if ($query_slice_adaptor) {
      $top_slice = $query_slice_adaptor->fetch_by_region(
              $query_genomic_align->dnafrag->coord_system_name,
              $query_genomic_align->dnafrag->name
          );
    } else {
      $top_slice = undef;
    }

    ## The code for transforming GenomicAlignBlocks into DnaDnaAlignFeatures assumes that
    ## reference_genomic_align is on the forward strand!
    if ($consensus_genomic_align->dnafrag_strand == -1) {
      $this_genomic_align_block->reverse_complement;
    }
    my $cstart = $consensus_genomic_align->dnafrag_start;
    my $cend   = $consensus_genomic_align->dnafrag_end;

    #skip features which do not overlap the requested region
    #next if ($cstart > $end || $cend < $start);

    my $ga_cigar_line;
    do {
      my @consensus_cigar_pieces = split(/(\d*[DIMG])/, $consensus_genomic_align->cigar_line);
      my @query_cigar_pieces = split(/(\d*[DIMG])/, $query_genomic_align->cigar_line);

      my @consensus_gapped_pieces;
      foreach my $piece (@consensus_cigar_pieces) {
        next if ($piece !~ /^(\d*)([MDIG])$/);
        my $num = $1;
        my $type = $2;
        $num = 1 if ($num !~ /^\d+$/);
        if( $type eq "M" ) {
          for (my $i=0; $i<$num; $i++) {push(@consensus_gapped_pieces, "N")}
        } else {
          for (my $i=0; $i<$num; $i++) {push(@consensus_gapped_pieces, '-')}
        }
      }
      my @query_gapped_pieces;
      foreach my $piece (@query_cigar_pieces) {
        next if ($piece !~ /^(\d*)([MDIG])$/);
        my $num = $1;
        my $type = $2;
        $num = 1 if ($num !~ /^\d+$/);
        if( $type eq "M" ) {
          for (my $i=0; $i<$num; $i++) {push(@query_gapped_pieces, "N")}
        } else {
          for (my $i=0; $i<$num; $i++) {push(@query_gapped_pieces, '-')}
        }
      }
      throw if (scalar(@consensus_gapped_pieces) != scalar(@query_gapped_pieces));
      my $type = "";
      my $num = 0;
      for (my $i=0; $i<@consensus_gapped_pieces; $i++) {
        if ($consensus_gapped_pieces[$i] eq "N" and $query_gapped_pieces[$i] eq "N") {
          if ($type ne "M") {
            $ga_cigar_line .= (($num==1)?"":$num).$type if ($num);
            $num = 0;
            $type = "M";
          }
        } elsif ($consensus_gapped_pieces[$i] eq "N" and $query_gapped_pieces[$i] eq "-") {
          if ($type ne "I") {
            $ga_cigar_line .= (($num==1)?"":$num).$type if ($num);
            $num = 0;
            $type = "I";
          }
        } elsif ($consensus_gapped_pieces[$i] eq "-" and $query_gapped_pieces[$i] eq "N") {
          if ($type ne "D") {
            $ga_cigar_line .= (($num==1)?"":$num).$type if ($num);
            $num = 0;
            $type = "D";
          }
        } elsif ($this_genomic_align_block->method_link_species_set->method->type =~ /^CACTUS_HAL/) {
          # Cactus returns blocks with double-gaps
          $num--;   # to cancel out the incrementation below
        } else {
          # But other methods shouldn't
          throw "no double gaps can occur in a pairwise alignment!";
        }
        $num++;
      }
      $ga_cigar_line .= (($num==1)?"":$num).$type;
    };
    my $df_name = $consensus_genomic_align->dnafrag->name;
    my $score = $this_genomic_align_block->score;
    my $perc_id = $this_genomic_align_block->perc_id;
    my $qdf_start = 1;
    my $ga_query_start = $query_genomic_align->dnafrag_start;
    my $ga_query_end = $query_genomic_align->dnafrag_end;
    my $ga_query_strand = $query_genomic_align->dnafrag_strand;
    my $qdf_name = $query_genomic_align->dnafrag->name;
    my $ga_strands_reversed = 0;
    if ($consensus_genomic_align->dnafrag_strand == -1) {
      $ga_strands_reversed = 1;
      $ga_query_strand = -$ga_query_strand;
    }

    #Stored on the genomic_align_block
    my $ga_group_id = $this_genomic_align_block->group_id();
    my $ga_level_id = $this_genomic_align_block->level_id();

    my ($slice, $seq_name, $start, $end, $strand);
    if ($this_genomic_align_block->reference_slice) {
      $slice = $this_genomic_align_block->reference_slice;
      $seq_name = $this_genomic_align_block->reference_slice->name;
      $start = $this_genomic_align_block->reference_slice_start;
      $end = $this_genomic_align_block->reference_slice_end;
      $strand = $this_genomic_align_block->reference_slice_strand;
    } else {
      $slice = $consensus_genomic_align->get_Slice();
      $seq_name = $consensus_genomic_align->dnafrag->name;
      $start = $consensus_genomic_align->dnafrag_start;
      $end = $consensus_genomic_align->dnafrag_end;
      $strand = $consensus_genomic_align->dnafrag_strand;
    }

    my $f = Bio::EnsEMBL::DnaDnaAlignFeature->new_fast
      ({'cigar_string' => $ga_cigar_line,
        'slice'        => $slice,
        'seqname'      => $seq_name,
        'start'        => $start,
        'end'          => $end,
        'strand'       => $strand,
        'species'      => $consensus_genomic_align->genome_db->name,
        'score'        => $score,
        'percent_id'   => $perc_id,
        'hstart'       => $qdf_start + $ga_query_start - 1,
        'hend'         => $qdf_start + $ga_query_end -1,
        'hstrand'      => $ga_query_strand,
        'hseqname'     => $qdf_name,
        'hspecies'     => $query_genomic_align->genome_db->name,
        'hslice'       => $top_slice,
        'align_type'   => $this_genomic_align_block->method_link_species_set->method->type,
        'group_id'     => $ga_group_id,
        'level_id'     => $ga_level_id,
        'strands_reversed' => $ga_strands_reversed});

    push @$dna_dna_align_features, $f;
  }

  return $dna_dna_align_features;
}

1;


