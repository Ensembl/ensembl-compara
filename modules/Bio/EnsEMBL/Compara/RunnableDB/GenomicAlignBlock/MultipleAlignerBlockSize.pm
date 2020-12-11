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

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::MultipleAlignerBlockSize

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

The RunnableDB module runs two INSERT statements to populate the block-size distribution tags

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::MultipleAlignerBlockSize;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::SqlCmd');

my $sql_drop_temp_table = q{
DROP TABLE IF EXISTS temp_block_list;
};

my $sql_create_temp_table_all = q{
CREATE TEMPORARY TABLE temp_block_list
       SELECT length
       FROM genomic_align_block
       WHERE method_link_species_set_id = #mlss_id#
};

my $sql_create_temp_table_no_anc = $sql_create_temp_table_all . q{
 AND genomic_align_block_id NOT IN (
       SELECT DISTINCT genomic_align_block_id
       FROM genomic_align JOIN dnafrag USING (dnafrag_id)
       WHERE coord_system_name = "ancestralsegment"
     )
};

my $sql_del_dist_num_blocks = q{
DELETE FROM method_link_species_set_tag
WHERE method_link_species_set_id = #mlss_id#
      AND tag LIKE "num\_blocks\_%"
};

my $sql_dist_num_blocks = q{
INSERT INTO method_link_species_set_tag
	SELECT #mlss_id#, CONCAT("num_blocks_",POW(10,FLOOR(LOG10(length)))) AS tag, COUNT(*) AS value
	FROM temp_block_list
	GROUP BY tag;
};

my $sql_del_dist_block_length = q{
DELETE FROM method_link_species_set_tag
WHERE method_link_species_set_id = #mlss_id#
      AND tag LIKE "totlength\_blocks\_%"
};

my $sql_dist_block_length = q{
INSERT INTO method_link_species_set_tag
	SELECT #mlss_id#, CONCAT("totlength_blocks_",POW(10,FLOOR(LOG10(length)))) AS tag, SUM(length) AS value
	FROM temp_block_list
	GROUP BY tag;
};

my $sql_tot_num_blocks = q{
REPLACE INTO method_link_species_set_tag
        SELECT #mlss_id#, 'num_blocks', COUNT(*)
        FROM temp_block_list;
};

my @base_sqls = ($sql_del_dist_num_blocks, $sql_dist_num_blocks, $sql_del_dist_block_length, $sql_dist_block_length, $sql_tot_num_blocks);

sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },
        'sql_standard'  => [ $sql_drop_temp_table, $sql_create_temp_table_all,    @base_sqls, $sql_drop_temp_table],
        'sql_epo'       => [ $sql_drop_temp_table, $sql_create_temp_table_no_anc, @base_sqls, $sql_drop_temp_table ],
    }
}

sub fetch_input {
    my ($self) = @_;

    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlss_adaptor->fetch_by_dbID($self->param_required('mlss_id'));

    # EPO alignments have blocks for the ancestral sequences
    if ($mlss->method->class eq 'GenomicAlignTree.ancestral_alignment') {
        $self->param('sql', $self->param_required('sql_epo'));
    } else {
        $self->param('sql', $self->param_required('sql_standard'));
    }

    $self->SUPER::fetch_input();
}

1;
