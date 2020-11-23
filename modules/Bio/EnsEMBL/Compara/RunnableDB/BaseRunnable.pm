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
use Digest::MD5 qw(md5_hex);

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;    # to use go_figure_compara_dba() and other things
use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;
use Bio::EnsEMBL::Compara::Utils::Registry;
use Bio::EnsEMBL::Compara::Utils::RunCommand;

use Bio::EnsEMBL::Hive::Utils ('stringify');

use base ('Bio::EnsEMBL::Hive::Process');



=head2 compara_dba

    Description: Getter/setter for the main Compara DBA.

    Example 1:   my $family_adaptor = $self->compara_dba()->get_FamilyAdaptor();    # implicit initialization and hashing
    Example 2:   my $external_foo_adaptor = $self->compara_dba( $self->param('db_conn') )->get_FooAdaptor();    # explicit initialization and hashing

=cut

sub compara_dba {
    my $self = shift @_;

    if (!$self->param_is_defined('compara_db') and !$self->worker->adaptor) {
        # go_figure_compara_dba won't be able to create a DBAdaptor, so let's
        # just print a nicer error message
        $self->input_job->transient_error(0);
        $self->throw('In standaloneJob mode, $self->compara_dba requires the -compara_db parameter to be defined on the command-line');
    }

    return $self->_cached_compara_dba('compara_db', @_);
}


=head2 _get_active_compara_dba

  Example     : $self->_get_active_compara_dba();
  Description : Private method to return the currently cached compara_dba. Note that
                this method will not update the DBA based on the current job parameters
                and may return the DBA of the previous job. It will return undef if
                $self->compara_dba has never been called, even though the call would
                return a DBA
  Returntype  : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor

=cut

sub _get_active_compara_dba {
    my $self = shift;
    return $self->{'_cached_dba'}->{'compara_db'};
}


=head2 get_all_compara_dbas

    Arg[1]      : [Optional] (str/arrayref) return only compara DBAs whose aliases match one of the given
                  patterns. These patterns can include wildcards ('*').
    Example     : my %compara_dbas = $self->get_all_compara_dbas();
                  my %compara_prev_dbas = $self->get_all_compara_dbas('*_prev');
    Description : Getter of compara DBAs and their corresponding aliases.
    Returntype  : Hashref

=cut

sub get_all_compara_dbas {
    my ($self, $patterns) = @_;

    # Create hash of compara alias => DBAdaptor
    my %compara_dbas = map { $_->species => $_ } @{ Bio::EnsEMBL::Registry->get_all_DBAdaptors(-GROUP => 'compara') };
    # If no patterns are given, return all compara dbas
    unless ( @{$patterns} ) {
        return \%compara_dbas;
    }
    $patterns = [$patterns] unless ref($patterns);
    # "Decompress" wildcards
    foreach my $alias ( @{$patterns} ) {
        $alias =~ s/\*/[a-zA-z0-9_]*/g;
    }
    # Filter all registry aliases and return only those that match at least one pattern
    foreach my $alias (keys %compara_dbas) {
        delete $compara_dbas{$alias} if (! grep { $alias =~ m/\A$_\Z/ } @{$patterns});
    }
    return \%compara_dbas;
}


=head2 get_cached_compara_dba

    Description: Getter/setter for arbitrary DBAs coming from other parameters.

=cut

sub get_cached_compara_dba {
    my ($self, $param_name) = @_;
    $self->param_required($param_name);
    return $self->_cached_compara_dba($param_name);
}


=head2 _cached_compara_dba

    Description: This is an intelligent setter/getter of a Compara DBA. Uses go_figure_compara_dba to figure out how to connect.
                 The DBA and its signature are kept in the Runnable, so that the connections persist and they don't have to be
                 recreated

=cut

sub _cached_compara_dba {
    my ($self, $param_name, $given_compara_db) = @_;

    $given_compara_db ||= ($self->param_is_defined($param_name) ? $self->param($param_name) : $self);

    my $given_ref = ref( $given_compara_db );
    my $given_signature  = ($given_ref eq 'ARRAY' or $given_ref eq 'HASH') ? stringify ( $given_compara_db ) : "$given_compara_db";

    $self->{'_cached_dba'} ||= {};
    $self->{'_cached_signature'} ||= {};

    if( !$self->{'_cached_signature'}->{$param_name} or ($self->{'_cached_signature'}->{$param_name} ne $given_signature) ) {
        $self->{'_cached_signature'}->{$param_name} = $given_signature;
        $self->{'_cached_dba'}->{$param_name} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $given_compara_db );
    }

    return $self->{'_cached_dba'}->{$param_name};
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
    # 2) Cached DBAs have been removed from the registry.

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

    # Finally, the best is to un-cache the Compara DBAs so that they
    # will be correctly recreated later.
    delete $self->{'_cached_dba'};
    delete $self->{'_cached_signature'};

    # Bonus: we setup ProxyDBConnections for all databases
    Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor->pool_all_DBConnections();
}


