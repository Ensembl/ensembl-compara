package Bio::EnsEMBL::Compara::Member;

use strict;
use Bio::EnsEMBL::Compara::BaseRelation;

our @ISA = qw(Bio::EnsEMBL::Compara::BaseRelation);

=head2 new

=cut

sub new {
  my ($class, @args) = @_;

  my $self = $class->SUPER::new(@args);

  if (scalar @args) {
    my ($taxon_id, $genome_db_id) = $self->_rearrange([qw(TAXON_ID GENOME_DB_ID)], @args);

    $taxon_id && $self->taxon_id($taxon_id);
    $genome_db_id && $self->genome_db_id($genome_db_id);
  }
  
  return $self;
}   

=head2 chr_name

=cut

sub chr_name {
  my $self = shift;
  $self->{'_chr_name'} = shift if (@_);
  return $self->{'_chr_name'};
}

=head2 chr_start

=cut

sub chr_start {
  my $self = shift;
  $self->{'_chr_start'} = shift if (@_);
  return $self->{'_chr_start'};
}

=head2 chr_end

=cut

sub chr_end {
  my $self = shift;
  $self->{'_chr_end'} = shift if (@_);
  return $self->{'_chr_end'};
}

=head taxon_id

=cut

sub taxon_id {
    my $self = shift;
    $self->{'_taxon_id'} = shift if (@_);
    return $self->{'_taxon_id'};
}

=head2 taxon

=cut

sub taxon {
  my $self = shift;

  if (@_) {
    my $taxon = shift;
    unless ($taxon->isa('Bio::EnsEMBL::Compara::Taxon')) {
      $self->throw(
		   "taxon arg must be a [Bio::EnsEMBL::Compara::Taxon".
		   "not a [$taxon]");
    }
    $self->{'_taxon'} = $taxon;
    $self->taxon_id($taxon->ncbi_taxid);
  } else {
    unless (defined $self->{'_taxon'}) {
      unless (defined $self->taxon_id) {
        $self->throw("can't fetch Taxon without a taxon_id");
      }
      my $TaxonAdaptor = $self->adaptor->db->get_TaxonAdaptor;
      $self->{'_taxon'} = $TaxonAdaptor->fetch_by_dbID($self->taxon_id);
    }
  }
  
  return $self->{'_taxon'};
}

=head genome_db_id

=cut

sub genome_db_id {
    my $self = shift;
    $self->{'_genome_db_id'} = shift if (@_);
    return $self->{'_genome_db_id'};
}

=head2 genome_db

=cut

sub genome_db {
  my $self = shift;

  if (@_) {
    my $genome_db = shift;
    unless ($genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB')) {
      $self->throw(
		   "arg must be a [Bio::EnsEMBL::Compara::GenomeDB".
		   "not a [$genome_db]");
    }
    $self->{'_genome_db'} = $genome_db;
    $self->genome_db_id($genome_db->dbID);
  } else {
    unless (defined $self->{'_genome_db'}) {
      unless (defined $self->genome_db_id) {
        $self->throw("can't fetch GenomeDB without a genome_db_id");
      }
      my $GenomeDBAdaptor = $self->adaptor->db->get_GenomeDBAdaptor;
      $self->{'_genome_db'} = $GenomeDBAdaptor->fetch_by_dbID($self->genome_db_id);
    }
  }
  
  return $self->{'_genome_db'};
}

=head2 sequence

  Arg [1]    : string $sequence
  Example    : my $seq = $member->sequence;
  Description: Extracts the sequence string of this member
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub sequence {
  my $self = shift;
  $self->{'_sequence'} = shift if(@_);
  return $self->{'_sequence'};
}

1;
