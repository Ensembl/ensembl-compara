# cOpyright EnsEMBL 1999-2004
#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::DnaAlignFeatureAdaptor
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::DnaAlignFeatureAdaptor

=head1 SYNOPSIS

$dafa = $compara_dbadaptor->get_DnaAlignFeatureAdaptor;
@align_features = @{$dafa->fetch_by_Slice_species($slice, $qy_species)};

=head1 DESCRIPTION

Retrieves alignments from a compara database in the form of DnaDnaAlignFeatures

=head1 CONTACT

Post questions to the EnsEMBL developer list: <ensembl-dev@ebi.ac.uk>

=cut


package Bio::EnsEMBL::Compara::DBSQL::DnaAlignFeatureAdaptor;
use strict;
use vars qw(@ISA);

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Cache; #CPAN LRU cache
use Bio::EnsEMBL::DnaDnaAlignFeature;

use Bio::EnsEMBL::Utils::Exception qw(warning throw);

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
              e.g. "NCBI_31" if undef assembly_default will be taken
 Arg [3]    : string $qy_species
              e.g. "Mus musculus"
 Arg [4]    : string $qy_assembly (can be undef)
              e.g. "MGSC_3", if undef assembly_default will be taken
 Arg [5]    : string $chr_name
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
 Exceptions : none
 Caller     : general

=cut

sub fetch_all_by_species_region {
  my ($self, $cs_species, $cs_assembly, 
      $qy_species, $qy_assembly,
      $chr_name, $start, $end, $alignment_type, $limit,$dnafrag_type) = @_;

  $limit = 0 unless (defined $limit);

  #get the genome database for each species
  my $gdba = $self->db->get_GenomeDBAdaptor;
  my $cs_gdb = $gdba->fetch_by_name_assembly($cs_species, $cs_assembly);
  my $qy_gdb = $gdba->fetch_by_name_assembly($qy_species, $qy_assembly);

  #retrieve dna fragments from the subjects species region of interest
  my $dfa = $self->db->get_DnaFragAdaptor;
  my $dnafrags = $dfa->fetch_all_by_GenomeDB_region($cs_gdb,
                                                    $dnafrag_type,
                                                    $chr_name,
                                                    $start,
                                                    $end);

  my $gaa = $self->db->get_GenomicAlignAdaptor;

  my @out = ();

  my $cs_sliceadaptor = $cs_gdb->db_adaptor->get_SliceAdaptor;
  my $qy_sliceadaptor;
  eval {
    $qy_sliceadaptor = $qy_gdb->db_adaptor->get_SliceAdaptor;
  };
  foreach my $df (@$dnafrags) {
    #caclulate coords relative to start of dnafrag
    my $df_start = $start - $df->start + 1;
    my $df_end   = $end   - $df->start + 1;

    #constrain coordinates so they are completely within the dna frag
    my $len = $df->end - $df->start + 1;
    $df_start = ($df_start < 1)  ? 1 : $df_start;
    $df_end   = ($df_end > $len) ? $len : $df_end;

    #fetch all alignments in the region we are interested in
    my $genomic_aligns = $gaa->fetch_all_by_DnaFrag_GenomeDB($df,
                                                             $qy_gdb,
                                                             $df_start,
                                                             $df_end,
                                                             $alignment_type,
                                                             $limit);

    #convert genomic aligns to dna align features
    foreach my $ga (@$genomic_aligns) {
      my $qdf = $ga->query_dnafrag;
      my $top_slice = $qy_sliceadaptor ?
          $qy_sliceadaptor->fetch_by_region($qdf->type, $qdf->name) : undef;
      #calculate chromosomal coords
      my $cstart = $df->start + $ga->consensus_start - 1;
      my $cend   = $df->start + $ga->consensus_end - 1;

      #skip features which do not overlap the requested region
      #next if ($cstart > $end || $cend < $start); 

      my $f = Bio::EnsEMBL::DnaDnaAlignFeature->new_fast
        ({'cigar_string' => $ga->cigar_line(),
          'seqname'      => $df->name,
          'start'        => $cstart,
          'end'          => $cend,
          'strand'       => 1,
          'species'      => $cs_species,
          'score'        => $ga->score(),
          'percent_id'   => $ga->perc_id(),
          'hstart'       => $qdf->start() + $ga->query_start() - 1,
          'hend'         => $qdf->start() + $ga->query_end() -1,
          'hstrand'      => $ga->query_strand(),
          'hseqname'     => $qdf->name,
          'hspecies'     => $qy_species,
          'hslice'       => $top_slice,
          'group_id'     => $ga->group_id(),
          'level_id'     => $ga->level_id(),
          'strands_reversed' => $ga->strands_reversed()});

      push @out, $f;
    }
  }

  # We need to attach slices of the entire seq region to the features.
  # The features come without any slices at all, but their coords are
  # relative to the beginning of the seq region.
  
  my $top_slice = $cs_sliceadaptor->fetch_by_region($dnafrag_type, $chr_name);
  map {$_->slice($top_slice)} @out;
  return \@out;
}




