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

=head1 DESCRIPTION

This modules contains common methods used when dealing with Core DBAdaptor
objects. The first section has methods that are general, whilst the second
section has methods that pretend to be part of the Bio::EnsEMBL::DBSQL::DBAdaptor
package (i.e. they can be called directly on $genome_db->db_adaptor):

- assembly_name: returns the assembly name
- locator: builds a Locator string

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;

use strict;
use warnings;

use DBI qw(:sql_types);

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Slice;
use Bio::EnsEMBL::DBSQL::ProxyDBConnection;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Iterator;

use Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::Utils::Scalar qw(:iterator);

my %share_dbcs;

=head2 pool_all_DBConnections

  Example     : $Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor->pool_all_DBConnections();
  Description : Create new ProxyDBConnections objects so that all the Core adaptors share
                the same underlying connection
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub pool_all_DBConnections {
    my $self = shift;

    foreach my $dba (@{Bio::EnsEMBL::Registry->get_all_DBAdaptors}) {
        $self->pool_one_DBConnection($dba);
    }
}


=head2 pool_one_DBConnection

  Arg [1]     : Bio::EnsEMBL::DBSQL::DBAdaptor
  Example     : $Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor->pool_one_DBConnection($dba);
  Description : Link this DBAdaptor to the pool, i.e. change its DBConnection to a
                ProxyDBConnection if possible, so that all the Core adaptors share
                the same underlying connection.
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub pool_one_DBConnection {
    my $self = shift;
    my $dba  = shift;

        my $dbc = $dba->dbc;
        # Skip the eHive DBConnections as they are different from Core's ones
        return if $dbc->isa('Bio::EnsEMBL::Hive::DBSQL::DBConnection');
        # ProxyDBConnections are what we want to achieve
        return if $dbc->isa('Bio::EnsEMBL::DBSQL::ProxyDBConnection');
        # Skip if it has no dbname
        return unless $dbc->dbname;
        # Disconnect as the DBC is going to be superseded
        $dbc->disconnect_if_idle;
        my $signature = sprintf('%s://%s@%s:%s/', $dbc->driver, $dbc->username, $dbc->host, $dbc->port);
        unless (exists $share_dbcs{$signature}) {
            #warn "Creating new shared DBC for $signature from ", $dbc->locator, "\n";
            # EnsEMBL::REST::Model::Registry uses $dbc directly, but I feel it safer to make a new instance
            $share_dbcs{$signature} = new Bio::EnsEMBL::DBSQL::DBConnection( -DBCONN => $dbc );
        }
        #warn "Replacing ", $dbc->locator, " with a Proxy to $signature\n";
        my $new_dbc = Bio::EnsEMBL::DBSQL::ProxyDBConnection->new(-DBC => $share_dbcs{$signature}, -DBNAME => $dbc->dbname);
        $dba->dbc($new_dbc);
}


=head2 iterate_toplevel_slices

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBAdaptor $species_dba
  Arg[2]      : (optional) String $genome_component
  Arg[-ATTRIBUTES] (opt)
              : Arrayref of strings. List of the attribute codes to load.
                If not defined, will load a preselection of attributes known
                to be necessary to build DnaFrags. Set it to an empty list to
                disable loading of any attributes.
  Arg[-RETURN_BATCHES] (opt)
              : Boolean. Make the iterator return batches of slices instead
                of the slices one by one
  Example     : my $it = iterate_toplevel_slices($human_dba);
  Description : Returns an iterator that yields all the top-level slices of
                the species considered (and the genome component if requested).
                Slices still include the duplicated bits, i.e. the human Y
                chromosome is complete and includes the PAR regions, and the
                non-reference slices (patches, haplotypes and LRGs) are present.
                Using an iterator means that the memory
                consumption remains low regardless of the size of the
                assembly. By default, the function will load some
                (seq_region) attributes, but the list of attributes to load
                can be configured, or this can be disabled altogether. The
                attributes are recorded under the "attributes" hash-key of
                each Slice object. Note that this is a non-standard location,
                and that calls to get_all_Attributes will not use it.
                Loading the slices is done in a separate database
                connection, so if you disable the loading of attributes and
                are not planning to use the database during the iteration,
                you may want to consider closing the connection before
                calling this function.
  Returntype  : Bio::EnsEMBL::Utils::Iterator
  Exceptions  : none

=cut

