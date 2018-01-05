=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

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

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpAllTreesOrthoXML; 

use strict;
use warnings;

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Compara::Graph::OrthoXMLWriter;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my ($self) = @_;

    # Defines the file handle
    my $file_handle = *STDOUT;
    if (defined $self->param('file')) {
        $file_handle = IO::File->new( $self->param('file'), 'w')
                        or die "Could not open file ".$self->param('file')." for writing: $!\n";
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
    my $list_trees = $self->compara_dba->get_GeneTreeAdaptor->fetch_all(-clusterset_id => $self->param('clusterset_id'), -member_type => $self->param('member_type'), -tree_type => 'tree');

    $self->param('tree_list', $list_trees);

}


sub run {
    my ($self) = @_;

    my $seq_member_adaptor = $self->compara_dba->get_SeqMemberAdaptor;
    my $callback_list_members = sub {
        my ($species) = @_;
        my $constraint = 'm.genome_db_id = '.($species->dbID);
        $constraint .= ' AND gtr.tree_type = "tree"';
        $constraint .= ' AND gtr.clusterset_id = "'.($self->param('clusterset_id')).'"' if defined $self->param('clusterset_id');
        $constraint .= ' AND gtr.member_type = "'.($self->param('member_type')).'"' if defined $self->param('member_type');
        my $join = [[['gene_tree_node', 'gtn'], 'm.seq_member_id = gtn.seq_member_id', undef], [['gene_tree_root', 'gtr'], 'gtn.root_id = gtr.root_id', undef]];
        return $seq_member_adaptor->generic_fetch($constraint, $join);
    };

    my $list_species = $self->compara_dba->get_GenomeDBAdaptor->fetch_all;
    # Launches the dump
    $self->param('writer')->_write_data($list_species, $callback_list_members, $self->param('tree_list'));
}


sub write_output {
    my ($self) = @_;
    $self->param('writer')->finish();
    $self->param('file_handle')->close();
}


1;
