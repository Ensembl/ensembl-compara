

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

sub get_all_Genes_exononly{
   my ($self) = @_;

   my @genes = $self->core_adaptor->get_GeneAdaptor->fetch_Genes_by_contig_list($self->contig_list);

   foreach my $gene ( @genes ) {
       foreach my $transcript ( $gene->each_Transcript() ) {
	   foreach my $exon ( $transcript->each_Exon() ) {
	       $self->_map_feature($exon);
	   }
       }
   }

   return @genes;
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