sub iterate_toplevel_slices {
    my $species_dba      = shift;
    my $genome_component = shift;

    my ($attributes, $return_batches) = rearrange([qw(ATTRIBUTES RETURN_BATCHES)], @_);
    $attributes //= ['codon_table', 'sequence_location', 'non_ref'];

    my $sa  = $species_dba->get_SliceAdaptor;
    my $csa = $species_dba->get_CoordSystemAdaptor;

    # "mysql_use_result" prevents us from running other queries in the same
    # connection, so making a copy of it.
    my $dbc = $species_dba->dbc;
    my $dbc_copy = Bio::EnsEMBL::DBSQL::DBConnection->new( -DBCONN => $dbc );

    # Taken from SliceAdaptor
    my $polyploid_extra_joins = 'JOIN (
                                   seq_region_attrib sra2
                                   JOIN attrib_type at2 USING (attrib_type_id)
                                 ) USING (seq_region_id)';
    my $polyploid_extra_where = 'AND at2.code = "genome_component" AND sra2.value = ?';

    my $slice_sql = 'SELECT sr.seq_region_id, sr.name, sr.length, sr.coord_system_id
                     FROM seq_region sr
                          JOIN coord_system cs USING (coord_system_id)
                          JOIN seq_region_attrib sra USING (seq_region_id)
                          JOIN attrib_type at USING (attrib_type_id)
                          ' . ($genome_component ? $polyploid_extra_joins : '') . '
                     WHERE at.code = "toplevel" AND cs.species_id = ?
                          ' . ($genome_component ? $polyploid_extra_where: '');

    my $sth = $dbc_copy->prepare($slice_sql, {'mysql_use_result' => 1});
    $sth->bind_param(1, $species_dba->species_id(), SQL_INTEGER );
    $sth->bind_param(2, $genome_component, SQL_VARCHAR) if $genome_component;
    $sth->execute();
    my ( $seq_region_id, $name, $length, $cs_id );
    $sth->bind_columns( \( $seq_region_id, $name, $length, $cs_id ) );

    my $slice_builder = sub {
        if ($sth->fetch) {
            my $cs = $csa->fetch_by_dbID($cs_id);
            if(!$cs) {
                throw("seq_region $name references non-existent coord_system $cs_id.");
            }
            return Bio::EnsEMBL::Slice->new_fast({
                    'start'             => 1,
                    'end'               => $length,
                    'strand'            => 1,
                    'seq_region_name'   => $name,
                    'seq_region_length' => $length,
                    'coord_system'      => $cs,
                    'adaptor'           => $sa,
                    # Not standard - Used by our own code below to record attributes
                    'attributes'        => {
                        'seq_region_id'     => $seq_region_id,
                    },
                });
        }
        $sth->finish;
        $dbc_copy->disconnect_if_idle;
        return;
    };

    my $slices_it = Bio::EnsEMBL::Utils::Iterator->new($slice_builder);
    return $slices_it unless @$attributes;

    my $batch_it = batch_iterator($slices_it, Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor::ID_CHUNK_SIZE);

    # Returns the same arrayref, but the slices will have the attributes loaded
    my $attributes_fetcher = sub {
        my $slices = shift;
        my %slice_hash = map {$_->{'attributes'}->{'seq_region_id'} => $_} @$slices;
        my $attrib_sql = 'SELECT seq_region_id, code, value
                          FROM seq_region_attrib JOIN attrib_type USING (attrib_type_id)
                          WHERE code IN (' . join(', ', map {"'$_'"} @$attributes) . ')
                                AND seq_region_id IN (' . join(', ', keys %slice_hash) . ')';

        $dbc->sql_helper->execute_no_return(
            -SQL          => $attrib_sql,
            -USE_HASHREFS => 1,
            -CALLBACK     => sub {
                my $row = shift;
                my $slice = $slice_hash{$row->{'seq_region_id'}};
                $slice->{'attributes'}->{$row->{'code'}} = $row->{'value'};
            },
        );
        return $slices;
    };
    my $batch_with_attrib_it = $batch_it->map($attributes_fetcher);

    return $return_batches ? $batch_with_attrib_it : flatten_iterator($batch_with_attrib_it);
}


# We pretend that all the methods are directly accessible on DBAdaptor
package Bio::EnsEMBL::DBSQL::DBAdaptor;


=head2 assembly_name

  Arg [1]    : Bio::EnsEMBL::DBSQL::DBAdaptor
  Example    : my $assembly_name = $genome_db->db_adaptor->assembly_name;
  Description: Gets the assembly name of this species
  Returntype : string

=cut

sub assembly_name {
    my $core_dba = shift;

    return undef unless $core_dba;
    return undef unless $core_dba->group eq 'core';

    ## We could alternatively do
    #return $core_dba->get_CoordSystemAdaptor->get_default_version;
    #return $core_dba->get_GenomeContainer->get_version;

    unless (exists $core_dba->{'_assembly_name'}) {
        my ($cs) = @{$core_dba->get_CoordSystemAdaptor->fetch_all()};
        $core_dba->{'_assembly_name'} = $cs ? $cs->version : '';
    }

    return $core_dba->{'_assembly_name'};
}


=head2 locator

  Arg [1]    : Bio::EnsEMBL::DBSQL::DBAdaptor
  Example    : my $locator = $genome_db->db_adaptor->locator;
  Description: Builds a locator that can be used later with DBLoader
  Returntype : string

=cut

sub locator {
    my $core_dba = shift;

    return undef unless $core_dba;
    return undef unless $core_dba->group eq 'core';

    my $species_safe = $core_dba->production_name;

    my $dbc = $core_dba->dbc();

    return sprintf(
          "%s/host=%s;port=%s;user=%s;pass=%s;dbname=%s;species=%s;species_id=%s;disconnect_when_inactive=%d",
          ref($core_dba), $dbc->host(), $dbc->port(), $dbc->username(), $dbc->password(), $dbc->dbname(), $species_safe, $core_dba->species_id, 1,
    );
}


=head2 url

  Arg [1]    : Bio::EnsEMBL::DBSQL::DBAdaptor
  Example    : my $url = $genome_db->db_adaptor->url;
  Description: Builds a URL that can be used later with the Registry or db_cmd.pl
  Returntype : string

=cut

sub url {
    my $core_dba = shift;

    return undef unless $core_dba;
    return undef unless $core_dba->group eq 'core';

    my $species_safe = $core_dba->production_name;

    my $dbc = $core_dba->dbc();

    require Bio::EnsEMBL::Utils::URI;
    my $uri = Bio::EnsEMBL::Utils::URI->new($dbc->driver);
    $uri->user($dbc->username);
    $uri->pass($dbc->password);
    $uri->port($dbc->port);
    $uri->host($dbc->host);

    $uri->{db_params} = {'dbname' => $dbc->dbname};
    $uri->add_param('group', $core_dba->group);
    $uri->add_param('species', $species_safe);
    $uri->add_param('species_id', $core_dba->species_id);

    return ($uri->generate_uri);
}


1;
