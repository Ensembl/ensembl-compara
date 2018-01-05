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
    };
}

sub fetch_input {
    my $self = shift @_;

    $self->SUPER::fetch_input();

    my $method_adaptor = $self->compara_dba->get_MethodAdaptor;
    foreach my $cat (qw(whole singleton pairwise)) {
        my $param_name = "${cat}_method_links";
        my @a = map {$method_adaptor->fetch_by_type($_) || die "Cannot find the method_link '$_'"} @{ $self->param($param_name) };
        $self->param($param_name, \@a);
    }
}


sub write_output {
    my $self = shift;

    my $all_gdbs = $self->param('genome_dbs');

    if (@{$self->param('whole_method_links')}) {
        my $ss = $self->_write_ss($all_gdbs);
        foreach my $ml (@{$self->param('whole_method_links')}) {
            my $mlss = $self->_write_mlss( $ss, $ml );
            # The last method_link listed in whole_method_links will make
            # the pipeline-wide mlss_id
            $self->db->hive_pipeline->add_new_or_update('PipelineWideParameters',
                'param_name' => 'mlss_id',
                'param_value' => $mlss->dbID
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

    # Finish with the call to SUPER which will save the pipeline-wide parameters
    $self->SUPER::write_output();
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
        if ((not $mlss) and $self->param('reference_dba')->get_MethodAdaptor->fetch_by_dbID($method->dbID)) {
            die sprintf("The %s / %s MethodLinkSpeciesSet could not be found in the master database\n", $method->toString, $ss->toString);
        }
    }
    unless ($mlss) {
        $mlss = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new( -method => $method, -species_set => $ss);
    }
    $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->store($mlss);
    return $mlss;
}


1;

