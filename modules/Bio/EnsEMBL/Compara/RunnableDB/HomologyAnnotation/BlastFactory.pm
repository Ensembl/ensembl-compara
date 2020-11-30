=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::BlastFactory

=head1 DESCRIPTION

Fetch list of member_ids per genome_db_id in db and create jobs for BlastAndParsePAF.
=over

=item step
Optional. How many sequences to write into the blast query file. Default: 200.

=back
=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::BlastFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Data::Dumper;

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'step' => 200,
        'taxon_list' => qw(Eukaryota, Metazoa, Chordata, Vertebrata, Plants, Fungi, Bacteria, Protists),
    };
}


sub fetch_input {
    my $self = shift @_;

    my $genome_dbs = $self->compara_dba->get_GenomeDBAdaptor->fetch_all();
    my ( @genome_db_ids, @query_members );

    foreach my $genome_db (@$genome_dbs) {
        my $genome_db_id = $genome_db->dbID;
        my $some_members = $self->compara_dba->get_SeqMemberAdaptor->_fetch_all_representative_for_blast_by_genome_db_id($genome_db_id);
        my @mlsss        = @{$self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type_GenomeDB('ENSEMBL_HOMOLOGUES', $genome_db)};
        $self->warning("There are multiple mlsss for $genome_db ENSEMBL_HOMOLOGUES when we only expect 1") if (scalar(@mlsss) > 1);
        my @genome_members;

        foreach my $member (@$some_members) {
            my $member_id = $member->dbID;
            push @genome_members, $member_id;
        }

        push @query_members, { 'genome_db_id' => $genome_db_id, 'mlss_id' => $mlsss[0]->dbID, 'member_ids' => \@genome_members, 'ref_taxa' => $self->_collect_classification_match($genome_db) };
    }

    $self->param('query_members', \@query_members);
}

sub write_output {
    my $self = shift @_;

    my $step              = $self->param('step');
    my @query_member_list = @{$self->param('query_members')};

    foreach my $genome ( @query_member_list ) {

        my $genome_db_id  = $genome->{'genome_db_id'};
        my $mlss_id       = $genome->{'mlss_id'};
        my $query_members = $genome->{'member_ids'};
        my $ref_taxa      = $genome->{'ref_taxa'};

        while (@$query_members) {
            my @job_array = splice(@$query_members, 0, $step);
            #my $output_id = { 'member_id_list' => \@job_array, 'genome_db_id' => $genome_db_id, 'mlss_id' => $mlss_id, 'ref_taxa' => $ref_taxa}; # With genome_db_id to send to per-genome peptide_align_feature tables
            my $output_id = { 'member_id_list' => \@job_array, 'mlss_id' => $mlss_id, 'ref_taxa' => $ref_taxa };
            $self->dataflow_output_id($output_id, 2);
        }
        $self->dataflow_output_id( { 'genome_db_id' => $genome_db_id, 'ref_taxa' => $ref_taxa }, 1 );
    }
}

sub _collect_classification_match {
    my ($self, $genome_db) = shift @_;

    my @taxon_list = @{$self->param('taxon_list')};
    my $taxon_dba  = $self->compara_dba->get_NCBITaxonAdaptor;
    my $parent     = $taxon_dba->fetch_by_dbID($genome_db->taxon_id);

    foreach my $taxa_name ( @taxon_list ) {
        my @taxon_ids = @{ $taxon_dba->fetch_all_nodes_by_name($taxa_name.'%') }
        if ( any { $_ eq $parent->dbID } @taxon_ids ) {
            return $taxa_name;
        }
    }
    return undef;

}

1;
