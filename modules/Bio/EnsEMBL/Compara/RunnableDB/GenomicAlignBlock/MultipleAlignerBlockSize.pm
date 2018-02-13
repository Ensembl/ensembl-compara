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

my $sql_num_blocks = q{
REPLACE INTO method_link_species_set_tag
	SELECT method_link_species_set_id, CONCAT("num_blocks_",POW(10,FLOOR(LOG10(length)))) AS tag, COUNT(*) AS value
	FROM genomic_align_block
        WHERE method_link_species_set_id = #mlss_id#
	GROUP BY tag;
};

my $sql_totlength = q{
REPLACE INTO method_link_species_set_tag
	SELECT method_link_species_set_id, CONCAT("totlength_blocks_",POW(10,FLOOR(LOG10(length)))) AS tag, SUM(length) AS value
	FROM genomic_align_block
        WHERE method_link_species_set_id = #mlss_id#
	GROUP BY tag;
};

sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },
        'sql'   => [ $sql_num_blocks, $sql_totlength ],
    }
}

1;
