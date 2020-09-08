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

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::Utils::IDGenerator;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::CopyData qw(:insert);

use base qw(Exporter);

our %EXPORT_TAGS;
our @EXPORT_OK;

@EXPORT_OK = qw(
    get_id_range
);
%EXPORT_TAGS = (
  all     => [@EXPORT_OK]
);


sub get_id_range {
    my ($dbc, $label, $n_ids, $requestor) = @_;

    $n_ids //= 1;
    die "Can only request a positive number of IDs" if $n_ids <= 0;

    # Check whether we have already seen this requestor
    if ($requestor) {
        my $existing_row = $dbc->db_handle->selectrow_arrayref(
            'SELECT assigned_id, size FROM id_assignments WHERE label = ? AND requestor = ?',
            undef,
            $label, $requestor,
        );
        if ($existing_row) {
            # This requestor has already placed its request, let's check if the interval was big enough
            return $existing_row->[0] if $existing_row->[1] >= $n_ids;
            # If not, forget about the previous request
            $dbc->do(
                'DELETE FROM id_assignments WHERE label = ? AND requestor = ?',
                undef,
                $label, $requestor,
            );
        }
    }

    # First insert the initial value if needed
    $dbc->do(
        'INSERT IGNORE INTO id_generator (label, next_id) VALUES (?, 1)',
        undef,
        $label,
    );

    # Increment the ID whilst recording the previous value
    $dbc->do(
        'UPDATE id_generator SET next_id = LAST_INSERT_ID(next_id) + ? WHERE label = ?',
        undef,
        $n_ids, $label,
    );

    # Recall the value before it got incremented
    my $next_id = $dbc->db_handle->last_insert_id();

    # Register the attempt
    if ($requestor) {
        single_insert($dbc, 'id_assignments', [ $label, $requestor, $next_id, $n_ids, ]);
    }

    return $next_id;
}

1;
