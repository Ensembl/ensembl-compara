
#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::ExternalFeatureView
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::ExternalFeatureView - View from one species of a comparative database

=head1 SYNOPSIS

   
   $view = Bio::EnsEMBL::Compara::DBSQL::ExternalFeatureView->new(
								  -compara => $comparadb,
								  -species => 'Homo_sapiens');

   $standard_db_adaptor->add_ExternalFeatureFactory($view);


=head1 DESCRIPTION

Provides a view of this comparative database from one species
perspective, giving out features (AlignBlocks) in
ExternalFeatureFactory manner

=head1 AUTHOR - Ewan Birney

This modules is part of the Ensembl project http://www.ensembl.org

Email birney@ebi.ac.uk

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::ExternalFeatureView;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Compara::ExternalViewAlign;

# Object preamble - inherits from Bio::EnsEMBL::DB::ExternalFeatureFactoryI

use Bio::EnsEMBL::DB::ExternalFeatureFactoryI
@ISA = qw(Bio::EnsEMBL::DB::ExternalFeatureFactoryI);

# new() is written here 

sub new {
  my($class,@args) = @_;

  my $self = {};
  bless $self,$class;

  my ($species_tag,$compara) = $self->_rearrange([qw(SPECIES COMPARA )],@args);

  if( !defined $species_tag ) {
      $self->throw("Must have a species tag (-species)");
  }
  
  if( !defined $compara ) {
      $self->throw("Must have a compara database");
  }

  my $genome_db = $compara->get_GenomeDBAdaptor->fetch_by_species_tag($species_tag);
  if( !defined $genome_db) {
      $self->throw("Cannot make ExternalFeatureView of comparative database from $species_tag");
  }


  $self->compara($compara);
  $self->genome_db($genome_db);


# set stuff in self from @args
  return $self;
}

=head2 get_Ensembl_SeqFeatures_contig_list

 Title   : get_Ensembl_SeqFeatures_contig_list
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_Ensembl_SeqFeatures_contig_list{
   my ($self,$hash_ref,@internal_contig) = @_;

   my @contigs;

   foreach my $id ( @internal_contig ) {
     push(@contigs,$hash_ref->{$id});
   }

   my %hash;

   foreach my $c ( @contigs ) {
       $hash{$c} = 1;
   }

   my @list = keys %hash;

   my @galn = $self->compara->get_GenomicAlignAdaptor->fetch_by_genomedb_dnafrag_list($self->genome_db,\@list);

   my @out;

   foreach my $aln ( @galn ) {
       foreach my $abs ( $aln->each_AlignBlockSet ) {
	   my @aln = $abs->get_AlignBlocks();
	   foreach my $al ( @aln ) {
	       if( exists $hash{$al->dnafrag->name} ) {
		   my $ex = Bio::EnsEMBL::Compara::ExternalViewAlign->new();
		   $ex->start($al->start);
		   $ex->end($al->end);
		   $ex->strand($al->strand);
		   $ex->seqname($al->dnafrag->name);
		   $ex->align($aln);
		   push(@out,$ex);
	       }
	   }
       }
   }

   return @out;
}



=head2 genome_db

 Title   : genome_db
 Usage   : $obj->genome_db($newval)
 Function: 
 Example : 
 Returns : value of genome_db
 Args    : newvalue (optional)


=cut

sub genome_db{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'genome_db'} = $value;
    }
    return $self->{'genome_db'};

}

=head2 compara

 Title   : compara
 Usage   : $obj->compara($newval)
 Function: 
 Example : 
 Returns : value of compara
 Args    : newvalue (optional)


=cut

sub compara{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'compara'} = $value;
    }
    return $self->{'compara'};

}

1;
