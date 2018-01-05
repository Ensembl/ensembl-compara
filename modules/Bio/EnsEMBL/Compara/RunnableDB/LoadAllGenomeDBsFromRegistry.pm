=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::LoadAllGenomeDBsFromRegistry

=head1 DESCRIPTION

Loads all the core databases and stores the species as GenomeDB objects.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::LoadAllGenomeDBsFromRegistry;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::LoadOneGenomeDB');

my $suffix_separator = '__cut_here__';


sub fetch_input {
    my $self = shift @_;
    $self->param('all_core_dbas', $self->get_all_core_dbas);
}

sub run {
    my $self = shift @_;

    my @genome_dbs;
    foreach my $core_dba (@{$self->param('all_core_dbas')}) {
        next unless $core_dba->assembly_name;
        push @genome_dbs, $self->create_genome_db($core_dba);
    }
    $self->param('genome_dbs', \@genome_dbs);
}

sub write_output {
    my $self = shift;

    foreach my $genome_db (@{$self->param('genome_dbs')}) {
        $self->store_and_dataflow_genome_db($genome_db, 2);
    }
}


sub get_all_core_dbas {
    my $self = shift;

    my $registry_conf_file = $self->param('registry_conf_file');
    my $registry_dbs = $self->param('registry_dbs') || [];
    my $registry_files = $self->param('registry_files') || [];
    $registry_dbs || $registry_files || die "'registry_dbs' or 'registry_files' become obligatory parameter";

    my @core_dba_list = ();

    if ($registry_conf_file) {
        $self->load_registry($registry_conf_file);
        push @core_dba_list, @{Bio::EnsEMBL::Registry->get_all_DBAdaptors(-GROUP => 'core')};
    }

    for(my $r_ind=0; $r_ind<scalar(@$registry_dbs); $r_ind++) {
        $registry_dbs->[$r_ind]->{'-db_version'} = $self->param('db_version') if $self->param('db_version') and not $registry_dbs->[$r_ind]->{'-db_version'};
        Bio::EnsEMBL::Registry->load_registry_from_db( %{ $registry_dbs->[$r_ind] }, -species_suffix => $suffix_separator.$r_ind, -db_version => $registry_dbs->[$r_ind]->{'-db_version'}, -verbose => '1');
        push @core_dba_list, @{Bio::EnsEMBL::Registry->get_all_DBAdaptors(-GROUP => 'core')};
    }

    for(my $r_ind=0; $r_ind<scalar(@$registry_files); $r_ind++) {

        my $reg_content = Bio::EnsEMBL::Compara::GenomeMF->all_from_file( $registry_files->[$r_ind] );
        push @core_dba_list, @$reg_content;
    }

    return \@core_dba_list;
}


1;

