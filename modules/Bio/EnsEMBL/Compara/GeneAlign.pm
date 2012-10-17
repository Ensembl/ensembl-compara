=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::GeneAlign

=head1 DESCRIPTION

Class to represent an alignment of genes, used as the base for a
gene tree. It implements the AlignedMemberSet interface.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::GeneAlign
  +- Bio::EnsEMBL::Compara::AlignedMemberSet

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::GeneAlign;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use strict;

use base ('Bio::EnsEMBL::Compara::AlignedMemberSet');


##############################
# Constructors / Destructors #
##############################

=head2 new

  Example    :
  Description:
  Returntype : Bio::EnsEMBL::Compara::GeneAlign
  Exceptions :
  Caller     :

=cut

sub new {
    my($class,@args) = @_;

    my $self = $class->SUPER::new(@args);

    if (scalar @args) {
        my ($gene_align_id) = rearrange([qw(GENE_ALIGN_ID)], @args);

        $gene_align_id && $self->gene_align_id($gene_align_id);
    }

    return $self;
}


#####################
# Object attributes #
#####################

=head2 gene_align_id

  Description : Getter/Setter for the gene_align_id field. This field would map
                to the gene_align / gene_align_member tables
  Returntype  : String
  Example     : my $aln_id = $tree->gene_align_id();
  Caller      : General

=cut

sub gene_align_id {
    my $self = shift;
    $self->{'_gene_align_id'} = shift if(@_);
    return $self->{'_gene_align_id'};
}


#######################
# MemberSet interface #
#######################

=head2 _attr_to_copy_list

  Description: Returns the list of all the attributes to be copied by deep_copy()
  Returntype : Array of String
  Caller     : General

=cut

sub _attr_to_copy_list {
    my $self = shift;
    my @sup_attr = $self->SUPER::_attr_to_copy_list();
    push @sup_attr, qw(_gene_align_id);
    return @sup_attr;
}


1;

