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

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBSQL::ProxyDBConnection;

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

    my ($cs) = @{$core_dba->get_CoordSystemAdaptor->fetch_all()};

    return $cs ? $cs->version : '';
}


=head2 locator

  Arg [1]    : Bio::EnsEMBL::DBSQL::DBAdaptor
  Example    : my $locator = $genome_db->db_adaptor->locator;
  Description: Builds a locator that can be used later with DBLoader
  Returntype : string

=cut

sub locator {
    my $core_dba = shift;
    my $suffix_separator = shift;

    return undef unless $core_dba;
    return undef unless $core_dba->group eq 'core';

    my $species_safe = $core_dba->species();
    if ($suffix_separator) {
        # The suffix was added to attain uniqueness and avoid collision, now we have to chop it off again.
        ($species_safe) = split(/$suffix_separator/, $core_dba->species());
    }

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
    my $suffix_separator = shift;

    return undef unless $core_dba;
    return undef unless $core_dba->group eq 'core';

    my $species_safe = $core_dba->species();
    if ($suffix_separator) {
        # The suffix was added to attain uniqueness and avoid collision, now we have to chop it off again.
        ($species_safe) = split(/$suffix_separator/, $core_dba->species());
    }

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