=head2 disconnect_from_databases

  Description : Disconnect from the eHive and Compara databases before running something offline

=cut

sub disconnect_from_databases {
    my $self = shift;
    $self->dbc->disconnect_if_idle() if ($self->dbc);
    if (my $compara_dba = $self->_get_active_compara_dba) {
        $compara_dba->dbc->disconnect_if_idle() if $compara_dba->dbc;
    }
}


=head2 disconnect_from_hive_database

  Description : Disconnect from the eHive database if it is not the same as the Compara database

=cut

sub disconnect_from_hive_database {
    my $self = shift;
    if (my $compara_dba = $self->_get_active_compara_dba) {
        return if ($self->dbc and $compara_dba->dbc and ($self->dbc eq $compara_dba->dbc));
    }
    $self->dbc->disconnect_if_idle() if ($self->dbc);
}


=head2 iterate_by_dbc

  Description : Group the objects by DBConnection before doing the iteration, so that the
                connection cycles are minimized, and call $callback on each of them.
                Access to a given DBConnection is wrapped with prevent_disconnect()

=cut

sub iterate_by_dbc {
    my ($self, $objects, $dbc_getter, $callback, $do_disconnect) = @_;

    my %objects_per_dbc_str;
    my %dbc_str_2_dbc;
    foreach my $obj (@$objects) {
        my $dbc = $dbc_getter->($obj);
        # The DBC could be a Proxy, in which case need to look into the "real" one
        $dbc = $dbc->__proxy if $dbc && $dbc->isa('Bio::EnsEMBL::DBSQL::ProxyDBConnection');
        my $dbc_str = defined $dbc ? "$dbc" : '';
        push @{$objects_per_dbc_str{$dbc_str}}, $obj;
        $dbc_str_2_dbc{$dbc_str} = $dbc;
    }

    # Make parameter to control prevent_disconnect ?
    foreach my $dbc_str (keys %dbc_str_2_dbc) {
      if ($dbc_str_2_dbc{$dbc_str}) {
        $dbc_str_2_dbc{$dbc_str}->prevent_disconnect( sub {
                $callback->($_) for @{$objects_per_dbc_str{$dbc_str}};
            } );
        $dbc_str_2_dbc{$dbc_str}->disconnect_if_idle if $do_disconnect;
      } else {
        $callback->($_) for @{$objects_per_dbc_str{$dbc_str}};
      }
    }
}


=head2 _slurp

  Arg[1]      : String $filename
  Example     : my $content = $self->_slurp('/path/to/file');
  Description : Reads the whole content of a file and returns it as a string
  Returntype  : String
  Exceptions  : Throws if the file cannot be open or closed
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
    close($fh) or $self->throw("Couldnt close file [$file_name]");
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
  Exceptions  : Throws if the file cannot be open or closed
  Caller      : general
  Status      : Stable

=cut

sub _spurt {
    my ($self, $file_name, $content, $append) = @_;
    open(my $fh, $append ? '>>' : '>', $file_name) or $self->throw("Couldnt open file [$file_name]");
    print $fh $content;
    close($fh) or $self->throw("Couldnt close file [$file_name]");
}


=head2 preload_file_in_memory

  Arg[1]      : String $filename
  Example     : $self->preload_file_in_memory($exonerate_esi_file);
  Description : Load the file into memory. Note that we can't guarantee that
                the file will remain in memory thereafter.
                Note: the current implementation uses "cat", which is considered
                a poor man's trick. Consider using "vmtouch" if that doesn't work
                well enough.
  Returntype  : none
  Exceptions  : Throws if preloading fails

=cut

sub preload_file_in_memory {
    my ($self, $file_name) = @_;
    $self->run_command("cat $file_name > /dev/null", { die_on_failure => 1 });
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

        return $self->compara_dba->dbc->sql_helper->transaction(
            -RETRY => $retry,
            -PAUSE => $pause,
            -CALLBACK => $callback,
        );
}


