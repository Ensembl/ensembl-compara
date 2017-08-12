=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable

=head1 SYNOPSIS

        # from within a Compara Runnable:
    my $FamilyAdaptor = $self->compara_dba()->get_FamilyAdaptor();

    my $ExternalFooFeatureAdaptor = $self->compara_dba($self->param('external_source'))->get_FooFeatureAdaptor();

=head1 DESCRIPTION

All Compara RunnableDBs *should* inherit from this module in order to work with module parameters and compara_dba in a neat way.

It inherits the parameter parsing functionality from Bio::EnsEMBL::Hive::Process
and provides a convenience method for creating the compara_dba from almost anything that can provide connection parameters.

Please refer to Bio::EnsEMBL::Hive::Process documentation to understand the basics of the RunnableDB interface.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable;

use strict;
use warnings;

use Carp;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;    # to use go_figure_compara_dba() and other things
use Bio::EnsEMBL::Compara::Utils::RunCommand;

use Bio::EnsEMBL::Hive::Utils ('stringify');

use base ('Bio::EnsEMBL::Hive::Process');

# Default values for the parameters used in this Runnable
# Make sure the sub-classes import this with $self->SUPER::param_defaults() !
sub param_defaults {
    return {
        'master_password'       => undef,   # Will default to $ENSADMIN_PSW
    }
}


=head2 compara_dba

    Description: this is an intelligent setter/getter of a Compara DBA. Resorts to magic in order to figure out how to connect.

    Example 1:   my $family_adaptor = $self->compara_dba()->get_FamilyAdaptor();    # implicit initialization and hashing

    Example 2:   my $external_foo_adaptor = $self->compara_dba( $self->param('db_conn') )->get_FooAdaptor();    # explicit initialization and hashing

=cut

sub compara_dba {
    my $self = shift @_;

    use Data::Dumper;
    my $given_compara_db = shift @_ || ($self->param_is_defined('compara_db') ? $self->param('compara_db') : $self);
    my $given_ref = ref( $given_compara_db );
    my $given_signature  = ($given_ref eq 'ARRAY' or $given_ref eq 'HASH') ? stringify ( $given_compara_db ) : "$given_compara_db";

    if( !$self->{'_cached_compara_db_signature'} or ($self->{'_cached_compara_db_signature'} ne $given_signature) ) {
        $self->{'_cached_compara_db_signature'} = $given_signature;
        $self->{'_cached_compara_dba'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $given_compara_db );
    }

    return $self->{'_cached_compara_dba'};
}


=head2 load_registry

  Example     : $self->load_registry();
  Description : Simple wrapper around Registry's load_all() method that takes care of 1) not loading the same
                registry file again and again, and 2) keeping $self->compara_dba valid
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub load_registry {
    my ($self, $registry_conf_file) = @_;

    # First we assume that nothing else could have tampered the registry,
    # so if the config file has been loaded it is still valid
    return if $self->{'_last_registry_file'} and ($self->{'_last_registry_file'} eq $registry_conf_file);

    # There are two consequences to not using "no_clear" in load_all():
    # 1) All the DBConnections have been closed at the db_handle level.
    # 2) $self->{'_cached_compara_dba'} has been removed from the registry.

    # eHive may fail with a "MySQL server has gone away" if its
    # DBConnection gets closed by load_all(). Let's check whether the
    # DBConnection is actually used by the Registry
    my $dbas_for_this_dbc = Bio::EnsEMBL::Registry->get_all_DBAdaptors_by_connection($self->dbc);

    # We can load the config file
    Bio::EnsEMBL::Registry->load_all($registry_conf_file, $self->debug, 0, 0, "throw_if_missing");
    $self->{'_last_registry_file'} = $registry_conf_file;

    # And let the API know that the db_handle is closed. eHive will survive !
    if (@$dbas_for_this_dbc) {
        $self->dbc->connected(0);
    }

    # Finally, the best is to un-cache the Compara DBAdaptor so that it
    # will be correctly recreated later.
    delete $self->{'_cached_compara_db_signature'};
    delete $self->{'_cached_compara_dba'};
}


=head2 _slurp

  Arg[1]      : String $filename
  Example     : my $content = $self->_slurp('/path/to/file');
  Description : Reads the whole content of a file and returns it as a string
  Returntype  : String
  Exceptions  : Throws if the file cannot be open
  Caller      : general
  Status      : Stable

=cut

sub _slurp {
  my ($self, $file_name) = @_;
  my $slurped;
  {
    local $/ = undef;
    open(my $fh, '<', $file_name) or $self->throw("Couldnt open file [$file_name]");
    $slurped = <$fh>;
    close($fh);
  }
  return $slurped;
}


=head2 _spurt

  Arg[1]      : String $filename
  Arg[2]      : String $content
  Arg[3]      : Boolean $append (default: false)
  Example     : $self->_spurt('/path/to/file.fa', ">seq_name\nACGTAAAGCATCACAT\n");
  Description : Create a file with the given content. If $append is true, the file is open in ">>" mode
  Returntype  : None
  Exceptions  : Throws if the file cannot be open
  Caller      : general
  Status      : Stable

=cut

sub _spurt {
    my ($self, $file_name, $content, $append) = @_;
    open(my $fh, $append ? '>>' : '>', $file_name) or $self->throw("Couldnt open file [$file_name]");
    print $fh $content;
    close($fh);
}


=head2 require_executable

Checks that the parameter is defined, and that the file is executable

=cut

sub require_executable {
    my ($self, $param_name) = @_;
    my $exe = $self->param_required($param_name);
    $self->input_job->transient_error(0);
    die "Cannot execute $param_name: '$exe'" unless(-x $exe);
    $self->input_job->transient_error(1);
    return $exe;
}


=head2 call_within_transaction {

Calls a method within a transaction.

=cut

sub call_within_transaction {
    my ($self, $callback, $retry, $pause) = @_;

        my $helper = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $self->compara_dba->dbc);
        return $helper->transaction(
            -RETRY => $retry,
            -PAUSE => $pause,
            -CALLBACK => $callback,
        );
}


sub run_command {
    my ($self, $cmd, $options) = @_;

    $options //= {};
    $options->{debug} = $self->debug;

    $self->dbc->disconnect_if_idle() if ($self->dbc);
    $self->compara_dba->dbc->disconnect_if_idle() if ($self->compara_dba);

    return Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec($cmd, $options);
}


=head2 elevate_privileges

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBConnection
  Example     : $self->elevate_privileges();
  Description : Upgrades the DBConnection's user to "ensadmin" if it is on "ensro".
                it needs the ENSADMIN_PSW environment variable to be defined, or the
                parameter 'master_password' otherwise
  Returntype  : None
  Caller      : internal

=cut

sub elevate_privileges {
    my $self = shift;
    my $dbc = shift;

    if ($dbc->username eq 'ensro') {
        my $new_password = $self->param('master_password') || $ENV{ENSADMIN_PSW};
        $self->throw("Cannot guess the password for 'ensadmin'\n") unless $new_password;
        $dbc->username('ensadmin');
        $dbc->password($new_password);
        $dbc->reconnect();
    }
}



1;
