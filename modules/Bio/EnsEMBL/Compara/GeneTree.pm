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

Bio::EnsEMBL::Compara::GeneTree

=head1 DESCRIPTION

Class to represent a gene tree object. Contains a link to
the root of the tree, as long as general tree properties.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::GeneTree
  `- Bio::EnsEMBL::Compara::Taggable

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

package Bio::EnsEMBL::Compara::GeneTree;

use strict;

use base ('Bio::EnsEMBL::Compara::Taggable');


sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
    return $self;
}

sub tree_type {
    my $self = shift;
    $self->{'_tree_type'} = shift if(@_);
    return $self->{'_tree_type'};
}

sub clusterset_id {
    my $self = shift;
    $self->{'_clusterset_id'} = shift if(@_);
    return $self->{'_clusterset_id'};
}

sub method_link_species_set_id {
    my $self = shift;
    $self->{'_method_link_species_set_id'} = shift if(@_);
    return $self->{'_method_link_species_set_id'};
}


sub stable_id {
    my $self = shift;
    $self->{'_stable_id'} = shift if(@_);
    return $self->{'_stable_id'};
}

sub version {
    my $self = shift;
    $self->{'_version'} = shift if(@_);
    return $self->{'_version'};
}

sub root {
    my $self = shift;
    $self->{'_root'} = shift if(@_);
    return $self->{'_root'};
}

sub adaptor {
    my $self = shift;
    $self->{'_adaptor'} = shift if(@_);
    return $self->{'_adaptor'};
}





sub root_id {
    my $self = shift;
    my $root = $self->root;
    return $root->node_id if defined $root;
}

1;

