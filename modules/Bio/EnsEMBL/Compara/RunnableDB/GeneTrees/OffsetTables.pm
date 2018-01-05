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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OffsetTables

=head1 SYNOPSIS

Simple Runnable based on eHive's SqlCmd that offsets all the gene-related tables

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::OffsetTables;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::SqlCmd');


sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },
        'range_index'   => 1,
        'offset'        => '#range_index#00000001',
        'sql'           => [
                    'ALTER TABLE homology          AUTO_INCREMENT=#offset#',
                    'ALTER TABLE gene_align        AUTO_INCREMENT=#offset#',
                    'ALTER TABLE gene_tree_node    AUTO_INCREMENT=#offset#',
                    'ALTER TABLE CAFE_gene_family  AUTO_INCREMENT=#offset#',
                ],
    }
}

1;
