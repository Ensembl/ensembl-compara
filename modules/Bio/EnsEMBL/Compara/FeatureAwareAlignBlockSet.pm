

#
# Ensembl module for Bio::EnsEMBL::Compara::FeatureAwareAlignBlockSet
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::FeatureAwareAlignBlockSet - AlignBlockSet which can deliver features

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 AUTHOR - Ewan Birney

This modules is part of the Ensembl project http://www.ensembl.org

Email birney@ebi.ac.uk

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::FeatureAwareAlignBlockSet;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::Compara::AlignBlockSet;
use Bio::EnsEMBL::Compara::MappedExon;

# Object preamble - inherits from Bio::Root::RootI

use Bio::Root::RootI;

@ISA = qw(Bio::EnsEMBL::Compara::AlignBlockSet);


=head2 get_all_Genes_exononly

 Title   : get_all_Genes_exononly
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_all_Genes_exononly {
   my ($self) = @_;

   my @genes = $self->core_adaptor->get_GeneAdaptor->fetch_by_contig_list($self->contig_list);

   my @out;
   my $mapper = $self->get_Mapper;
  
   foreach my $gene ( @genes ) {
       my $new_gene = Bio::EnsEMBL::Gene->new();
       $new_gene->dbID($gene->dbID);
       $new_gene->adaptor($gene->adaptor);
       push(@out,$new_gene);

       foreach my $trans ( $gene->each_Transcript() ) {
	   my $new_trans = Bio::EnsEMBL::Transcript->new();
	   $new_trans->dbID($trans->dbID);
	   $new_trans->adaptor($trans->adaptor);

	   $new_gene->add_Transcript($new_trans);
	   my $rank = 0;
	   foreach my $exon ( $trans->get_all_Exons() ) {
	       $rank++;
	       my @coordlist = $mapper->map_coordinates($exon->start,$exon->end,$exon->strand,$exon->contig_id,"rawcontig");

	       if( scalar(@coordlist) == 1 && $coordlist[0]->isa('Bio::EnsEMBL::Mapper::Gap') ) {
		   # skip this exon
		   next;
	       }


	       my $new_exon = Bio::EnsEMBL::Compara::MappedExon->new();
	       $new_exon->dbID($new_exon->dbID);
	       $new_exon->adaptor($new_exon->adaptor);
	       $new_exon->rank($rank);
	       $new_exon->warped(0);

	       # remove starting and trailing gaps, setting warped if so
	       while( $coordlist[0]->isa('Bio::EnsEMBL::Mapper::Gap') ) {
		   unshift @coordlist;
		   $new_exon->warped(1);
	       } 

	       while( $coordlist[$#coordlist]->isa('Bio::EnsEMBL::Mapper::Gap') ) {
		   pop @coordlist;
		   $new_exon->warped(1);
	       } 

	       # set start and end

	       $new_exon->start($coordlist[0]->start);
	       $new_exon->end($coordlist[$#coordlist]->end);

	       # if more than 1 then must gap

	       if( scalar(@coordlist) != 1 ) {
		   $new_exon->warped(1);
	       }

	       # attach to Transcript

	       $new_trans->add_Exon($new_exon);
	   }
       }
   }

   return @out;
}


=head2 core_adaptor

 Title   : core_adaptor
 Usage   : $obj->core_adaptor($newval)
 Function: 
 Example : 
 Returns : value of core_adaptor
 Args    : newvalue (optional)


=cut

sub core_adaptor{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'core_adaptor'} = $value;
    }
    return $self->{'core_adaptor'};

}


1;

