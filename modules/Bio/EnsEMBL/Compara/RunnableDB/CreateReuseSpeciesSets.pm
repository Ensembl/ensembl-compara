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

Bio::EnsEMBL::Compara::RunnableDB::CreateReuseSpeciesSets

=head1 DESCRIPTION

Used to create the species sets for reused / non-reused species

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CreateReuseSpeciesSets;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::SpeciesSet;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'reused_gdb_ids'    => [],
        'nonreused_gdb_ids' => [],
    };
}

sub fetch_input {
    my $self = shift @_;

    if(my $reference_db = $self->param('master_db')) {
        my $reference_dba = $self->get_cached_compara_dba('master_db');
        $self->param('reference_dba', $reference_dba);
        warn "Storing with a reference_db ($reference_db)\n" if($self->debug());
    } else {
        $self->param('reference_dba', undef);
        warn "Storing without a reference_db\n" if($self->debug());
    }

    $self->param('genome_dbs', $self->compara_dba->get_GenomeDBAdaptor->fetch_all());
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

    $self->_write_shared_ss('reuse', [grep {$_->{is_reused}} @$all_gdbs] );
    $self->_write_shared_ss('nonreuse', [grep {not $_->{is_reused}} @$all_gdbs] );

    $self->db->hive_pipeline->add_new_or_update('PipelineWideParameters',
        'param_name' => 'species_count',
        'param_value' => scalar(grep {not $_->is_polyploid} @$all_gdbs),
    );

    # Whether all the species are reused
    $self->db->hive_pipeline->add_new_or_update('PipelineWideParameters',
        'param_name' => 'are_all_species_reused',
        'param_value' => ((grep {not $_->{is_reused}} @$all_gdbs) ? 0 : 1),
    );

    $self->dataflow_output_id(undef, 2) if grep {$_->{is_reused}} @$all_gdbs;
    $self->db->hive_pipeline->save_collections();
}


## Write a species-set that is made available pipeline-wide
sub _write_shared_ss {
    my ($self, $name, $gdbs) = @_;
    my $ss = $self->_write_ss($gdbs, 1, $name);
    $self->db->hive_pipeline->add_new_or_update('PipelineWideParameters',
        'param_name' => $name.'_ss_id',
        'param_value' => $ss->dbID,
    );
    $self->db->hive_pipeline->add_new_or_update('PipelineWideParameters',
        'param_name' => $name.'_ss_csv',
        'param_value' => join(',', -1, map {$_->dbID} @$gdbs),
    );
    return $ss;
}


# Write the species-set of the given genome_dbs
# Try to reuse the data from the reference db if possible
sub _write_ss {
    my ($self, $genome_dbs, $is_local_ss, $name) = @_;

    my $ss;
    if ($self->param('reference_dba')) {
        $ss = $self->param('reference_dba')->get_SpeciesSetAdaptor->fetch_by_GenomeDBs($genome_dbs);
        if ((not $is_local_ss) and (not $ss)) {
            die sprintf("The %s species-set could not be found in the master database\n", join('/', map {$_->name} @$genome_dbs) || 'empty');
        }
    }
    unless ($ss) {
        $ss = Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => $genome_dbs, -name => $name );
    }
    $self->compara_dba->get_SpeciesSetAdaptor->store($ss);
    return $ss;
}


1;

