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

=cut

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BuildMaster::ReconfigPipeline

=head1 SYNOPSIS

Modifies the registry configuration file to add the information of each species'
cloned core database, and updates the information in 'database.default.properties'
file (used by Java healthchecks) to point to the right host.

Requires several inputs:
    'cloned_dbs'      : hash accumulator of "species" => "database_name"
    'reg_conf'        : full path to the registry configuration file
    'reg_conf_tmpl'   : full path to the registry configuration template file
    'java_hc_db_prop' : full path to 'database.default.properties' file (used by Java healthchecks)
    'backups_dir'     : full path to the pipeline's backup directory
    'dst_host'        : host name where the cloned core and master databases have been created
    'dst_port'        : host port


=cut

package Bio::EnsEMBL::Compara::RunnableDB::BuildMaster::ReconfigPipeline;

use warnings;
use strict;
use File::Slurp;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
    }
}

sub fetch_input {
    my $self = shift;
    my $dst_host = $self->param_required('dst_host');
    my $cloned_dbs = $self->param_required('cloned_dbs');
    # Create the cloned core databases hash with the format:
    #     species/alias name => [ host, db_name ]
    my $dbs_hash = "\n";
    foreach my $species (keys %{ $cloned_dbs }) {
        my $dbname = $cloned_dbs->{$species};
        $dbs_hash .= "    '$species' => [ '$dst_host', '$dbname' ],\n";
    }
    $self->param('dbs_hash', $dbs_hash);
}

sub run {
    my $self = shift;
    my $reg_conf = $self->param_required('reg_conf');
    my $reg_conf_tmpl = $self->param_required('reg_conf_tmpl');
    my $dbs_hash = $self->param_required('dbs_hash');
    # Find the spot (labelled "<dbs_hash>") where the cloned core databases must
    # be stored and add the required information
    my $content = read_file($reg_conf_tmpl);
    $content =~ s/<dbs_hash>/$dbs_hash/;
    # Modify the registry conf file
    open(my $file, '>', $reg_conf) or die "Could not open file '$reg_conf' $!";
    print $file $content;
    close $file;
    # Make a backup copy of the Java healthchecks database properties file
    my $java_hc_db_prop = $self->param_required('java_hc_db_prop');
    my $backups_dir = $self->param_required('backups_dir');
    $self->run_command("cp $java_hc_db_prop $backups_dir", {die_on_failure => 1});
    # All cloned core and new master databases are in the same host, so replace
    # that information in the Java healthchecks database properties file
    # ('host', 'host1' and 'host2', and 'port', 'port1' and 'port2')
    my $dst_host = $self->param_required('dst_host');
    my $dst_port = $self->param_required('dst_port');
    $content = read_file($java_hc_db_prop);
    $content =~ s/(^)(host[12]?[ ]*=)[ ]*[\w\.-]+/$1$2 $dst_host/gm;
    $content =~ s/(^)(port[12]?[ ]*=)[ ]*\d+/$1$2 $dst_port/gm;
    open($file, '>', $java_hc_db_prop) or die "Could not open file '$java_hc_db_prop' $!";
    print $file $content;
    close $file;
}

1;
