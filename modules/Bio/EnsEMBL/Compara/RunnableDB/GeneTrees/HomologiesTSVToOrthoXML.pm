=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::HomologiesTSVToOrthoXML

=head1 SYNOPSIS



=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::HomologiesTSVToOrthoXML;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::ApiVersion;

use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
        'high_confidence'   => 0,
        'ortholog_method_link_id' => 201,
        'hc_only' => 0,
    }
}

sub fetch_input {
    my $self = shift;

    return if $self->param('hc_only');
    # create mapping of seq_member stable_id
    my $sql = 'SELECT seq_member.stable_id, seq_member.taxon_id, name, seq_member_id, assembly, genebuild, source_name FROM seq_member JOIN genome_db USING (genome_db_id)';
    # $sql .= " WHERE seq_member.stable_id IN ('ENSAPOP00000034950','ENSAPEP00000008265','ENSACIP00000010104','ENSACLP00000033329','ENSAPOP00000017196','ENSAPOP00000001384')";
    # $sql .= ' GROUP BY taxon_id, seq_member_id';
    # print "fetching stable_id mapping from " . $self->compara_dba->dbc->url . "\n\n";
    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();
    my $mapping = $sth->fetchall_hashref('stable_id');
    $self->param('stable_id_mapping', $mapping);
}

