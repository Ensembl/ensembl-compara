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

=cut


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PrepareSpeciesSetsMLSS

=head1 DESCRIPTION

Used to create all the species set / MLSS objects needed for a pipeline.

Given a set of GenomeDBs, this Runnable can create

 - main MLSSs (with all the genomes)
 - singleton MLSSs
 - pairwise MLSSs
 - reuse and non-reuse species-sets

If the master_db parameter is set, the Runnable will copy over the MLSS
from the master database. Otherwise, it will create new ones from the list of
all the species.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PrepareSpeciesSetsMLSS;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::CreateReuseSpeciesSets');


sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults },
        'whole_method_links'        => [],
        'singleton_method_links'    => [],
        'pairwise_method_links'     => [],
        'store_reuse_ss'            => 1,
    };
}

sub fetch_input {
    my $self = shift @_;

    $self->SUPER::fetch_input();

    my $method_adaptor = $self->compara_dba->get_MethodAdaptor;
    foreach my $cat (qw(whole singleton pairwise)) {
        my $param_name = "${cat}_method_links";
        my @a = map {$method_adaptor->fetch_by_type($_) || $self->die_no_retry("Cannot find the method_link '$_'")} @{ $self->param($param_name) };
        $self->param($param_name, \@a);
    }
}


sub write_output {
    my $self = shift;

    my $all_gdbs = $self->genome_dbs;

    my @param_names;
    @param_names = @{$self->param('param_names')} if $self->param('param_names');

    if (@{$self->param('whole_method_links')}) {
        my $ss = $self->_write_ss($all_gdbs);

        my @homology_range_indices;
        foreach my $ml (@{$self->param('whole_method_links')}) {
            my $mlss = $self->_write_mlss( $ss, $ml );

            if ($mlss->method->type eq 'PROTEIN_TREES' || $mlss->method->type eq 'NC_TREES') {
                my $homology_range_index = $self->param('reference_dba')->dbc->sql_helper->execute_single_result(
                    -SQL => 'SELECT value FROM method_link_species_set_tag WHERE method_link_species_set_id = ? AND tag = "homology_range_index"',
                    -PARAMS => [$mlss->dbID]
                );
                push(@homology_range_indices, $homology_range_index) if defined $homology_range_index;
            }

            # The last method_link listed in whole_method_links will make
            # the pipeline-wide mlss_id, unless param_names have been specified
            my $this_param_name = shift @param_names || 'mlss_id';
            $self->add_or_update_pipeline_wide_parameter($this_param_name, $mlss->dbID);
        }

        if (scalar(@homology_range_indices) == 1) {
            $self->add_or_update_pipeline_wide_parameter('homology_range_index', $homology_range_indices[0]);
        } elsif (scalar(@homology_range_indices) > 1) {
            $self->die_no_retry(
                sprintf(
                    "cannot set 'homology_range_index' pipeline-wide parameter; %d values specified",
                    scalar(@homology_range_indices),
                )
            );
        }
    }

    my @noncomponent_gdbs = grep {not $_->genome_component} @$all_gdbs;
    foreach my $genome_db (@noncomponent_gdbs) {
        last unless scalar(@{$self->param('singleton_method_links')});

        my $ssg = $self->_write_ss( [$genome_db] );

        foreach my $ml (@{$self->param('singleton_method_links')}) {
            next if ($ml->type eq 'ENSEMBL_HOMOEOLOGUES') && !$genome_db->is_polyploid;
            my $mlss = $self->_write_mlss( $ssg, $ml );
        }
    }

    ## In theory, we could skip the orthologs between components of the same polyploid Genome
    foreach my $ml (@{$self->param('pairwise_method_links')}) {
        $self->_write_all_pairs( $ml, [@noncomponent_gdbs]);
    }

    if ( $self->param('store_reuse_ss') ) {
        # Finish with the call to SUPER which will save the reuse species sets into pipeline-wide parameters
        $self->SUPER::write_output();
    } else {
        $self->db->hive_pipeline->save_collections();
    }
}


# Write a mlss for each pair of species
sub _write_all_pairs {
    my ($self, $ml, $gdbs) = @_;
    foreach my $g1 (@$gdbs) {
        foreach my $g2 (@$gdbs) {
            next if $g1->dbID >= $g2->dbID;
            my $ss12 = $self->_write_ss( [$g1, $g2] );
            my $mlss_h12 = $self->_write_mlss($ss12, $ml);
        }
    }
}


# Write the mlss of this species-set and this method
# Try to reuse the data from the reference db if possible
sub _write_mlss {
    my ($self, $ss, $method) = @_;

    my $mlss;
    if ($self->param('reference_dba')) {
        $mlss = $self->param('reference_dba')->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_id_species_set_id($method->dbID, $ss->dbID);

        if ((not $mlss) && $self->param('reference_dba')->get_MethodAdaptor->fetch_by_dbID($method->dbID)) {
            $self->die_no_retry(sprintf("The %s / %s MethodLinkSpeciesSet could not be found in the master database\n", $method->toString, $ss->toString));
        }
    }
    unless ($mlss) {
        $mlss = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new( -method => $method, -species_set => $ss);
    }
    $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->store($mlss);
    return $mlss;
}

sub genome_dbs {
    my $self = shift;

    return $self->param('genome_dbs') unless $self->param('filter_by_mlss_id');

    my $filter_mlss = $self->param('reference_dba')->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param('filter_by_mlss_id'));
    my $filter_gdbs = $filter_mlss->species_set->genome_dbs;
    my @filtered_gdbs;
    foreach my $gdb ( @{$self->param('genome_dbs')} ) {
        push @filtered_gdbs, $gdb if grep { $gdb->dbID == $_->dbID } @$filter_gdbs;
    }
    $self->param('genome_dbs', \@filtered_gdbs);
    return \@filtered_gdbs;
}

1;
