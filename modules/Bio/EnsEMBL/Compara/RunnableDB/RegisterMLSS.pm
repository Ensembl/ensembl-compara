=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::RegisterMLSS

=head1 DESCRIPTION

This Runnable register the current database to the MLSS record in the master database.

Parameters:
 - master_db: location of the master database. If associated to the "ensro" user,
              the runnable will try to upgrade the connection to "ensadmin", using
              the password given by "master_password", or the environment variable
              ENSADMIN_PSW otherwise.
 - master_password: password of the "ensadmin" user. see above
 - mlss_id: dbID of the MethodLinkSpeciesSet of the pipeline

 - allow_reregistration: boolean. see below
 - allow_overwrite_other_database: boolean. see below

=cut

package Bio::EnsEMBL::Compara::RunnableDB::RegisterMLSS;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::DBSQL::DBConnection;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'allow_reregistration'              => 0,   # Boolean. 0 means: die if the current database is already registered for this MLSS
        'allow_overwrite_other_database'    => 0,   # Boolean. 0 means: die if another database has been registered for this MLSS
    }
}


sub fetch_input {
    my $self = shift @_;

    # Connect to the master db
    my $master_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $self->param_required('master_db') );

    # Trick to elevate the privileges on this session only
    $self->elevate_privileges($master_dba->dbc);
    $self->param('master_dbc', $master_dba->dbc);
    warn "master: ", $master_dba->dbc->locator, "\n" if $self->debug;

    # Sanity checks on the MLSS
    my $mlss_id = $self->param_required('mlss_id');
    my $master_mlss = $master_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    die "Could not find the MLSS dbID=$mlss_id in the master database\n" unless $master_mlss;
    $self->param('master_mlss', $master_mlss);

    # Build the url string
    my $this_dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $self->compara_dba->dbc);
    # Trick to avoid leaking the password in the master database
    if ($this_dbc->username eq 'ensadmin') {
        $this_dbc->username('ensro');
        $this_dbc->password('');
    }
    warn "this: ", $this_dbc->url, "\n" if $self->debug;
    $self->param('this_url', $this_dbc->url);
}

sub write_output {
    my $self = shift @_;

    my $master_mlss = $self->param('master_mlss');
    my $this_url = $self->param('this_url');

    if ($master_mlss->url) {
        if ($master_mlss->url eq $this_url) {
            unless ($self->param('allow_reregistration')) {
                die "This database [$this_url] is already registered for MLSS ", $master_mlss->dbID, "\n";
            }
        } else {
            unless ($self->param('allow_overwrite_other_database')) {
                die "The MLSS ".$master_mlss->dbID." is already registered to a different database: ", $master_mlss->url, "\n";
            }
        }
    }

    # FIXME: this UPDATE query should be in the MLSS adaptor
    my $update_query = 'UPDATE method_link_species_set SET url = ? WHERE method_link_species_set_id = ?';
    $self->param('master_dbc')->do($update_query, undef, $this_url, $self->param('mlss_id'));
}

1;

