=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

Bio::EnsEMBL::Compara::Production::EPOanchors::CheckDnaFragReusability

=head1 DESCRIPTION

This Runnable checks whether a certain genome_db data can be reused for the purposes of EPO pipeline by
checking whether the DnaFrags are the same.

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::CheckDnaFragReusability;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::CheckGenomeReusability');


sub run_comparison {
    my $self = shift @_;

    return $self->do_one_comparison('dnafrags',
        $self->hash_all_dnafrags_from_dba( $self->param('reuse_dba') ),
        $self->hash_all_dnafrags_from_dba( $self->compara_dba ),
    );
}


sub hash_all_dnafrags_from_dba {
    my $self = shift;
    my $dba = shift @_;

    my $sql = q{
        SELECT CONCAT_WS(':', dnafrag_id, length, name, coord_system_name)
          FROM dnafrag
         WHERE genome_db_id = ?
           AND is_reference = 1
    };

    return $self->hash_rows_from_dba($dba, $sql, $self->param('genome_db_id'));
}

1;
