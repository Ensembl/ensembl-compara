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

Bio::EnsEMBL::Compara::DBSQL::DnaFragAltRegionAdaptor

=head1 DESCRIPTION

Database adaptor for the C<dnafrag_alt_region> table.

It is a very simple adaptor that only provides basic fetch and store
functionality.

=cut



package Bio::EnsEMBL::Compara::DBSQL::DnaFragAltRegionAdaptor;

use strict;
use warnings;

use DBI qw(:sql_types);

use base qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);


########################################################
# Implements Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor #
########################################################

## For generic_fetch*

sub _tables {
    return (['dnafrag_alt_region','dar'])
}


sub _columns {
    return qw (
        dar.dnafrag_id
        dar.dnafrag_start
        dar.dnafrag_end
    );
}


sub _objs_from_sth {
    my ($self, $sth) = @_;

    return $self->generic_objs_from_sth($sth, 'Bio::EnsEMBL::Compara::Locus', [
            'dnafrag_id',
            'dnafrag_start',
            'dnafrag_end',
        ],
        sub {
            return {
                'dnafrag_strand' => 1,
            }
        } );
}


#################
# Store methods #
#################

sub store_or_update {
    my ($self, $locus) = @_;

    $self->bind_param_generic_fetch($locus->dnafrag_id, SQL_INTEGER);
    my $is_already = $self->generic_count('dar.dnafrag_id = ?');

    if ($is_already) {

        $self->generic_update('dnafrag_alt_region',
            {
                'dnafrag_start' => $locus->dnafrag_start,
                'dnafrag_end'   => $locus->dnafrag_end,
            },
            {
                'dnafrag_id'    => $locus->dnafrag_id,
            } );

    } else {

        $self->generic_insert('dnafrag_alt_region', {
                'dnafrag_id'    => $locus->dnafrag_id,
                'dnafrag_start' => $locus->dnafrag_start,
                'dnafrag_end'   => $locus->dnafrag_end,
            });
    }
}

sub delete_by_dbID {
    my ($self, $dnafrag_id) = @_;

    throw("id argument is required") if (!defined $dnafrag_id);

    my ($name, $syn) = @{ ($self->_tables)[0] };
    my $delete_sql = qq{DELETE FROM $name WHERE dnafrag_id = ?};

    $self->dbc->do($delete_sql, undef, $dnafrag_id);
}


#################
# Fetch methods #
#################

## The default implementations expect the dbID column to be "${table}_id"
## which is not the case here.

=head2 fetch_by_dbID

  Arg[1]     : int $dnafrag_id
  Example    : $dnafrag_alt_region = $dar_adaptor->fetch_by_dbID(3);
  Description: Fetches from the database the DnaFrag alternative region for that
               DnaFrag ID
  Returntype : Bio::EnsEMBL::Compara::Locus
  Exceptions : returns undef if $dnafrag_id is not found

=cut

sub fetch_by_dbID {
    my ($self, $dnafrag_id) = @_;

    $self->bind_param_generic_fetch($dnafrag_id, SQL_INTEGER);
    return $self->generic_fetch_one('dar.dnafrag_id = ?');
}


=head2 fetch_all_by_dbID_list

  Arg [1]    : Arrayref of $dnafrag_ids
  Example    : $dnafrag_alt_regions = $dar_adaptor->fetch_all_by_dbID_list([$dnafrag_id1, $dnafrag_id2]);
  Description: Returns all the DnaFrag alternative region objects for the
               given DnaFrag IDs
  Returntype : Arrayref of Bio::EnsEMBL::Compara::Locus

=cut

sub fetch_all_by_dbID_list {
    my ($self, $dnafrag_ids) = @_;

    return [] unless scalar(@$dnafrag_ids);

    return $self->generic_fetch_concatenate($dnafrag_ids, 'dar.dnafrag_id', SQL_INTEGER);
}


1;