=head2 fetch_all_by_Slice

 Arg [1]    : Bio::EnsEMBL::Slice
 Arg [2]    : string $qy_species
              The query species to retrieve alignments against
 Arg [3]    : string $qy_assembly
 Arg [4]    : string $$alignment_type
              The type of alignments to be retrieved
              e.g. WGA or WGA_HCR
 Example    : $gaa->fetch_all_by_Slice($slice, "Mus musculus","WGA");
 Description: find matches of query_species in the region of a slice of a 
              subject species
 Returntype : an array reference of Bio::EnsEMBL::DnaDnaAlignFeature objects
 Exceptions : none
 Caller     : general

=cut

sub fetch_all_by_Slice {
  my ($self, $orig_slice, $qy_species, $qy_assembly, $alignment_type, 
      $limit) = @_;

  unless($orig_slice && ref $orig_slice && 
         $orig_slice->isa('Bio::EnsEMBL::Slice')) {
    throw("Invalid slice argument [$orig_slice]\n");
  }

  unless($qy_species) {
    throw("Query species argument is required");
  }

  $limit = 0 unless (defined $limit);

  unless (defined $qy_assembly) {
    my $qy_gdb = 
      $self->db->get_GenomeDBAdaptor->fetch_by_name_assembly($qy_species);
    $qy_assembly = $qy_gdb->assembly;
#    warning("qy_assembly was undef. Queried the default " .
#            "one for $qy_species = $qy_assembly\n");
  }

  my $slice_adaptor = $orig_slice->adaptor();

  if(!$slice_adaptor) {
    warning("Slice has no attached adaptor. Cannot get Compara features.");
  }
  
  my $cs_species = 
    $slice_adaptor->db->get_MetaContainer->get_Species->binomial();

  my $key = uc(join(':', $orig_slice->name,
                    $cs_species, $qy_species, $qy_assembly, $alignment_type));

  if(exists $self->{'_cache'}->{$key}) {
    return $self->{'_cache'}->{$key};
  }

  my @projection = @{$orig_slice->project('toplevel')};  
  return [] if(!@projection);

  my @results;

  foreach my $segment (@projection) {
    my $slice = $segment->to_Slice;
    my $slice_start = $slice->start;
    my $slice_end   = $slice->end;
    my $slice_strand = $slice->strand;

    my $cs_assembly = $slice->coord_system->version();
    my $dnafrag_type = $slice->coord_system->name;

    my $features = $self->fetch_all_by_species_region($cs_species,$cs_assembly,
                                                      $qy_species,$qy_assembly,
                                                      $slice->seq_region_name,
                                                      $slice_start, $slice_end,
                                                      $alignment_type,
                                                      $limit,$dnafrag_type);

    # We need to attach slices of the entire seq region to the features.
    # The features come without any slices at all, but their coords are
    # relative to the beginning of the seq region.
    
    # the above is now done in the fetch_all_by_species_region call
    
    my $top_slice = $slice_adaptor->fetch_by_region($dnafrag_type, 
                                                    $slice->seq_region_name);

    # need to convert features to requested coord system
    # if it was different then the one we used for fetching

    if($top_slice->name() ne $orig_slice->name()) {
      foreach my $f (@$features) {
        push @results, $f->transfer($orig_slice);
      }
    } else {
      push @results, @$features;
    }
  }

  #update the cache
  $self->{'_cache'}->{$key} = \@results;
  return \@results;
}

