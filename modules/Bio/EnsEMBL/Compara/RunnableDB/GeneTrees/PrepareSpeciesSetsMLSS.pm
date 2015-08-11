=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PrepareSpeciesSetsMLSS

=head1 DESCRIPTION

Used to create all the species set / MLSS objects needed for a gene-tree pipeline

 - the main MLSS of the pipeline
 - all the single-species paralogues MLSS
 - all the pairwise orthologues MLSS
 - two empty species sets for reuse / nonreuse lists

If the master_db parameter is set, the Runnable will copy over the MLSS
from the master database. Otherwise, it will create new ones from the list of
all the species.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::PrepareSpeciesSetsMLSS;

use strict;
use Scalar::Util qw(looks_like_number);

use Bio::EnsEMBL::Compara::SpeciesSet;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'tree_method_link'  => 'PROTEIN_TREES',
        'reused_gdb_ids'    => [],
        'nonreused_gdb_ids' => [],
        'create_homology_mlss'  => 1,
    };
}

sub fetch_input {
    my $self = shift @_;

    if(my $reference_db = $self->param('master_db')) {
        my $reference_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $reference_db );
        $self->param('reference_dba', $reference_dba);
        warn "Storing with a reference_db ($reference_db)\n" if($self->debug());
    } else {
        $self->param('reference_dba', undef);
        warn "Storing without a reference_db\n" if($self->debug());
    }

    $self->param('genome_dbs', $self->compara_dba->get_GenomeDBAdaptor->fetch_all());

    my $method_adaptor = $self->compara_dba->get_MethodAdaptor;
    # FIXME : not all the pipelines want homologues
    $self->param('ml_ortho', $method_adaptor->fetch_by_type('ENSEMBL_ORTHOLOGUES'));
    $self->param('ml_para', $method_adaptor->fetch_by_type('ENSEMBL_PARALOGUES'));
    $self->param('ml_homoeo', $method_adaptor->fetch_by_type('ENSEMBL_HOMOEOLOGUES'));
    $self->param('ml_genetree', $method_adaptor->fetch_by_type($self->param('tree_method_link')));
}

sub _has_duplicates {
    my $a = shift;
    my %seen = ();
    map {$seen{$_}++} @$a;
    return scalar(keys %seen) != scalar(@$a) ? 1 : 0;
}

sub run {
    my $self = shift;

    # Reusability is only possible if there is a master database and if the arrays have been used
    if ($self->param('reference_dba') and (scalar(@{$self->param('reused_gdb_ids')}) or scalar(@{$self->param('nonreused_gdb_ids')}))) {
        $self->find_reusable_genomes();
    } else {
        foreach my $gdb (@{$self->param('genome_dbs')}) {
            $gdb->{is_reused} = 0;
            #next unless $gdb->is_polyploid;
            map {$_->{is_reused} = 0} @{$gdb->component_genome_dbs};
        }
    }
}

sub find_reusable_genomes {
    my $self = shift;

    # Here we check that the data is consistent

    die "Duplicates in reused_gdb_ids\n" if _has_duplicates($self->param('reused_gdb_ids'));
    die "Duplicates in nonreused_gdb_ids\n" if _has_duplicates($self->param('nonreused_gdb_ids'));

    my %all_gdbs = map {$_->dbID => $_} @{$self->param('genome_dbs')};
    my @reused_gdbs = map {$all_gdbs{$_} || die "Invalid genome_db_id $_ in 'reused_gdb_ids'\n"} @{$self->param('reused_gdb_ids')};
    my @nonreused_gdbs = map {$all_gdbs{$_} || die "Invalid genome_db_id $_ in 'nonreused_gdb_ids'\n"} @{$self->param('nonreused_gdb_ids')};

    map {$_->{is_reused} = 1} @reused_gdbs;
    map {$_->{is_reused} = 0} @nonreused_gdbs;

    foreach my $gdb (@{$self->param('genome_dbs')}) {
        next unless $gdb->is_polyploid;

        # Component GenomeDBs are missing, we need to add them
        map {$_->{is_reused} = $gdb->{is_reused}} @{$gdb->component_genome_dbs};

        # If component genomes are used, they must *all* be there
        my $components_in_core_db = $gdb->db_adaptor->get_GenomeContainer->get_genome_components;
        my $components_in_compara = $gdb->component_genome_dbs;
        die sprintf("Some %s genome components are missing from the species set !\n", $gdb->name) if scalar(@$components_in_core_db) != scalar(@$components_in_compara);
    }

    die "Some genome_dbs are missing from reused_gdb_ids and nonreused_gdb_ids\n" if grep {not defined $_->{is_reused}} @{$self->param('genome_dbs')};
}

