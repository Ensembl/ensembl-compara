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

=cut

# POD documentation - main docs before the code
=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::MapAnchorsFactory

=head1 SYNOPSIS

$exonate_anchors->fetch_input();
$exonate_anchors->write_output(); writes to disc and database

=head1 DESCRIPTION

Module to dump the genome sequences of a given set of species to disc.
It will also set up the jobs for mapping of anchors to those genomes if 
an anchor_batch_size is specified in the pipe-config file.  

=head1 AUTHOR - compara

This modules is part of the Ensembl project http://www.ensembl.org

Email http://lists.ensembl.org/mailman/listinfo/dev

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
http://lists.ensembl.org/mailman/listinfo/dev


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::MapAnchorsFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub run {
    my ($self) = @_;
    my $batch_size = $self->param_required('anchor_batch_size');
    die "'anchor_batch_size' must be non-zero\n" unless $batch_size;
    my $anchor_dba = $self->get_cached_compara_dba('compara_anchor_db');
    my $sth = $anchor_dba->dbc->prepare("SELECT anchor_id, COUNT(*) AS num_seq FROM anchor_sequence GROUP BY anchor_id ORDER BY anchor_id");
    $sth->execute();
    my $count = 0;
    my @anchor_ids;
    my $min_anchor_id;
    my $max_anchor_id;
    while( my $ref = $sth->fetchrow_arrayref() ){
        if ($count) {
            if (($count+$ref->[1]) > $batch_size) {
                push @anchor_ids, { 'min_anchor_id' => $min_anchor_id, 'max_anchor_id' => $max_anchor_id };
                $count = 0;
            }
        }
        $min_anchor_id = $ref->[0] unless $count;
        $max_anchor_id = $ref->[0];
        $count += $ref->[1];
    }
    if ($count) {
        push @anchor_ids, { 'min_anchor_id' => $min_anchor_id, 'max_anchor_id' => $max_anchor_id };
    }
    $self->param('anchor_id_intervals', \@anchor_ids);
}

sub write_output {
	my ($self) = @_;
	$self->dataflow_output_id( $self->param('anchor_id_intervals'), 2);
}

1;

