# Copyright EnsEMBL 1999-2003
#
# Ensembl module for Bio::EnsEMBL::DBSQL::DnaAlignFeatureAdaptor
#
# You may distribute this module under the same terms as perl itself

=head1 NAME

Bio::EnsEMBL::DBSQL::DnaAlignFeatureAdaptor

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

 Arg [1]    : string subject_species
              e.g. "Homo_sapiens"
 Arg [2]    : string query_species
              e.g. "Mus_musculus"
 Arg [6]    : string dnafrag_type (optional)
              type of dnafrag from which data as to be queried, default is 
              "Chromosome"
 Arg [3]    : string name
              the name of the dnafrag to retrieve alignments from (e.g. 'X')
 Arg [4]    : int start
 Arg [5]    : int end
 Example    : $gaa->fetch_all_by_species_region("Homo_sapiens","Mus_musculus",
                                                "Chromosome", "X",
						250_000, 750_000);  
 Description: find matches of query_species on subject_species between 
              a given region on a dnafrag
 Returntype : an array reference of Bio::EnsEMBL::DnaDnaAlignFeature objects
 Exceptions : none
 Caller     : general

=cut

sub fetch_all_by_species_region {
  my ($self, $sb_species, $qy_species, 
      $dnafrag_type, $name, $start, $end) = @_;

  $dnafrag_type ||= "Chromosome"; #default is Chromosome
  
  #get the genome database for each species
  my $gdba = $self->db->get_GenomeDBAdaptor;  
  my $sb_gdb = $gdba->fetch_by_species_tag($sb_species);
  my $qy_gdb = $gdba->fetch_by_species_tag($qy_species);


  #retrieve dna fragments from the subjects species region of interest
  my $dfa = $self->db->get_DnaFragAdaptor;
  my $dnafrags = $dfa->fetch_all_by_species_region($sb_species,
						   $dnafrag_type, 
						   $name,
						   $start, 
						   $end);
  
  my $gaa = $self->db->get_GenomicAlignAdaptor;

  my @out = ();

  foreach my $df (@$dnafrags) {
    #retreive subject/query alignments for each dna fragment
    my $genomic_aligns = $gaa->fetch_all_by_dnafrag_genomedb($df, $qy_gdb);

    #convert genomic aligns to dna align features
    foreach my $ga (@$genomic_aligns) {
      my $f = Bio::EnsEMBL::DnaDnaAlignFeature->new(
				       '-cigar_string' => $ga->cigar_line);
      my $cdf = $ga->consensus_dnafrag;
      my $qdf = $ga->query_dnafrag;

      $f->contig($cdf->contig);
      $f->start($cdf->start + $ga->consensus_start - 1);
      $f->end($cdf->start + $ga->consensus_end - 1);
      $f->strand(1);
      $f->species($sb_species);
      $f->score($ga->score);
      $f->percent_id($ga->perc_id);

      $f->hstart($qdf->start + $ga->query_start - 1);
      $f->hend($qdf->start + $ga->query_end -1);
      $f->hstrand($ga->query_strand);
      $f->hseqname($qdf->contig->name);
      $f->hspecies($qy_species);

      push @out, $f;
    }
  }

  return \@out;
}




=head2 fetch_all_by_Slice

 Arg [1]    : Bio::EnsEMBL::Slice
 Arg [2]    : string query_species
              e.g. "Mus_musculus"
 Example    : $gaa->fetch_all_by_Slice($slice, "Mus_musculus");
 Description: find matches of query_species in the region of a slice of a 
              subject species
 Returntype : an array reference of Bio::EnsEMBL::DnaDnaAlignFeature objects
 Exceptions : none
 Caller     : general

=cut

sub fetch_all_by_Slice {
  my ($self, $slice, $qy_species) = @_;

  unless($slice && ref $slice && $slice->isa('Bio::EnsEMBL::Slice')) {
    $self->throw("Invalid slice argument [$slice]\n");
  }

  unless($qy_species) {
    $self->throw("Query species argument is required");
  }

  #we will probably use a taxon object instead of a string eventually
  my $species = $slice->adaptor->db->get_MetaContainer->get_Species;
  my $sb_species = $species->binomial;
  $sb_species =~ s/ /_/; #replace spaces with underscores

  my $key = join(':', "SLICE", $slice->name, $sb_species, $qy_species);

  if(exists $self->{'_cache'}->{$key}) {
    return $self->{'_cache'}->{$key};
  } 

  my $slice_start = $slice->chr_start;
  my $slice_end   = $slice->chr_end;
  my $slice_strand = $slice->strand;

  my $features = $self->fetch_all_by_species_region($sb_species,
						    $qy_species,
						    'Chromosome',
						    $slice->chr_name,
						    $slice_start,
						    $slice_end);

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
      my $start  = $slice_end - $f->start + 1;
      my $end    = $slice_end - $f->end   + 1;
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