sub run {
    my $self = shift;

    my $tsv_file = $self->param_required('tsv_file');
    my $xml_file = $self->param_required('xml_file');

    unless ( $self->param('hc_only') ) {
        my $stable_id_map = $self->param('stable_id_mapping');
        my $tmp_file_name = $self->param('high_confidence') ? "tmp_groups.strict.xml" : "tmp_groups.xml";
        my $tmp_groups_file = $self->param('hash_dir') . "/$tmp_file_name";
        print "\n  !! TMP_GROUPS_FILE: $tmp_groups_file !!\n\n";
        open(TMP_GROUPS, '>', $tmp_groups_file) or die "Cannot open tmp file '$tmp_groups_file' for writing\n";

        open( TSV,  '<', $tsv_file ) or die "Cannot open '$tsv_file'\n";

        my %species_and_genes;
        my @ortholog_groups;
        while( my $line = <TSV> ) {
            # my @parts = split(/\s+/, $line);
            my ($gene_stable_id, $protein_stable_id, $species, $identity, $homology_type, $homology_gene_stable_id, $homology_protein_stable_id,
            $homology_species, $homology_identity, $dn, $ds, $goc_score, $wga_coverage, $is_high_confidence, $homology_id) = split(/\s+/, $line);

            next if ($gene_stable_id eq 'gene_stable_id'); # header line - skip
            next unless $homology_type =~ /ortholog/;
            next if $self->param_required('high_confidence') && $is_high_confidence != 1;


            # grab and store list of species & genes
            my $seq1_info = $stable_id_map->{$protein_stable_id};
            my $seq2_info = $stable_id_map->{$homology_protein_stable_id};

            die "Cannot find info for $protein_stable_id\n" unless defined $seq1_info;
            die "Cannot find info for $homology_protein_stable_id\n" unless defined $seq2_info;

            my $species1_header = "<species name=\"" . $seq1_info->{name} . "\" NCBITaxId=\"" . $seq1_info->{taxon_id} . "\"><database name=\"Unknown\" version=\"" . $seq1_info->{assembly} . "/" . $seq1_info->{genebuild} . "\"><genes>";
            my $species2_header = "<species name=\"" . $seq2_info->{name} . "\" NCBITaxId=\"" . $seq2_info->{taxon_id} . "\"><database name=\"Unknown\" version=\"" . $seq2_info->{assembly} . "/" . $seq2_info->{genebuild} . "\"><genes>";

            my $gene1_info = "<gene id=\"" . $seq1_info->{seq_member_id} . "\" " . ($seq1_info->{source_name} =~ /PEP$/ ? "protId" : "transcriptId") . "=\"" . $seq1_info->{stable_id} . "\"/>";
            my $gene2_info = "<gene id=\"" . $seq2_info->{seq_member_id} . "\" " . ($seq2_info->{source_name} =~ /PEP$/ ? "protId" : "transcriptId") . "=\"" . $seq2_info->{stable_id} . "\"/>";
            $species_and_genes{$species1_header}->{$seq1_info->{seq_member_id}} = $gene1_info;
            $species_and_genes{$species2_header}->{$seq2_info->{seq_member_id}} = $gene2_info;

            # store homology pairs
            my $group_str = "<orthologGroup id=\"${homology_id}\"><property name=\"homology_description\" value=\"$homology_type\" /><geneRef id=\"" . $seq1_info->{seq_member_id} . "\" /> <geneRef id=\"" . $seq2_info->{seq_member_id} . "\" />";
            $group_str .= "<score id=\"dn\" value=\"$dn\" />" if defined $dn and $dn ne 'NULL';
            $group_str .= qq{ <score id=\"ds\" value=\"$ds\" />} if defined $ds and $ds ne 'NULL';
            $group_str .= qq{ <score id=\"goc_score\" value=\"$goc_score\" />} if defined $goc_score and $goc_score ne 'NULL';
            $group_str .= qq{ <score id=\"wga_coverage\" value=\"$wga_coverage\" />} if defined $wga_coverage and $wga_coverage ne 'NULL';
            $group_str .= qq{  </orthologGroup>\n};
            # push( @ortholog_groups, $str );
            print TMP_GROUPS $group_str;
        }
        close TSV;
        close TMP_GROUPS;

        # write OrthoXML
        open( XML,  '>', $xml_file ) or die "Cannot open '$xml_file'\n";
        my $version = software_version();
        print XML "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n";
        print XML "<orthoXML xmlns=\"http://orthoXML.org/2011/\" origin=\"Ensembl Compara\" version=\"0.3\" originVersion=\"$version\">\n";
        foreach my $species_header ( keys %species_and_genes ) {
            print XML "$species_header\n";
            print XML "\t" . join("\n\t", values %{ $species_and_genes{$species_header} }) . "\n";
            print XML "</genes></database></species>\n";
        }
        print XML "<groups>\n";
        open(TMP_GROUPS, '<', $tmp_groups_file);
        while ( my $group_line = <TMP_GROUPS> ) {
            print XML $group_line;
        }
        close TMP_GROUPS;
        print XML "</groups>\n</orthoXML>";
        close XML;

        unlink $tmp_groups_file;
    }

    $self->healthcheck_xml;

    print "OrthoXML file written to $xml_file\n";
}

sub healthcheck_xml {
    my $self = shift;
    my $xml_file = $self->param_required('xml_file');
    my $clusterset_id = $self->param_required('clusterset_id');
    my $member_type = $self->param_required('member_type');
    my $orth_ml_id = $self->param_required('ortholog_method_link_id');

    # check for truncated line near EOF
    my $tail_out = $self->get_command_output(['tail', '-3', $xml_file]);
    unless ( $tail_out =~ /<groups>\s+<\/groups>\s+<\/orthoXML>$/ ) { # allow for 'empty' XML
        die "Detected truncation at EOF in $xml_file:\n$tail_out\n\n" unless $tail_out =~ /<\/orthologGroup>\s+<\/groups>\s+<\/orthoXML>$/;
    }

    # need to get exp count from db, to filter on is_high_confidence!
    print "Counting expected orthologGroup entries..\n";
    my $exp_count_sql = "
    SELECT COUNT(*) FROM homology h
        JOIN gene_tree_root gtr ON h.gene_tree_root_id = gtr.root_id
    WHERE gtr.member_type = '$member_type'
        AND gtr.clusterset_id = '$clusterset_id'
        AND LEFT(h.description, 8) = 'ortholog'
    ";
    $exp_count_sql .= " and h.is_high_confidence = 1" if $self->param('high_confidence');
    my $sth = $self->compara_dba->dbc->prepare($exp_count_sql);
    $sth->execute();
    my $exp_count = $sth->fetchrow_arrayref->[0];

    print "Counting orthologGroup entries in XML..\n";
    my $xml_count_cmd = "grep -c orthologGroup $xml_file";
    my $xml_count_run = $self->run_command($xml_count_cmd); # can't use die_on_failure when result could be 0!
    die $xml_count_run->err if $xml_count_run->err;
    my $xml_count = $xml_count_run->out;
    chomp $xml_count;

    die "Found $xml_count orthologs written to XML file - expected $exp_count!\n" unless $xml_count == $exp_count;
}

1;
