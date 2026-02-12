=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::DumpSpeciesPaths

=head1 DESCRIPTION

This runnable dumps, for a given gene-tree MLSS, a
mapping of genome names to FTP dump relative paths.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::DumpSpeciesPaths;

use strict;
use warnings;

use File::Basename qw(fileparse);
use File::Path qw(make_path);
use JSON qw(encode_json);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my ($self) = @_;

    my $clusterset_id = $self->param_required('clusterset_id');
    my $member_type = $self->param_required('member_type');
    my $species_path_file = $self->param_required('species_path_file');

    my($species_path_file_name, $species_path_parent_dir) = fileparse($species_path_file);

    my $mlss_dba = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor();
    my $method_dba = $self->compara_dba->get_MethodAdaptor();

    my $method_type;
    if ($member_type eq 'protein') {
        $method_type = 'PROTEIN_TREES';
    } elsif ($member_type eq 'ncrna') {
        $method_type = 'NC_TREES';
    } else {
        $self->die_no_retry("unknown member_type: $member_type");
    }

    my $mlss = $mlss_dba->fetch_by_method_link_type_species_set_name($method_type, $clusterset_id);
    my $collection = $mlss->species_set;

    my @collection_gdbs = grep { !$_->genome_component } @{$collection->genome_dbs};

    my %species_path_info;
    foreach my $gdb (@collection_gdbs) {
        $species_path_info{$gdb->name} = $gdb->_get_ftp_dump_relative_path();
    }

    make_path($species_path_parent_dir);
    $self->_spurt($species_path_file, encode_json(\%species_path_info));
}


1;
