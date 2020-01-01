
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

Bio::EnsEMBL::Compara::RunnableDB::MemberIDRangeFactory

=head1 DESCRIPTION

This Analysis/RunnableDB defines range of member_ids of a requested size by
scanning the table by ascending order. Both the gene_member and seq_member
tables are supported.

It dataflows 1 job per chunk.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::MemberIDRangeFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $table       = $self->param_required('table');
    my $chunk_size  = $self->param_required('chunk_size');

    my $sql         = "SELECT ${table}_id FROM $table ORDER BY ${table}_id";
    my $sth         = $self->compara_dba->dbc->prepare( $sql, { 'mysql_use_result' => 1 } );

    my $count = 0;
    my $start_member_id;
    my $curr_member_id;

    $sth->execute();
    $sth->bind_columns( \$curr_member_id );

    my @chunks;
    while ($sth->fetch()) {
        $start_member_id //= $curr_member_id;
        $count++;
        if ($count == $chunk_size) {
            push @chunks, {"min_${table}_id" => $start_member_id, "max_${table}_id" => $curr_member_id};
            undef $start_member_id;
            $count = 0;
        }
    }
    $sth->finish;
    push @chunks, {"min_${table}_id" => $start_member_id, "max_${table}_id" => $curr_member_id} if $count;

    $self->param('chunks', \@chunks);
}


sub write_output {
    my $self = shift @_;

    $self->dataflow_output_id($self->param('chunks'), 2);
}

1;
