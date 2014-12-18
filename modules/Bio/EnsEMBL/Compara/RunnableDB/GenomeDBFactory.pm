=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory

=head1 DESCRIPTION

This Runnable flows some GenomeDB ids, depending on a few parameters.
The source is one of (by decreasing priority):
 - a species set (given by species_set_id)
 - a method_link_species_set (given by mlss_id)
 - all the GenomeDBs

The default is to flow all the GenomeDBs fetched by the previous rule, but
specific kinds of GenomeDBs can be controlled individually:
 - polyploid_genomes : principal GenomeDB of polyploid genomes
 - component_genomes : component GenomeDBs of polyploid genomes
 - normal_genomes : GenomeDBs not related to polyploid genomes
Those 3 parameters are set to 1 by default, but can be set to 0 to prevent
dataflowing some GenomeDBs.

IDs are flown on branch "fan_branch_code" (default: 2)

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GenomeDBFactory;

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        # set to 0 to remove some genomes from the factory
        'polyploid_genomes' => 1,
        'component_genomes' => 1,
        'normal_genomes'    => 1,

        'extra_parameters'  => [],

        'fan_branch_code'   => 2,
    }
}

sub fetch_input {
    my $self = shift @_;

    # We try our best to get a list of GenomeDBs
    my $genome_dbs;

    if ($self->param('species_set_id')) {
        my $species_set_id = $self->param_required('species_set_id');
        die unless looks_like_number($species_set_id);
        # Currently, empty species sets cannot be represented
        my $species_set    = $self->compara_dba()->get_SpeciesSetAdaptor->fetch_by_dbID($species_set_id); # or die "Could not fetch ss with dbID=$species_set_id";
        $genome_dbs        = $species_set ? $species_set->genome_dbs() : [];

    } elsif ($self->param('mlss_id')) {
        my $mlss_id = $self->param('mlss_id');
        my $mlss    = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id) or die "Could not fetch mlss with dbID=$mlss_id";
        $genome_dbs = $mlss->species_set_obj->genome_dbs;

    } else {
        $genome_dbs = $self->compara_dba->get_GenomeDBAdaptor->fetch_all();
    }

    # Now we apply the filters
    # Note that to filter out some GenomeDBs, we keep the other ones !
    $genome_dbs = [grep {not $_->is_polyploid} @$genome_dbs] if not $self->param('polyploid_genomes');
    $genome_dbs = [grep {not $_->genome_component} @$genome_dbs] if not $self->param('component_genomes');
    $genome_dbs = [grep {$_->is_polyploid or $_->genome_component} @$genome_dbs] if not $self->param('normal_genomes');

    $self->param('genome_dbs', $genome_dbs);
}


sub write_output {
    my $self = shift;

    # Dataflow the GenomeDBs
    foreach my $gdb (@{$self->param('genome_dbs')}) {
        my $h = { 'genome_db_id' => $gdb->dbID };
        foreach my $p (@{$self->param('extra_parameters')}) {
            $h->{$p} = $gdb->$p;
        }
        $self->dataflow_output_id($h, $self->param('fan_branch_code'));
    }
}

1;
