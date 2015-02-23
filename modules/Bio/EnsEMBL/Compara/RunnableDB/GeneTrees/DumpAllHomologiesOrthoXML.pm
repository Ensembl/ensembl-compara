=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpAllHomologiesOrthoXML

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to dump all the homologies of a database
in a single file, with the OrthoXML format

It requires one parameter:
 - compara_db: connection parameters to the Compara database

The following parameters are optional:
 - file: [string] output file to dump (otherwise: standard output)

=head1 SYNOPSIS

standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpAllHomologiesOrthoXML
  -compara_db 'mysql://ensro:@compara4:3306/mp12_compara_nctrees_66c'

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpAllHomologiesOrthoXML; 

use strict;

use IO::File;

use Bio::EnsEMBL::ApiVersion;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        "ortholog_method_link_id"   => 201,
        "strict_orthologies"        => 0,
           };
}


sub fetch_input {
    my ($self) = @_;

    # Defines the file handle
    my $file_handle = *STDOUT;
    if (defined $self->param('file')) {
        $file_handle = IO::File->new( $self->param('file'), 'w');
    }
    $self->param('file_handle', $file_handle);
}


sub run {
    my ($self) = @_;
    my $HANDLE = $self->param('file_handle');

    my $version = software_version();
    print $HANDLE "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
    print $HANDLE "<orthoXML xmlns=\"http://orthoXML.org/2011/\" origin=\"Ensembl Compara\" version=\"0.3\" originVersion=\"$version\">\n";

    my $sql = 'SELECT seq_member.taxon_id, name, seq_member_id, seq_member.stable_id, assembly, genebuild,source_name FROM gene_tree_root JOIN gene_tree_node USING (root_id) JOIN seq_member USING (seq_member_id) JOIN genome_db USING (genome_db_id) WHERE clusterset_id = "default" GROUP BY taxon_id, seq_member_id';
    my $sth = $self->compara_dba->dbc->prepare($sql, { 'mysql_use_result' => 1 });
    $sth->execute;
    my $last;
    while(my $rowhash = $sth->fetchrow_hashref) {
        if (not defined $last or $last ne ${$rowhash}{taxon_id}) {
            print $HANDLE "</genes></database></species>\n" if defined $last;
            $last = ${$rowhash}{taxon_id};
            print $HANDLE "<species name=\"", ${$rowhash}{name}, "\" NCBITaxId=\"", $last, "\"><database name=\"Unknown\" version=\"", ${$rowhash}{assembly}, "/", ${$rowhash}{genebuild}, "\"><genes>\n";
        }
        print $HANDLE "\t<gene id=\"", ${$rowhash}{seq_member_id}, "\" ".(${$rowhash}{source_name} =~ /PEP$/ ? "protId" : "transcriptId")."=\"", ${$rowhash}{stable_id}, "\"/>\n";
    }
    print $HANDLE "</genes></database></species>\n" if defined $last;
    print $HANDLE "<groups>\n";

    $sql = "SELECT homology_id, seq_member_id, homology.description FROM homology_member JOIN homology USING (homology_id) JOIN method_link_species_set USING (method_link_species_set_id) WHERE method_link_id=".$self->param('ortholog_method_link_id');
    if (defined $self->param('id_range')) {
        my $range = $self->param('id_range');
        $range =~ s/-/ AND /;
        $sql .= " AND homology_id BETWEEN $range";
    }
    if ($self->param('strict_orthologies')) {
        $sql .= " AND is_tree_compliant = 1";
    }
    $sth = $self->compara_dba->dbc->prepare($sql, { 'mysql_use_result' => 1 });

    $sth->execute;
    my %seen;
    while(my $rowhash = $sth->fetchrow_hashref) {
        if (exists $seen{${$rowhash}{homology_id}}) {
            print $HANDLE "<orthologGroup id=\"", ${$rowhash}{homology_id}, "\"><property name=\"homology_description\" value=\"", ${$rowhash}{description}, "\" /><geneRef id=\"", ${$rowhash}{seq_member_id}, "\" /><geneRef id=\"", $seen{${$rowhash}{homology_id}}, "\" /></orthologGroup>\n";
            delete $seen{${$rowhash}{homology_id}};
        } else {
            $seen{${$rowhash}{homology_id}} = ${$rowhash}{seq_member_id};
        }
    }
    
    print $HANDLE "</groups>\n";
    print $HANDLE "</orthoXML>";

}

sub write_output {
    my ($self) = @_;
    $self->param('file_handle')->close();
}


1;
