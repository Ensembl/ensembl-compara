# Copyright EnsEMBL 1999-2003
#
# Ensembl module for Bio::EnsEMBL::DBSQL::DnaAlignFeatureAdaptor
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
      $chr_name, $start, $end,$alignment_type, $limit) = @_;

  $limit = 0 unless (defined $limit);

  my $dnafrag_type = 'Chromosome';

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
      my $f = Bio::EnsEMBL::DnaDnaAlignFeature->new(
				       '-cigar_string' => $ga->cigar_line);
      my $qdf = $ga->query_dnafrag;

      #calculate chromosomal coords
      my $cstart = $df->start + $ga->consensus_start - 1;
      my $cend   = $df->start + $ga->consensus_end - 1;

      #skip features which do not overlap the requested region
      #next if ($cstart > $end || $cend < $start); 

      $f->seqname($df->name);
      $f->start($cstart);
      $f->end($cend);
      $f->strand(1);
      $f->species($cs_species);
      $f->score($ga->score);
      $f->percent_id($ga->perc_id);

      $f->hstart($qdf->start + $ga->query_start - 1);
      $f->hend($qdf->start + $ga->query_end -1);
      $f->hstrand($ga->query_strand);
      $f->hseqname($qdf->name);
      $f->hspecies($qy_species);

      push @out, $f;
    }
  }

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
  my ($self, $slice, $qy_species, $qy_assembly, $assembly_type, $limit) = @_;

  unless($slice && ref $slice && $slice->isa('Bio::EnsEMBL::Slice')) {
    $self->throw("Invalid slice argument [$slice]\n");
  }

  unless($qy_species) {
    $self->throw("Query species argument is required");
  }

  $limit = 0 unless (defined $limit);

  unless (defined $qy_assembly) {
    my $qy_gdb = $self->db->get_GenomeDBAdaptor->fetch_by_name_assembly($qy_species);
    $qy_assembly = $qy_gdb->assembly;
    warn "qy_assembly was undef. Queried the default one for $qy_species = $qy_assembly\n";
  }
  
  my $cs_species =
      $slice->adaptor->db->get_MetaContainer->get_Species->binomial;
  my $cs_assembly = $slice->assembly_type;

  my $key = uc(join(':', "SLICE", $slice->name,
		 $cs_species,$cs_assembly,
		 $qy_species, $qy_assembly,$assembly_type));

  if(exists $self->{'_cache'}->{$key}) {
    return $self->{'_cache'}->{$key};
  }

  my $slice_start = $slice->chr_start;
  my $slice_end   = $slice->chr_end;
  my $slice_strand = $slice->strand;

  my $features = $self->fetch_all_by_species_region($cs_species,$cs_assembly,
						    $qy_species,$qy_assembly,
						    $slice->chr_name,
						    $slice_start, $slice_end,$assembly_type,
                                                    $limit);

  if($slice_strand == 1) {
    foreach my $f (@$features) {
      my $start  = $f->start - $slice_start + 1;
      my $end    = $f->end   - $slice_start + 1;
      $f->start($start);
      $f->end($end);
      $f->contig($slice);
    }
  } else {
    foreach my $f (@$features) {
      my $start  = $slice_end - $f->end   + 1;
      my $end    = $slice_end - $f->start + 1;
      my $strand = $f->strand * -1;
      $f->start($start);
      $f->end($end);
      $f->strand($strand);
      $f->contig($slice);
    }
  }

  #update the cache
  $self->{'_cache'}->{$key} = $features;

  return $features;
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


