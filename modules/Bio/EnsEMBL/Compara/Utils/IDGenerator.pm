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

=head1 DESCRIPTION

Helper function to assign unique numeric identifiers even when the data are
not stored in the database. This is primarily intended for pipelines that
first store their data in flat files and load them later into the database.

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
    initialise_id
    get_id_range
);
%EXPORT_TAGS = (
  all     => [@EXPORT_OK]
);


=head2 initialise_id

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBConnection $dbc
  Arg[2]      : String $label
  Arg[3]      : Integer $first_id. Defaults to 1
  Example     : initialise_id($dbc, 'homology', "${offset}00000001");
  Description : Set the first dbID of this label, if it hasn't been set
                before
  Returntype  : - undef if there has been an error
                - "0E0" if the label was already initialised
                - 1 if the label could be initialised

=cut

sub initialise_id {
    my ($dbc, $label, $first_id) = @_;
    return $dbc->do(
        'INSERT IGNORE INTO id_generator (label, next_id) VALUES (?, ?)',
        undef,
        $label,
        $first_id || 1,
    );
}


=head2 get_id_range

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBConnection $dbc
  Arg[2]      : String $label
  Arg[3]      : (optional) Integer $n_ids. Defaults to 1
  Arg[4]      : (optional) Integer $requestor
  Example     : my $homology_id_start = get_id_range($dbc, 'homology', 1623);
                my $gene_tree_id = get_id_range($dbc, 'gene_tree');
  Description : Request a new range of $n_ids IDs. The method returns the
                first integer of the range, and the caller can assume that
                all integers between this value and the value plus $n_ids
                minus 1 (both boundaries included) are now allocated to it.
                When $requestor is given, the assignment will be recorded
                in the database, so that further calls with the same
                requestor identifier (and a compatible $n_ids) will return
                the same start ID. This is useful when rerunning jobs.
                The IDs are recorded in a table and the method can be
                called by concurrent jobs.
  Returntype  : Integer
  Exceptions  : none

=cut

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
    initialise_id($dbc, $label);

    # Increment the ID whilst recording the previous value
    $dbc->do(
        'UPDATE id_generator SET next_id = LAST_INSERT_ID(next_id) + ? WHERE label = ?',
        undef,
        $n_ids, $label,
    );

    # Recall the value before it got incremented
    my $next_id = $dbc->db_handle->last_insert_id(undef, undef, undef, undef);

    # Register the attempt
    if ($requestor) {
        single_insert($dbc, 'id_assignments', [ $label, $requestor, $next_id, $n_ids, ]);
    }

    return $next_id;
}

1;