=head2 run_command {

Similar to eHive's run_system_command but also disconnects from the Compara
databases and returns an object.

=cut

sub run_command {
    my ($self, $cmd, $options) = @_;

    $options //= {};
    $options->{debug} = $self->debug;

    $self->disconnect_from_databases;

    return Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec($cmd, $options);
}


=head2 get_command_output

Wrapper around run_command that captures the standard output of the command and raises any failure

=cut

sub get_command_output {
    my ($self, $cmd, $options) = @_;

    $options //= {};
    $options->{die_on_failure} //= 1;

    my $run_cmd = $self->run_command($cmd, $options);
    if (wantarray) {
        return split /\n/, $run_cmd->out;
    } else {
        return $run_cmd->out;
    }
}


=head2 read_from_command {

Helper method to safely open a command as a pipe and read from it

=cut

sub read_from_command {
    my ($self, $cmd, $read_sub, $options) = @_;

    $options //= {};
    $options->{pipe_stdout} = $read_sub;
    $options->{die_on_failure} //= 1;

    return $self->run_command($cmd, $options);
}


=head2 write_to_command {

Helper method to safely open a command as a pipe and write to it

=cut

sub write_to_command {
    my ($self, $cmd, $write_sub, $options) = @_;

    $options //= {};
    $options->{pipe_stdin} = $write_sub;
    $options->{die_on_failure} //= 1;

    return $self->run_command($cmd, $options);
}


=head2 elevate_privileges

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBConnection
  Example     : $self->elevate_privileges();
  Description : Upgrades the DBConnection's user to "ensadmin" if it is on "ensro".
  Returntype  : None
  Caller      : internal

=cut

sub elevate_privileges {
    my $self = shift;
    my $dbc = shift;

    if ($dbc->username eq 'ensro') {
        $dbc->username(Bio::EnsEMBL::Compara::Utils::Registry::get_rw_user($dbc->host));
        $dbc->password(Bio::EnsEMBL::Compara::Utils::Registry::get_rw_pass($dbc->host));
        $dbc->reconnect();
    }
}


=head2 complete_early_if_branch_connected

  Arg[1]      : (string) message
  Arg[2]      : (integer) branch number
  Description : Wrapper around complete_early that first checks that the
                branch is connected to something.
  Returntype  : void if the branch is not connected. Otherwise doesn't return

=cut

sub complete_early_if_branch_connected {
    my ($self, $message, $branch_code) = @_;

    # just return if no corresponding gc_dataflow rule has been defined
    return unless $self->input_job->analysis->dataflow_rules_by_branch->{$branch_code};

    # TODO: flowing to $branch_code can be done by complete_early in eHive 2.5
    if (defined $branch_code) {
        $self->dataflow_output_id(undef, $branch_code);
        $self->input_job->autoflow(0);
    }
    $self->complete_early($message);
}


=head2 add_or_update_pipeline_wide_parameter

  Arg[1]      : (string) $param_name: the parameter name
  Arg[2]      : (string) $param_value: the parameter value
  Example     : $self->add_or_update_pipeline_wide_parameter('are_all_species_reused', 1);
  Description : Add a new pipeline-wide parameter, or update its value
  Returntype  : none
  Exceptions  : none
  Caller      : general

=cut

sub add_or_update_pipeline_wide_parameter {
    my ($self, $param_name, $param_value) = @_;
    my ($pwp) = $self->db->hive_pipeline->add_new_or_update('PipelineWideParameters',
        'param_name'    => $param_name,
        'param_value'   => $param_value,
    );
    my $adaptor = $self->db->get_PipelineWideParametersAdaptor;
    $adaptor->store_or_update_one($pwp, ['param_name']);
}


=head2 die_no_retry

  Example     : $self->die_no_retry("GenomeDB dbID=45 is missing");
  Description : Make the job "die" with the given error, but also tell eHive
                that it is not worth retrying the job (the error is not
                "transient").
  Returntype  : none
  Exceptions  : die

=cut

sub die_no_retry {
    my $self = shift;
    $self->input_job->transient_error(0);
    die @_;
}


=head2 get_requestor_id

  Example     : my $requestor_id = $self->get_requestor_id();
  Description : Return an identifier for this job that can be used as
                a requestor ID in Utils::IDGenerator
  Returntype  : Integer (unsigned 64-bits)

=cut

sub get_requestor_id {
    my $self = shift;

    # Use the eHive job_id if possible
    if ($self->input_job && $self->input_job->dbID) {
        return $self->input_job->dbID;
    }

    # Resort to computing a (likely unique) 64-bits key
    # based on the job's parameters
    my $params = stringify($self->input_job->{'_unsubstituted_param_hash'});
    # md5 returns a 128 bits / 16 bytes string, of which we take
    # the 64 left-most bits
    my $id = unpack 'Q', md5($params);
    return $id
}

1;