sub write_output {
    my $self = shift;

    my $all_gdbs = $self->param('genome_dbs');
    my $ss = $self->_write_ss($all_gdbs);
    my $mlss = $self->_write_mlss( $ss, $self->param('ml_genetree') );
    $self->db->get_PipelineWideParametersAdaptor->store( {'param_name' => 'mlss_id', 'param_value' => $mlss->dbID} );

    $self->db->get_PipelineWideParametersAdaptor->store( {'param_name' => 'species_count', 'param_value' => scalar(grep {not $_->is_polyploid} @$all_gdbs)} );

    my @noncomponent_gdbs = grep {not $_->genome_component} @$all_gdbs;
    foreach my $genome_db (@noncomponent_gdbs) {
        last unless $self->param('create_homology_mlss');

        my $ssg = $self->_write_ss( [$genome_db] );
        my $mlss_pg = $self->_write_mlss( $ssg, $self->param('ml_para') );

        if ($genome_db->is_polyploid) {
            my $mlss_hg = $self->_write_mlss( $ssg, $self->param('ml_homoeo') );
        }
    }

    ## Since possible_ortholds have been removed, there are no between-species paralogs any more
    ## Also, not that in theory, we could skip the orthologs between components of the same polyploid Genome
    $self->_write_all_pairs( $self->param('ml_ortho'), [@noncomponent_gdbs]) if $self->param('create_homology_mlss');

    $self->_write_shared_ss('reuse', [grep {$_->{is_reused}} @{$self->param('genome_dbs')}] );
    $self->_write_shared_ss('nonreuse', [grep {not $_->{is_reused}} @{$self->param('genome_dbs')}] );

    # Whether all the species are reused
    $self->db->get_PipelineWideParametersAdaptor->store( {'param_name' => 'are_all_species_reused', 'param_value' => ((grep {not $_->{is_reused}} @{$self->param('genome_dbs')}) ? 0 : 1)} );

    $self->dataflow_output_id($self->input_id, 2) if grep {$_->{is_reused}} @{$self->param('genome_dbs')};
}

sub _write_shared_ss {
    my ($self, $name, $gdbs) = @_;
    my $ss = $self->_write_ss($gdbs, 1);
    $self->db->get_PipelineWideParametersAdaptor->store( {'param_name' => $name.'_ss_id', 'param_value' => $ss->dbID} );
    $self->db->get_PipelineWideParametersAdaptor->store( {'param_name' => $name.'_ss_csv', 'param_value' => join(',', -1, map {$_->dbID} @$gdbs)} );
    return $ss;
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


# Write the species-set of the given genome_dbs
# Try to reuse the data from the reference db if possible
sub _write_ss {
    my ($self, $genome_dbs, $is_local_ss) = @_;

    my $ss;
    if ($self->param('reference_dba')) {
        $ss = $self->param('reference_dba')->get_SpeciesSetAdaptor->fetch_by_GenomeDBs($genome_dbs);
        if ((not $is_local_ss) and (not $ss)) {
            die sprintf("The %s species-set could not be found in the master database\n", join('/', map {$_->name} @$genome_dbs));
        }
    }
    unless ($ss) {
        $ss = Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => $genome_dbs );
    }
    $self->compara_dba->get_SpeciesSetAdaptor->store($ss);
    return $ss;
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
        $mlss = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new( -method => $method, -species_set_obj => $ss);
    }
    $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->store($mlss);
    return $mlss;
}


1;