sub interpolate_best_location {
  my ($self,$slice,$species,$alignment_type) = @_;
  
  my $max_distance_for_clustering = 10000;
  my $dafs = $self->fetch_all_by_Slice($slice, $species, undef, $alignment_type);

  my %name_strand_clusters;
  my $based_on_group_id = 1;
  foreach my $daf (@{$dafs}) {
    if ($daf->group_id > 0) {
      push @{$name_strand_clusters{$daf->group_id}}, $daf;
    } else {
      $based_on_group_id = 0 if ($based_on_group_id);
      push @{$name_strand_clusters{$daf->hseq_region_name. "_" .$daf->hseq_region_strand}}, $daf;
    }
  }

  if ($based_on_group_id) {
    my @ordered_name_strands = sort {scalar @{$name_strand_clusters{$b}} <=> scalar @{$name_strand_clusters{$a}}} keys %name_strand_clusters;
    
    my @best_blocks = sort {$a->hseq_region_start <=> $b->hseq_region_end} @{$name_strand_clusters{$ordered_name_strands[0]}||[]};

    if( !@best_blocks ) {
      return undef;
    } elsif ($slice->strand > 0) {
      return ($best_blocks[0]->hseq_region_name,
              $best_blocks[0]->hseq_region_start 
              + int(($best_blocks[-1]->hseq_region_end - $best_blocks[0]->hseq_region_start)/2),
              $best_blocks[0]->hseq_region_strand);
    } else {
      return ($best_blocks[0]->hseq_region_name,
              $best_blocks[0]->hseq_region_start 
              + int(($best_blocks[-1]->hseq_region_end - $best_blocks[0]->hseq_region_start)/2),
              $best_blocks[0]->hseq_region_strand * -1);
    }

  } else {
    
    my @refined_clusters;
    foreach my $name_strand (keys %name_strand_clusters) {
      # an array of arrayrefs
      # name, strand, start, end, nb of blocks
      my @sub_clusters;
      foreach my $block (sort {$a->hseq_region_start <=> $b->hseq_region_start} @{$name_strand_clusters{$name_strand}||[]}) {
        unless (scalar @sub_clusters) {
          push @sub_clusters, [$block->hseq_region_name,$block->hseq_region_strand, $block->hseq_region_start, $block->hseq_region_end, 1];
          next;
        }
        my $block_clustered = 0;
        foreach my $arrayref (@sub_clusters) {
          my ($n,$st,$s,$e,$c) = @{$arrayref};
          if ($block->hseq_region_start<=$e &&
              $block->hseq_region_end>=$s) {
            # then overlaps.
            $arrayref->[2] = $block->hseq_region_start if ($block->hseq_region_start < $s);
            $arrayref->[3] = $block->hseq_region_end if ($block->hseq_region_end > $e);
            $arrayref->[4]++;
            $block_clustered = 1;
          } elsif ($block->hseq_region_start <= $e + $max_distance_for_clustering &&
                   $block->hseq_region_start > $e) {
            # then is downstream
            $arrayref->[3] = $block->hseq_region_end;
            $arrayref->[4]++;
            $block_clustered = 1;
          } elsif ($block->hseq_region_end >= $s - $max_distance_for_clustering &&
                   $block->hseq_region_end < $s) {
            # then is upstream
            $arrayref->[2] = $block->hseq_region_start;
            $arrayref->[4]++;
            $block_clustered = 1;
          }
        }
        unless ($block_clustered) {
          # do not overlap anything already seen, so adding as new seeding cluster
          push @sub_clusters, [$block->hseq_region_name,$block->hseq_region_strand, $block->hseq_region_start, $block->hseq_region_end, 1];
        }
      }
      push @refined_clusters, @sub_clusters;
    }

    # sort by the max number of blocks desc
    @refined_clusters = sort {$b->[-1] <=> $a->[-1]} @refined_clusters;

    if(!@refined_clusters) {
      return undef;
    } elsif ($slice->strand > 0) {
      return ($refined_clusters[0]->[0], #hseq_region_name,
              $refined_clusters[0]->[2]
              + int(($refined_clusters[0]->[3] - $refined_clusters[0]->[2])/2),
              $refined_clusters[0]->[1]);
    } else {
      return ($refined_clusters[0]->[0], #hseq_region_name
              $refined_clusters[0]->[2]
              + int(($refined_clusters[0]->[3] - $refined_clusters[0]->[2])/2),
              $refined_clusters[0]->[1] * -1);
    }
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


1;


