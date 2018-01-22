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
use warnings;

use IO::File;

use Bio::EnsEMBL::ApiVersion;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        "ortholog_method_link_id"   => 201,
        'high_confidence'           => 0,
        "clusterset_id"             => 'default',
        "member_type"               => 'protein',
           };
}


sub fetch_input {
    my ($self) = @_;

    # Defines the file handle
    my $file_handle = *STDOUT;
    if (defined $self->param('file')) {
        $file_handle = IO::File->new( $self->param('file'), 'w')
                        or die "Could not open file ".$self->param('file')." for writing: $!\n";
    }
    $self->param('file_handle', $file_handle);
}


sub run {
    my ($self) = @_;
    my $HANDLE = $self->param('file_handle');

    my $version = software_version();
    print $HANDLE "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
    print $HANDLE "<orthoXML xmlns=\"http://orthoXML.org/2011/\" origin=\"Ensembl Compara\" version=\"0.3\" originVersion=\"$version\">\n";

    my $sql = "SELECT seq_member.taxon_id, name, seq_member_id, seq_member.stable_id, assembly, genebuild,source_name
      FROM gene_tree_root JOIN gene_tree_node USING (root_id) JOIN seq_member USING (seq_member_id) JOIN genome_db USING (genome_db_id)
      WHERE clusterset_id = '".$self->param_required('clusterset_id')."'
      GROUP BY taxon_id, seq_member_id";
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

    $sql = sprintf(q{
                    SELECT
                        h.homology_id,
                        h.description,
                        hm1.seq_member_id,
                        hm2.seq_member_id,
                        h.dn,
                        h.ds,
                        h.goc_score,
                        h.wga_coverage
                    FROM
                        homology h
                        JOIN homology_member hm1 USING (homology_id)
                        JOIN homology_member hm2 USING (homology_id)
                        JOIN method_link_species_set USING (method_link_species_set_id)
                        JOIN gene_tree_root gtr ON h.gene_tree_root_id = gtr.root_id
                    WHERE
                        method_link_id = %d
                        AND hm1.seq_member_id < hm2.seq_member_id
                        AND gtr.member_type = "%s"
                        AND gtr.clusterset_id = "%s"
            }, $self->param_required('ortholog_method_link_id'), $self->param_required('member_type'), $self->param_required('clusterset_id'));

    if (defined $self->param('min_hom_id')) {
        $sql .= " AND homology_id >= ".$self->param('min_hom_id');
    }
    if (defined $self->param('max_hom_id')) {
        $sql .= " AND homology_id <= ".$self->param('max_hom_id');
    }
    if ($self->param_required('high_confidence')) {
        $sql .= " AND is_high_confidence = 1";
    }
    $sth = $self->compara_dba->dbc->prepare($sql, { 'mysql_use_result' => 1 });

    $sth->execute;

    my ($homology_id, $description, $seq_member_id1, $seq_member_id2, $dn, $ds, $goc_score, $wga_coverage );
    $sth->bind_columns(\$homology_id, \$description, \$seq_member_id1, \$seq_member_id2, \$dn, \$ds, \$goc_score, \$wga_coverage);

    while ($sth->fetch()) {
        my $str = qq{<orthologGroup id="${homology_id}"><property name="homology_description" value="${description}" /><geneRef id="${seq_member_id1}" /> <geneRef id="${seq_member_id2}" />};
        $str .= qq{ <score id="dn" value="${dn}" />} if defined $dn;
        $str .= qq{ <score id="ds" value="${ds}" />} if defined $ds;
        $str .= qq{ <score id="goc_score" value="${goc_score}" />} if defined $goc_score;
        $str .= qq{ <score id="wga_coverage" value="${wga_coverage}" />} if defined $wga_coverage;
        $str .= qq{  </orthologGroup>\n};
        print $HANDLE $str;
    }
    
    print $HANDLE "</groups>\n";
    print $HANDLE "</orthoXML>";

}

sub write_output {
    my ($self) = @_;
    $self->param('file_handle')->close();
}


1;
