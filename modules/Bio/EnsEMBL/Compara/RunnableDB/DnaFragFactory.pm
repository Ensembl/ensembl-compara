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

Bio::EnsEMBL::Compara::RunnableDB::DnaFragFactory

=head1 DESCRIPTION

This Runnable flows the DnaFrags of a genome. The genome is referred to
by its dbID (genome_db_id) or its production name (genome_db_name).

By default, all the DnaFrags will be dataflown, but there are two ways
of restricting the list:
 - only_karyotype: only return the DnaFrags that are on the karyotype
 - filters: extra arguments to be given to DnaFragAdaptor::fetch_all_by_GenomeDB
   e.g. { -COORD_SYSTEM_NAME => 'scaffold', -CELLULAR_COMPONENT => 'NUC' }

IDs are flown on branch "fan_branch_code" (default: 2)

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DnaFragFactory;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Scalar qw(assert_integer);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'only_karyotype'    => 0,
        'filters'           => {},

        # List of DnaFrag attribute names that will be added to the output_ids
        'extra_parameters'  => [],

        'fan_branch_code'   => 2,

        # Definition of the GenomeDB
        'genome_db_id'    => undef,
        'genome_db_name'  => undef,
    }
}

sub fetch_input {
    my $self = shift @_;

    # We try our best to get the GenomeDB
    my $genome_db;

    if (my $genome_db_id = $self->param('genome_db_id')) {
        assert_integer($genome_db_id, 'genome_db_id');
        $genome_db = $self->compara_dba()->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) or die "Could not fetch GenomeDB with dbID=$genome_db_id";

    } elsif (my $genome_db_name = $self->param_required('genome_db_name')) {
        $genome_db = $self->compara_dba()->get_GenomeDBAdaptor->fetch_by_name_assembly($genome_db_name) or die "Could not fetch GenomeDB with name=$genome_db_name";

    }

    my $dnafrags;
    if ($self->param('only_karyotype')) {
        $dnafrags = $self->compara_dba()->get_DnaFragAdaptor->fetch_all_karyotype_DnaFrags_by_GenomeDB($genome_db);
    } else {
        $dnafrags = $self->compara_dba()->get_DnaFragAdaptor->fetch_all_by_GenomeDB($genome_db, %{$self->param_required('filters')});
    }
    $self->param('dnafrags', $dnafrags);
}


sub write_output {
    my $self = shift;

    foreach my $dnafrag (@{$self->param('dnafrags')}) {
        my $h = { 'dnafrag_id' => $dnafrag->dbID };
        foreach my $p (@{$self->param('extra_parameters')}) {
            $h->{$p} = $dnafrag->$p;
        }
        $self->dataflow_output_id($h, $self->param('fan_branch_code'));
    }
}

1;
