=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpAllTreesOrthoXML

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to dump all the trees of a database
in a single file, with the OrthoXML format

It requires one parameter:
 - compara_db: connection parameters to the Compara database

The following parameters are optional:
 - file: [string] output file to dump (otherwise: standard output)

=head1 SYNOPSIS

standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpAllTreesOrthoXML
  -compara_db 'mysql://ensro:@compara4:3306/mp12_compara_nctrees_66c' -member_type ncrna -file dump_ncrna

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


package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpAllTreesOrthoXML; 

use strict;

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my ($self) = @_;

    # Defines the file handle
    my $file_handle = *STDOUT;
    if (defined $self->param('file')) {
        $file_handle = IO::File->new( $self->param('file'), 'w');
    }
    $self->param('file_handle', $file_handle);

    # Creates the OrthoXML writer
    my $w = Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter->new(
            -HANDLE => $self->param('file_handle'),
            -SOURCE => "Ensembl Compara",
            -SOURCE_VERSION => software_version(),
            );
    $self->param('writer', $w);

    # List of all the trees
    my $list_trees = $self->compara_dba->get_GeneTreeAdaptor->fetch_all(-clusterset_id => 'default', -member_type => $self->param('member_type'), -tree_type => 'tree');

    $self->param('tree_list', $list_trees);

}


sub run {
    my ($self) = @_;

    my $seq_member_adaptor = $self->compara_dba->get_SeqMemberAdaptor;
    my $callback_list_members = sub {
        my ($species) = @_;
        my $constraint = 'm.genome_db_id = '.($species->dbID);
        $constraint .= ' AND gtr.tree_type = "tree"';
        $constraint .= ' AND gtr.clusterset_id = "default"';
        $constraint .= ' AND gtr.member_type = "'.($self->param('member_type')).'"' if defined $self->param('member_type');
        my $join = [[['gene_tree_node', 'gtn'], 'm.member_id = gtn.member_id', undef], [['gene_tree_root', 'gtr'], 'gtn.root_id = gtr.root_id', undef]];
        return $seq_member_adaptor->generic_fetch($constraint, $join);
    };

    my $list_species = $self->compara_dba->get_GenomeDBAdaptor->fetch_all;
    # Launches the dump
    $self->param('writer')->write_data($list_species, $callback_list_members, $self->param('tree_list'));
}


sub write_output {
    my ($self) = @_;
    $self->param('writer')->finish();
    $self->param('file_handle')->close();
}


1;
