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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpAllHomologiesOrthoXML

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to dump all the homologies of a database
in a single file, with the OrthoXML format

It requires one parameter:
 - compara_db: connection parameters to the Compara database

The following parameters are optional:
 - tree_type: [string] restriction on which trees should be dumped (see the
              corresponding field in the gene_tree_root table)
 - possible_ortho: [boolean] (default 0) whether or not low confidence
                   duplications should be treated as speciations
 - file: [string] output file to dump (otherwise: standard output)

=head1 SYNOPSIS

standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpAllHomologiesOrthoXML
  -compara_db 'mysql://ensro:@compara4:3306/mp12_compara_nctrees_66c'

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


package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpAllHomologiesOrthoXML; 

use strict;

use IO::File;

use Bio::EnsEMBL::ApiVersion;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        "ortholog_method_link_id" => 201,
           };
}


sub fetch_input {
    my ($self) = @_;

    # Defines the file handle
    my $file_handle = *STDOUT;
    if (defined $self->param('file')) {
        $file_handle = IO::File->new($self->param_substitute($self->param('file')), 'w');
    }
    $self->param('file_handle', $file_handle);
}


sub run {
    my ($self) = @_;
    my $HANDLE = $self->param('file_handle');

    my $version = software_version();
    print $HANDLE "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
    print $HANDLE "<orthoXML xmlns=\"http://orthoXML.org/2011/\" origin=\"Ensembl Compara\" version=\"0.3\" originVersion=\"$version\">\n";

    my $sql = 'SELECT member.taxon_id, name, member_id, stable_id, assembly, genebuild,source_name FROM gene_tree_member JOIN member USING (member_id) JOIN genome_db USING (genome_db_id) ORDER BY taxon_id, member_id';
    my $sth = $self->compara_dba->dbc->prepare($sql, {mysql_use_result=>1});
    $sth->execute;
    my $last;
    while(my $rowhash = $sth->fetchrow_hashref) {
        if (not defined $last or $last ne ${$rowhash}{taxon_id}) {
            print $HANDLE "</genes></database></species>\n" if defined $last;
            $last = ${$rowhash}{taxon_id};
            print $HANDLE "<species name=\"", ${$rowhash}{name}, "\" NCBITaxId=\"", $last, "\"><database name=\"Unknown\" version=\"", ${$rowhash}{assembly}, "/", ${$rowhash}{genebuild}, "\"><genes>\n";
        }
        print $HANDLE "\t<gene id=\"", ${$rowhash}{member_id}, "\" ".(${$rowhash}{source_name} eq 'ENSEMBLPEP' ? "protId" : "transcriptId")."=\"", ${$rowhash}{stable_id}, "\"/>\n";
    }
    print $HANDLE "</genes></database></species>\n" if defined $last;
    print $HANDLE "<groups>\n";

    $sql = "SELECT homology_id, member_id, homology.description FROM homology_member JOIN homology USING (homology_id) JOIN method_link_species_set USING (method_link_species_set_id) WHERE method_link_id=".$self->param('ortholog_method_link_id');
    if (defined $self->param('id_range')) {
        my $range = $self->param_substitute($self->param('id_range'));
        $range =~ s/-/ AND /;
        $sql .= " AND homology_id BETWEEN $range";
    }
    $sth = $self->compara_dba->dbc->prepare($sql, {mysql_use_result=>1});

    $sth->execute;
    my %seen;
    while(my $rowhash = $sth->fetchrow_hashref) {
        if (exists $seen{${$rowhash}{homology_id}}) {
            print $HANDLE "<orthologGroup id=\"", ${$rowhash}{homology_id}, "\"><property name=\"homology_description\" value=\"", ${$rowhash}{description}, "\" /><geneRef id=\"", ${$rowhash}{member_id}, "\" /><geneRef id=\"", $seen{${$rowhash}{homology_id}}, "\" /></orthologGroup>\n";
            delete $seen{${$rowhash}{homology_id}};
        } else {
            $seen{${$rowhash}{homology_id}} = ${$rowhash}{member_id};
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
