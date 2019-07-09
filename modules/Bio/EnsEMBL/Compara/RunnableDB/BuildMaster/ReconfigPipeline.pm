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
file (used by Java healthchecks) to point to the right hosts.

Requires several inputs:
    'cloned_dbs'      : hash accumulator of 'species' => 'database_name'
    'init_reg_conf'   : full path to the initial registry configuration file
    'reg_conf'        : full path to the registry configuration file
    'reg_conf_tmpl'   : full path to the registry configuration template file
    'master_db'       : new master database
    'java_hc_db_prop' : full path to 'database.default.properties' file (used by
                        Java healthchecks)
    'backups_dir'     : full path to the pipeline's backup directory
    'dst_host'        : host name where the cloned core databases have been created
    'dst_port'        : host port


=cut

package Bio::EnsEMBL::Compara::RunnableDB::BuildMaster::ReconfigPipeline;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;
    my $dst_host = $self->param_required('dst_host');
    my $cloned_dbs = $self->param_required('cloned_dbs');
    # Create the cloned core databases hash content with the format:
    #     species/alias name => [ host, db_name ]
    my $core_dbs_hash = "\n";
    foreach my $species (keys %{ $cloned_dbs }) {
        my $dbname = $cloned_dbs->{$species};
        $core_dbs_hash .= "    '$species' => [ '$dst_host', '$dbname' ],\n";
    }
    $self->param('core_dbs_hash', $core_dbs_hash);
    # Create the [host, db_name] array content for 'compara_master', getting the
    # information from the initial registry configuration file
    my $compara = $self->param_required('master_db');
    my $init_reg_conf = $self->param_required('init_reg_conf');
    Bio::EnsEMBL::Registry->load_all($init_reg_conf, 0, 0, 0, "throw_if_missing");
    my $compara_db = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, "compara");
    my $master_db_info = " '" . $compara_db->dbc->host . "', '" . $compara_db->dbc->dbname . "' ";
    $self->param('master_db_info', $master_db_info);
}

sub run {
    my $self = shift;
    my $reg_conf = $self->param_required('reg_conf');
    my $reg_conf_tmpl = $self->param_required('reg_conf_tmpl');
    my $core_dbs_hash = $self->param_required('core_dbs_hash');
    my $master_db_info = $self->param_required('master_db_info');
    my $java_hc_db_prop = $self->param_required('java_hc_db_prop');
    my $dst_host = $self->param_required('dst_host');
    my $dst_port = $self->param_required('dst_port');
    # Find the tag '<core_dbs_hash>' in the registry configuration file template
    # and replace it by the cloned core databases hash content
    my $content = $self->_slurp($reg_conf_tmpl);
    $content =~ s/<core_dbs_hash>/$core_dbs_hash/;
    # Find the tag '<master_db_info>' in the registry configuration file
    # template and replace it by the new master database array content
    $content =~ s/<master_db_info>/$master_db_info/;
    # Uncomment the line where add_compara_dbs() is executed
    $content =~ s/\#add_compara_dbs\(/add\_compara\_dbs\(/;
    # Modify the registry configuration file
    $self->_spurt($reg_conf, $content);
    # All cloned core databases are in the same host, so replace that
    # information in the Java healthchecks database properties file ('host',
    # 'host1' and 'host2', and 'port', 'port1' and 'port2')
    $content = $self->_slurp($java_hc_db_prop);
    $content =~ s/(^)(host[12]?[ ]*=)[ ]*[\w\.-]+/$1$2 $dst_host/gm;
    $content =~ s/(^)(port[12]?[ ]*=)[ ]*\d+/$1$2 $dst_port/gm;
    $self->_spurt($java_hc_db_prop, $content);
}

1;
