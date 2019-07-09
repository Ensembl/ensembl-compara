=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This modules contains common methods used when dealing with the
Registry, especially in the context of registry configuration files.

The hash structure accepted in all add*dbas functions is like this:

 my $ancestral_dbs = {
     'ancestral_prev'    => [ 'mysql-ens-compara-prod-1', "ensembl_ancestral_$prev_release" ],
     'ancestral_curr'    => [ 'mysql-ens-compara-prod-1', "ensembl_ancestral_$curr_release" ],
 };

It can be directly passed to the add*dbas function like this:

 Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $ancestral_dbs );

Note that by default, all the aliases that end with '_prev' will have a
read-only connection (ensro user). Otherwise, a read+write connection will
be defined, using the appropriate user (ensadmin or ensrw).

The port and passwords are automatically retrieved through the mysql-cmd binary.

=head1 REGISTRY DEFINITION METHODS

=cut

package Bio::EnsEMBL::Compara::Utils::Registry;

use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor;

my %ports;
my %rw_users;
my %rw_passwords;


=head2 add_core_dbas

  Example     : Bio::EnsEMBL::Compara::Utils::Registry::add_core_dbas( $core_dbs );
  Description : Define a Bio::EnsEMBL::DBSQL::DBAdaptor for each database
  Returntype  : none
  Exceptions  : none

=cut

sub add_core_dbas {
    add_dbas('Bio::EnsEMBL::DBSQL::DBAdaptor', @_);
}


=head2 add_compara_dbas

  Example     : Bio::EnsEMBL::Compara::Utils::Registry::add_compara_dbas( $compara_dbs );
  Description : Define a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor for each database
  Returntype  : none
  Exceptions  : none

=cut

sub add_compara_dbas {
    add_dbas('Bio::EnsEMBL::Compara::DBSQL::DBAdaptor', @_);
}


=head2 add_taxonomy_dbas

  Example     : Bio::EnsEMBL::Taxonomy::Utils::Registry::add_taxonomy_dbas( $taxonomy_dbs );
  Description : Define a Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor for each database
  Returntype  : none
  Exceptions  : none

=cut

sub add_taxonomy_dbas {
    add_dbas('Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor', @_);
}


=head2 add_dbas

  Example     : Bio::EnsEMBL::Taxonomy::Utils::Registry::add_dbas( 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor', $compara_dbs );
  Description : Define a DBAdaptor of the required type for each database.  For databases
                that contain "_prev", a read-only connection will be defined (using the
                ensro user). Otherwise, a read_write connection will be defined (using
                ensadmin or ensrw) and querying the password with a mysql-cmd
  Returntype  : none
  Exceptions  : none

=cut

sub add_dbas {
    my $dba_class = shift;
    my $compara_dbs = shift;

    foreach my $alias_name ( keys %$compara_dbs ) {
        my ( $host, $db_name ) = @{ $compara_dbs->{$alias_name} };

        my ( $user, $pass );
        if ( $alias_name =~ /_prev/ ) {
            $user = 'ensro';
            $pass = '';
        } else {
            $user = get_rw_user($host);
            $pass = get_rw_pass($host);
        }

        $dba_class->new(
            -host => $host,
            -user => $user,
            -pass => $pass,
            -port => get_port($host),
            -species => $alias_name,
            -dbname  => $db_name,
        );
    }
}


=pod

=head1 MYSQL_CMDS WRAPPER METHODS

=cut


=head2 get_port

  Example     : Bio::EnsEMBL::Compara::Utils::Registry::get_port('mysql-ens-compara-prod-1');
  Description : Run the associated mysql-cmd to get the port of this host
  Returntype  : Integer
  Exceptions  : none

=cut

sub get_port {
    my $host = shift;
    unless (exists $ports{$host}) {
        my $port = `$host port`;
        chomp $port;
        $ports{$host} = $port;
    }
    return $ports{$host};
}


=head2 get_rw_user

  Example     : Bio::EnsEMBL::Compara::Utils::Registry::get_rw_user('mysql-ens-compara-prod-1');
  Description : Run the associated mysql-cmd to get the read+write username for this host
  Returntype  : String
  Exceptions  : none

=cut

sub get_rw_user {
    my $host = shift;
    unless (exists $rw_users{$host}) {
        # There are several possible user names
        foreach my $rw_user (qw(ensadmin ensrw w)) {
            my $rc = system("which $host-$rw_user > /dev/null");
            unless ($rc) {
                $rw_users{$host} = $rw_user;
                last;
            }
        }
    }
    return $rw_users{$host};
}


=head2 get_rw_pass

  Example     : Bio::EnsEMBL::Compara::Utils::Registry::get_rw_pass('mysql-ens-compara-prod-1');
  Description : Run the associated mysql-cmd to get the password of this host's read+write user
  Returntype  : String
  Exceptions  : none

=cut

sub get_rw_pass {
    my $host = shift;
    unless (exists $rw_passwords{$host}) {
        my $rw_user = get_rw_user($host);
        my $rw_pass = `$host-$rw_user pass`;
        chomp $rw_pass;
        $rw_passwords{$host} = $rw_pass;
    }
    return $rw_passwords{$host};
}

1;
