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

Bio::EnsEMBL::Hive::RunnableDB::GeneTrees::DumpHomologiesTSV

=head1 DESCRIPTION

This RunnableDB module dumps homologies in TSV format. It is able to dump
either all the homologies or only the ones of a certain genome_db_id.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpHomologiesTSV;

use strict;
use warnings;

use File::Basename qw/dirname/;
use File::Path qw/make_path/;

use base ('Bio::EnsEMBL::Hive::RunnableDB::DbCmd');


sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },

        # There is too much cache to afford caching it client-side
        'append'        => [qw(-q)],

        # By default empty, but can be used to filter on a genome_db_id
        'extra_filter'  => '',

        # The base query
        'input_query'   => sprintf q|
                    SELECT
                        gm1.stable_id AS gene_stable_id,
                        sm1.stable_id AS protein_stable_id,
                        gdb1.name AS species,
                        hm1.perc_id AS identity,
                        h.description AS homology_type,
                        gm2.stable_id AS homology_gene_stable_id,
                        sm2.stable_id AS homology_protein_stable_id,
                        gdb2.name AS homology_species,
                        hm2.perc_id AS homology_identity,
                        h.dn,
                        h.ds,
                        h.goc_score,
                        h.wga_coverage
                    FROM
                        homology h
                        JOIN (homology_member hm1 JOIN gene_member gm1 USING (gene_member_id) JOIN genome_db gdb1 USING (genome_db_id) JOIN seq_member sm1 USING (seq_member_id)) USING (homology_id)
                        JOIN (homology_member hm2 JOIN gene_member gm2 USING (gene_member_id) JOIN genome_db gdb2 USING (genome_db_id) JOIN seq_member sm2 USING (seq_member_id)) USING (homology_id)
                    WHERE
                        homology_id BETWEEN #min_hom_id# AND #max_hom_id#
                        AND hm1.gene_member_id != hm2.gene_member_id
                        #extra_filter#
                |,

    }
}

sub fetch_input {
    my $self = shift;

    if (my $genome_db_id = $self->param('genome_db_id')) {
        my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $self->data_dbc );
        my $genome_db   = $compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
        my $name        = $genome_db->name;

        if ($genome_db->db_adaptor->is_multispecies()) {
            $name = $1.'/'.$name if $genome_db->db_adaptor->dbc->dbname() =~ /(.+)\_core/;
        }
        $self->param('species_name', $name);
        $self->param('extra_filter', 'AND gm1.genome_db_id = '.$genome_db_id);

        make_path(dirname($self->param('output_file')));
    }

    $self->SUPER::fetch_input();
}

1;
