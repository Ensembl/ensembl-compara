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

Bio::EnsEMBL::Compara::RunnableDB::BuildMaster::CreateRegConf

=head1 SYNOPSIS

Runs the script 'clone_core_database.pl' (located at 'ensembl-test/scripts/' by default)
over a given JSON configuration file with the regions of data to clone.

Requires several inputs:
    'clone_data_regions' : full path to the clone script 'clone_core_database.pl'
    'reg_conf'  : full path to the registry configuration file
    'dst_host'  : host name where the new core database will be created
    'dst_port'  : host port
    'json_file' : JSON configuration file with the regions of data to clone

The dataflow output writes the new core database's name into the accumulator named 'cloned_db'.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BuildMaster::CreateRegConf;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;
use File::Slurp;
use File::Basename;
use File::Spec;

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
    my $reg_conf_tmpl = $self->param_required('reg_conf_tmpl');
    my $work_dir = $self->param_required('work_dir');
    my $dbs_hash = $self->param_required('dbs_hash');
    # Find the spot (labelled "<dbs_hash>") where the cloned core databases must
    # be stored and add the required information
    my $content = read_file($reg_conf_tmpl);
    $content =~ s/<dbs_hash>/$dbs_hash/;
    # Remove "_tmpl" suffix from registry conf template filename
    my ( $reg_conf_fname, $dirs, $suffix ) = fileparse($reg_conf_tmpl);
    $reg_conf_fname =~ s/_tmpl//;
    # Create the new registry conf file
    my $reg_conf = File::Spec->join($work_dir, $reg_conf_fname);
    open(my $file, '>', $reg_conf) or die "Could not open file '$reg_conf' $!";
    print $file $content;
    close $file;
}

sub write_output {
    my $self = shift;
}

1;
