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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ResyncIds

=head1 DESCRIPTION

This module rewrite the genomic_align(_block) entries so that the dbIDs are in the range of method_link_species_set_id * 10**10

=head1 CONTACT

Post questions to the Ensembl development list: http://lists.ensembl.org/mailman/listinfo/dev


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ResyncIds;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::CopyData qw(:row_copy);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;

    my $out_of_sync_mlss_id = $self->param_required('out_of_sync_mlss_id');
    my $out_of_sync_mlss    = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($out_of_sync_mlss_id);

    my $master_dba          = $self->get_cached_compara_dba('master_db');
    my $master_method       = $master_dba->get_MethodAdaptor->fetch_by_type($out_of_sync_mlss->method->type);
    my @master_genome_dbs   = map {$master_dba->get_GenomeDBAdaptor->fetch_by_name_assembly($_->name, $_->assembly) || die "Cannot find ".$_->name." / ".$_->assembly} @{$out_of_sync_mlss->species_set->genome_dbs};
    my $master_mlss         = $master_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_GenomeDBs($master_method->type, \@master_genome_dbs);

    print $master_method->toString, "\n";
    print $_->toString, "\n" for @master_genome_dbs;

    $self->_assert_dbIDs_are_different([$master_mlss], [$out_of_sync_mlss]);
    $self->_assert_dbIDs_are_different([$master_mlss->species_set], [$out_of_sync_mlss->species_set]);
    #$self->_assert_dbIDs_are_different(\@master_genome_dbs, $out_of_sync_mlss->species_set->genome_dbs);

    $self->param('master_dbc', $master_dba->dbc);
    $self->param('master_mlss', $master_mlss);
    $self->param('out_of_sync_mlss', $out_of_sync_mlss);
    $self->param('genome_db_id_mapping', [[$out_of_sync_mlss->species_set->genome_dbs->[0]->dbID, $master_genome_dbs[0]->dbID],
                                          [$out_of_sync_mlss->species_set->genome_dbs->[1]->dbID, $master_genome_dbs[1]->dbID]]);
}


sub run {
    my $self = shift;

    my $genome_db_id_mapping    = $self->param('genome_db_id_mapping');

    $self->call_within_transaction(sub {
        my $dbc = $self->compara_dba->dbc;

        ## 1. Use the correct MLSS
        # Copy new MLSS
        copy_data_with_foreign_keys_by_constraint($self->param('master_dbc'), $dbc, 'method_link_species_set', 'method_link_species_set_id', $self->param('master_mlss')->dbID, undef, 1);
        # Change mlss_id
        for my $table_name (qw(genomic_align genomic_align_block method_link_species_set_tag)) {
            $dbc->do("UPDATE $table_name SET method_link_species_set_id = ? WHERE method_link_species_set_id = ?", undef, $self->param('master_mlss')->dbID, $self->param('out_of_sync_mlss_id'));
        }
        # Delete old MLSS
        $dbc->do('DELETE FROM method_link_species_set WHERE method_link_species_set_id = ?', undef, $self->param('out_of_sync_mlss_id'));
        # Change species_set_id
        $dbc->do('UPDATE method_link_species_set SET species_set_id = ? WHERE species_set_id = ?', undef, $self->param('master_mlss')->species_set->dbID, $self->param('out_of_sync_mlss')->species_set->dbID);
        $dbc->do('DELETE FROM species_set WHERE species_set_id = ?', undef, $self->param('out_of_sync_mlss')->species_set->dbID);
        $dbc->do('DELETE FROM species_set_header WHERE species_set_id = ?', undef, $self->param('out_of_sync_mlss')->species_set->dbID);

        ## 2. Use the correct DnaFrags
        $self->_update_dnafrags($dbc, @{$genome_db_id_mapping->[0]});
        $self->_update_dnafrags($dbc, @{$genome_db_id_mapping->[1]});

        ## 3. Delete the old genome_db_ids
        $dbc->do(sprintf('DELETE FROM genome_db WHERE genome_db_id IN (%s) AND genome_db_id NOT IN (%s)', join(',', map {$_->dbID} @{$self->param('out_of_sync_mlss')->species_set->genome_dbs}), join(',', map {$_->dbID} @{$self->param('master_mlss')->species_set->genome_dbs})));
    } );
}


sub _update_dnafrags {
    my ($self, $dbc, $old_genome_db_id, $new_genome_db_id) = @_;

    my $offset      = 1_000_000_000;

    ## 1. Shift old DnaFrags
    # Make a fake genome_db_id
    $dbc->do("INSERT INTO genome_db SELECT genome_db_id+$offset, taxon_id, name, assembly, genebuild, has_karyotype, is_high_coverage, genome_component, strain_name, display_name, locator, first_release, last_release FROM genome_db WHERE genome_db_id = ?", undef, $old_genome_db_id);
    # Duplicate DnaFrags
    $dbc->do("INSERT INTO dnafrag SELECT dnafrag_id+$offset, length, name, genome_db_id+$offset, coord_system_name, cellular_component, is_reference, codon_table_id FROM dnafrag WHERE genome_db_id = ?", undef, $old_genome_db_id);
    # Link to shifted DnaFrags
    $dbc->do("UPDATE genomic_align JOIN dnafrag USING (dnafrag_id) SET genomic_align.dnafrag_id = genomic_align.dnafrag_id+$offset WHERE genome_db_id = ?", undef, $old_genome_db_id);
    # Remove unshifted DnaFrags
    $dbc->do("DELETE FROM dnafrag WHERE genome_db_id = ?", undef, $old_genome_db_id);

    ## 2. Bring the new DnaFrags in
    # Copy new DnaFrags
    copy_data_with_foreign_keys_by_constraint($self->param('master_dbc'), $dbc, 'dnafrag', 'genome_db_id', $new_genome_db_id);
    # Link to new DnaFrags
    $dbc->do('UPDATE genomic_align ga JOIN dnafrag d1 USING (dnafrag_id) JOIN dnafrag d2 USING (name) SET ga.dnafrag_id = d2.dnafrag_id WHERE d1.genome_db_id = ? AND d2.genome_db_id = ?', undef, $old_genome_db_id+$offset, $new_genome_db_id);

    ## 3. Should be able to delete the shifted old DnaFrags and the fake genome_db_id
    $dbc->do("DELETE FROM dnafrag WHERE genome_db_id = ?", undef, $old_genome_db_id+$offset);
    $dbc->do("DELETE FROM genome_db WHERE genome_db_id = ?", undef, $old_genome_db_id+$offset);
}


sub _assert_dbIDs_are_different {
    my ($self, $objects1, $objects2) = @_;

    my %set1 = (map {$_->dbID => $_} @$objects1);
    my %set2 = (map {$_->dbID => $_} @$objects2);

    if (my @intersection = grep {$set1{$_->dbID}} @$objects2) {
        die "dbID colllision between the master database and the compara database:\n"
            . join("\n", map {sprintf("%d\n - [master] %s\n - [compara] %s\n", $_->dbID, $set1{$_->dbID}->toString, $_->toString)} @intersection);
    }
}

1;
