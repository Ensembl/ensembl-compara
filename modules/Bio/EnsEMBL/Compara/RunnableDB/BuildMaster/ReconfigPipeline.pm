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

Replaces the registry configuration file of each resource class and meadow type.

Requires several inputs:
    'new_reg_conf' : full path where the new registry configuration file is located
    'pipeline_url' : url of the pipeline to be edited
    'resources'    : hash with the resouce classes of the pipeline


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

sub run {
    my $self = shift;
    my $reg_conf = $self->param_required('new_reg_conf');
    my $pipeline_url = $self->param_required('pipeline_url');
    my $resources = $self->param_required('resources');
    # Replace the registry configuration file in each resource class
    foreach my $res_class (keys %{ $resources }) {
        foreach my $meadow_type (keys %{ $resources->{$res_class} }) {
            # Skip meadow types that do not have a registry configuration file defined
            if (ref($resources->{$res_class}->{$meadow_type}) eq 'ARRAY') {
                my $meadow = $resources->{$res_class}->{$meadow_type}[0];
                # Escape double quotes to use the meadow inside a double-quoted string
                $meadow =~ s/\"/\\\"/g;
                my $config = $resources->{$res_class}->{$meadow_type}[1];
                # Replace the default registry configuration file by the new one
                $config =~ s/--reg_conf .*/--reg_conf $reg_conf/;
                # Update the resource class
                $self->run_command("tweak_pipeline.pl -url $pipeline_url -SET 'resource_class[$res_class].$meadow_type=[\"$meadow\",\"$config\"]'", {die_on_failure => 1});
            }
        }
    }
    my $java_hc_db_prop = $self->param_required('java_hc_db_prop');
    my $backups_dir = $self->param_required('backups_dir');
    # Make a backup copy of the Java healthchecks database properties file
    $self->run_command("cp $java_hc_db_prop $backups_dir", {die_on_failure => 1});
    # All cloned core and new master databases are in the same host, so replace
    # that information in the Java healthchecks database properties file
    # ('host', 'host1' and 'host2', and 'port', 'port1' and 'port2')
    my $dst_host = $self->param_required('dst_host');
    my $dst_port = $self->param_required('dst_port');
    my $content = read_file($java_hc_db_prop);
    $content =~ s/(^)(host[12]?[ ]*=)[ ]*[\w\.-]+/$1$2 $dst_host/gm;
    $content =~ s/(^)(port[12]?[ ]*=)[ ]*\d+/$1$2 $dst_port/gm;
    open(my $file, '>', $java_hc_db_prop) or die "Could not open file '$java_hc_db_prop' $!";
    print $file $content;
    close $file;
}

1;
