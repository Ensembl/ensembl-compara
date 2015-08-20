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

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;    # to use go_figure_compara_dba() and other things
use Bio::EnsEMBL::Compara::Utils::RunCommand;

use Bio::EnsEMBL::Hive::Utils ('stringify');

use base ('Bio::EnsEMBL::Hive::Process');

# Default values for the parameters used in this Runnable
# Make sure the sub-classes import this with $self->SUPER::param_defaults() !
sub param_defaults {
    return {
        'do_transactions'       => undef,
        'species_tree_file'     => undef,
        'species_tree_string'   => undef,
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

    my $given_compara_db = shift @_ || ($self->param_is_defined('compara_db') ? $self->param('compara_db') : $self);
    my $given_ref = ref( $given_compara_db );
    my $given_signature  = ($given_ref eq 'ARRAY' or $given_ref eq 'HASH') ? stringify ( $given_compara_db ) : "$given_compara_db";

    if( !$self->{'_cached_compara_db_signature'} or ($self->{'_cached_compara_db_signature'} ne $given_signature) ) {
        $self->{'_cached_compara_db_signature'} = $given_signature;
        $self->{'_cached_compara_dba'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $given_compara_db );
    }

    return $self->{'_cached_compara_dba'};
}



=head2 get_species_tree_file

Returns the name of a file containing the species tree to be used.
 1. param('species_tree_file') if exists
 2. dumps param('species_tree_string') if exists
 3. dumps the 'species_tree' tag for the mlss param('mlss_id')

By default, it creates a file named 'spec_tax.nh' in the worker temp directory

=cut

sub get_species_tree_file {
    my $self = shift @_;

    unless( $self->param('species_tree_file') ) {

        my $species_tree_string = $self->get_species_tree_string();
        eval {
            use Bio::EnsEMBL::Compara::Graph::NewickParser;
            my $eval_species_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($species_tree_string);
            my @leaves = @{$eval_species_tree->get_all_leaves};
        };
        if($@) {
            die "Error '$@' parsing species tree from the string '$species_tree_string'";
        }

            # store the string in a local file:
        my $file_basename = shift || 'spec_tax.nh';
        my $species_tree_file = $self->worker_temp_directory . $file_basename;
        open SPECIESTREE, ">$species_tree_file" or die "Could not open '$species_tree_file' for writing : $!";
        print SPECIESTREE $species_tree_string;
        close SPECIESTREE;
        $self->param('species_tree_file', $species_tree_file);
    }
    return $self->param('species_tree_file');
}

sub _load_species_tree_string_from_db {
    my ($self) = @_;

    my $mlss_id = $self->param_required('mlss_id');
    my $label = $self->param('label') || 'default';
    my $species_tree_string = $self->compara_dba->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($mlss_id, $label)->species_tree();
    $self->param('species_tree_string', $species_tree_string);
}

=head2 get_species_tree_string

Return a string containing the species tree to be used
 1. param('species_tree_string') if exists
 2. content from param('species_tree_file') if exists
 3. 'species_tree' tag for the mlss param('mlss_id')

=cut

sub get_species_tree_string {
    my $self = shift @_;

    unless( $self->param('species_tree_string') ) {
        if( my $species_tree_file = $self->param('species_tree_file') ) {
            $self->param('species_tree_string', $self->_slurp( $species_tree_file ));
        } else {
            $self->_load_species_tree_string_from_db;
        }
    }
    return  $self->param('species_tree_string');
}


=head2 _slurp

Reads the whole content of a file and returns it as a string

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

Prints $content to a file

=cut

sub _spurt {
    my ($self, $file_name, $content) = @_;
    open(my $fh, '>', $file_name) or $self->throw("Couldnt open file [$file_name]");
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

Calls a method within a transaction (if "do_transactions" is set).
Otherwise, calls it directly.

=cut

sub call_within_transaction {
    my ($self, $callback, $retry, $pause) = @_;

    # Make sure the same commands are inside and outside of the transaction
    if ($self->param('do_transactions')) {
        my $helper = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $self->compara_dba->dbc);
        return $helper->transaction(
            -RETRY => $retry,
            -PAUSE => $pause,
            -CALLBACK => $callback,
        );
    } else {
        return $callback->();
    }
}


sub run_command {
    my ($self, $cmd, $timeout) = @_;

    print STDERR "COMMAND: $cmd\n" if ($self->debug);
    print STDERR "TIMEOUT: $timeout\n" if ($timeout and $self->debug);
    my $runCmd = Bio::EnsEMBL::Compara::Utils::RunCommand->new($cmd, $timeout);
    $self->compara_dba->dbc->disconnect_if_idle();
    $runCmd->run();
    print STDERR "OUTPUT: ", $runCmd->out, "\n" if ($self->debug);
    print STDERR "ERROR : ", $runCmd->err, "\n\n" if ($self->debug);
    return $runCmd;
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
