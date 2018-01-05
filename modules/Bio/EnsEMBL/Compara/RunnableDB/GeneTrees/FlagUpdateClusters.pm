
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

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::FlagUpdateClusters

=head1 DESCRIPTION

1) This module loops through all the genes from the current and previous databases.

2) Identifies the genes that have been updated, deleted or added.

3) Checks for all these flagged genes (%flagged) in the list of members from all the root_ids and updated the flag "needs_update" in the gene_tree_root_tag table. 

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::FlagUpdateClusters;

use strict;
use warnings;
use Data::Dumper;

use Bio::EnsEMBL::Compara::Utils::CopyData qw(:insert);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;

    #get reuse_compara_dba adaptor
    $self->param( 'reuse_compara_dba', $self->get_cached_compara_dba('reuse_db') );
}

sub run {
    my $self = shift;

    #Get list of genes:
    print "getting prev_hash\n" if ( $self->debug );
    my $prev_hash = _hash_all_sequences_from_db( $self->param('reuse_compara_dba') );
    print "getting curr_hash\n" if ( $self->debug );
    my $curr_hash = _hash_all_sequences_from_db( $self->param('compara_dba') );
    print "getting reused vs current seq_member_ids map\n" if ( $self->debug );
    my $seq_member_id_map = _seq_member_map( $self->param('reuse_compara_dba'), $self->param('compara_dba') );
    $self->param( 'seq_member_id_map', $seq_member_id_map );

    #---------------------------------------------------------------------------------
    #deleted (members that existed in the previous mlss_id but dont exist in the current mlss_id), updated & added arent used by the logic.
    #deleted: is not used at all, but lets keep it here for debugging purpouse.
    #It is just here in case we need to test which genes are different in each case.
    #flag is that hash used my the module.
    #---------------------------------------------------------------------------------
    my ( %flag, %deleted, %updated, %added );
    print "flagging members on the sequence level\n" if ( $self->debug );
    _check_hash_equals( $prev_hash, $curr_hash, \%flag, \%deleted, \%updated, \%added );
    print "DELETED:|" . keys(%deleted) . "|\tUPDATED:|" . keys(%updated) . "|\tADDED:|" . keys(%added) . "|\n" if ( $self->debug );

    print "undef prev_hash\n" if ( $self->debug );
    undef %$prev_hash;

    print "undef curr_hash\n" if ( $self->debug );
    undef %$curr_hash;

    #Get list of current_stable_ids:
    print "getting list of roots\n" if ( $self->debug );
    my ( $current_stable_ids, $reused_stable_ids ) = $self->_get_stable_id_root_id_list( $self->param('compara_dba'), $self->param('reuse_compara_dba') );
    $self->param( 'current_stable_ids', $current_stable_ids );
    $self->param( 'reused_stable_ids',  $reused_stable_ids );

    my %root_ids_2_update;
    $self->param( 'root_ids_2_update', \%root_ids_2_update );

    my %root_ids_2_add;
    $self->param( 'root_ids_2_add', \%root_ids_2_add );

    my %root_ids_2_delete;
    $self->param( 'root_ids_2_delete', \%root_ids_2_delete );

    #get current tree adaptor
    $self->param( 'current_tree_adaptor', $self->param('compara_dba')->get_GeneTreeAdaptor ) || die "Could not get current GeneTreeAdaptor";

    #get reused tree adaptor
    $self->param( 'reused_tree_adaptor', $self->param('reuse_compara_dba')->get_GeneTreeAdaptor ) || die "Could not get reused GeneTreeAdaptor";

    print "looping current_stable_ids\n" if ( $self->debug );
    foreach my $current_stable_id ( keys %{$current_stable_ids} ) {

        my $gene_tree_id = $current_stable_ids->{$current_stable_id};

        #get current_gene_tree
        my $current_gene_tree = $self->param('current_tree_adaptor')->fetch_by_dbID($gene_tree_id) or die "Could not fetch current_gene_tree with gene_tree_id='$gene_tree_id'";
        $self->throw("no input current_gene_tree") unless $current_gene_tree;
        my @current_members = @{ $current_gene_tree->get_all_Members };
        my $num_of_members  = scalar(@current_members);

        #get reused_gene_tree
        my $reused_gene_tree = $self->param('reused_tree_adaptor')->fetch_by_stable_id($current_stable_id);

        #There is no need for both array and hash structures here. Should change code to use only the hash!
        my @reused_members;
        my %reused_members_hash;
        my %current_members_hash;

        if ($reused_gene_tree) {
            @reused_members = @{ $reused_gene_tree->get_all_Members };

            foreach my $member (@reused_members) {
                my $reused_stable_id = $member->stable_id;
                $reused_members_hash{$reused_stable_id} = 1;
            }
        }

        foreach my $current_member (@current_members) {

            $current_members_hash{ $current_member->stable_id } = 1;

            #updated:
            if ( exists( $updated{ $current_member->stable_id } ) ) {
                $root_ids_2_update{$gene_tree_id}{ $current_member->stable_id } = 1;

                #print "\t$gene_tree_id:UPD:".$current_member->stable_id."\n";
            }

            #added
            if ( exists( $added{ $current_member->stable_id } ) ) {
                $root_ids_2_add{$gene_tree_id}{ $current_member->stable_id } = 1;

                #print "\t$gene_tree_id:ADD:".$current_member->stable_id."\n";
            }

            if ($reused_gene_tree) {
                if ( !exists( $reused_members_hash{ $current_member->stable_id } ) && ( !exists( $added{ $current_member->stable_id } ) ) && ( !exists( $updated{ $current_member->stable_id } ) ) ) {
                    $root_ids_2_add{$gene_tree_id}{ $current_member->stable_id } = 1;
                }
            }
        }

        if ($reused_gene_tree) {
            foreach my $reused_member (@reused_members) {

                #deleted
                if ( exists( $deleted{ $reused_member->stable_id } ) ) {
                    $root_ids_2_delete{$gene_tree_id}{ $reused_member->stable_id } = 1;

                    #print "\t$gene_tree_id:DEL:" . $reused_member->stable_id . "\n";
                }

                # Removing members that are present in the reused tree but not in the current tree. But have the same sequence.
                #  this happens if there were diffences in the clustering, given that the sequences were the same they were not caught by previous MD5 checksum tests.
                if ( !$current_members_hash{ $reused_member->stable_id } ) {
                    $root_ids_2_delete{$gene_tree_id}{ $reused_member->stable_id } = 1;
                }

            }
            $reused_gene_tree->release_tree;
        }
        else {

            #print "Could not fetch reused tree with with stable_id=$current_stable_id. Tree will be build from scratch\n" if ($self->debug);
            $current_gene_tree->store_tag( 'new_build', 1 ) || die "Could not store_tag 'new_build'";
        }

        my $members_2_change = scalar( keys( %{ $root_ids_2_add{$gene_tree_id} } ) ) + scalar( keys( %{ $root_ids_2_update{$gene_tree_id} } ) );

        #print "Memebers to change (add+update): $members_2_change | members to delete: " . scalar( keys( %{ $root_ids_2_delete{$gene_tree_id} } ) ) . "\n" if ($self->debug);
        if ( ( $members_2_change/scalar(@current_members) ) >= $self->param_required('update_threshold_trees') ) {
            $current_gene_tree->store_tag( 'new_build', 1 ) || die "Could not store_tag 'new_build'";
        }

        #releasing tree from memory
        $current_gene_tree->release_tree;

    } ## end foreach my $current_stable_id...
} ## end sub run

sub write_output {
    my $self = shift;

    print "writing outs\n" if ( $self->debug );

    #-----------------------------------------------------------------------------------------------------------------------------------------------
    # When a genome is updated it may contain the same sequences and stable ids, but the seq_member_ids will be different
    #   since it was re-inserted into the database.
    # This will cause the trees copy from the previous database to fail, since the old seq_member_ids will not be the same for the current database.
    # We just store the mapping now, it will later be used by copy_trees_from_previous_release.
    #-----------------------------------------------------------------------------------------------------------------------------------------------

    my @mapping_data;
    foreach my $stable_id ( keys %{ $self->param('seq_member_id_map') } ) {
        push(@mapping_data, [ $stable_id, $self->param('seq_member_id_map')->{$stable_id}->{'reused'}, $self->param('seq_member_id_map')->{$stable_id}->{'current'} ]);
    }
    bulk_insert($self->compara_dba->dbc, 'seq_member_id_current_reused_map', \@mapping_data, ['stable_id', 'seq_member_id_reused', 'seq_member_id_current']);
    @mapping_data= (); # To free the memory

    my %flagged;
    foreach my $current_stable_id ( keys %{ $self->param('current_stable_ids') } ) {

        my $gene_tree_id = $self->param('current_stable_ids')->{$current_stable_id};

        my $gene_tree = $self->param('current_tree_adaptor')->fetch_by_dbID($gene_tree_id) or die "Could not fetch gene_tree with gene_tree_id='$gene_tree_id'";

        #root_ids_2_update
        if ( keys( %{ $self->param('root_ids_2_update')->{$gene_tree_id} } ) ) {
            if ( !$flagged{$gene_tree_id} ) {
                $gene_tree->store_tag( 'needs_update',        1 ) || die "Could not store_tag 'needs_update' for $gene_tree_id";
                $gene_tree->store_tag( 'only_needs_deleting', 0 ) || die "Could not store_tag 'only_needs_deleting' for $gene_tree_id";
            }
            $gene_tree->store_tag( 'updated_genes_list', join( ",", keys( %{ $self->param('root_ids_2_update')->{$gene_tree_id} } ) ) ) ||
              die "Could not store_tag 'updated_genes_list' for $gene_tree_id";
            $flagged{$gene_tree_id} = 1;
        }

        #root_ids_2_add
        if ( keys( %{ $self->param('root_ids_2_add')->{$gene_tree_id} } ) ) {
            if ( !$flagged{$gene_tree_id} ) {
                $gene_tree->store_tag( 'needs_update',        1 ) || die "Could not store_tag 'needs_update' for $gene_tree_id";
                $gene_tree->store_tag( 'only_needs_deleting', 0 ) || die "Could not store_tag 'only_needs_deleting' for $gene_tree_id";
            }
            $gene_tree->store_tag( 'added_genes_list', join( ",", keys( %{ $self->param('root_ids_2_add')->{$gene_tree_id} } ) ) ) ||
              die "Could not store_tag 'added_genes_list' for $gene_tree_id";
            $flagged{$gene_tree_id} = 1;
        }

        #root_ids_2_delete
        if ( keys( %{ $self->param('root_ids_2_delete')->{$gene_tree_id} } ) ) {
            if ( ( !$gene_tree->has_tag('only_needs_deleting') ) && ( !$gene_tree->has_tag('needs_update') ) ) {
                $gene_tree->store_tag( 'only_needs_deleting', 1 ) || die "Could not store_tag 'only_needs_deleting' for $gene_tree_id";
            }
            $gene_tree->store_tag( 'deleted_genes_list', join( ",", keys( %{ $self->param('root_ids_2_delete')->{$gene_tree_id} } ) ) ) ||
              die "Could not store_tag 'deleted_genes_list' for $gene_tree_id";
        }

        if ( ( !keys( %{ $self->param('root_ids_2_update')->{$gene_tree_id} } ) ) &&
             ( !keys( %{ $self->param('root_ids_2_add')->{$gene_tree_id} } ) ) &&
             ( !keys( %{ $self->param('root_ids_2_delete')->{$gene_tree_id} } ) ) ) {
            $gene_tree->store_tag( 'identical_copy', 1 ) || die "Could not store_tag 'identical_copy' for $gene_tree_id";
        }
    } ## end foreach my $current_stable_id...

} ## end sub write_output

##########################################
#
# internal methods
#
##########################################

#This function checks the differences between all the sequences loaded in the current database vs. the re-used database.
#It will not catch more subtles cases where sequences are the same but the were not present in the re-used tree.
sub _check_hash_equals {
    my ( $prev_hash, $curr_hash, $flag, $deleted, $updated, $added ) = @_;

    foreach my $stable_id ( keys %$curr_hash ) {
        if ( !exists( $prev_hash->{$stable_id} ) ) {
            $added->{$stable_id} = 1;
        }
        else {
            if ( $curr_hash->{$stable_id} ne $prev_hash->{$stable_id} ) {
                $updated->{$stable_id} = 1;
            }
        }
    }

    foreach my $stable_id ( keys %$prev_hash ) {
        if ( !exists( $curr_hash->{$stable_id} ) ) {
            $deleted->{$stable_id} = 1;
        }
    }
}

sub _hash_all_sequences_from_db {
    my $compara_dba = shift;

    my %sequence_set;

    my $sql = "SELECT stable_id, MD5(sequence) FROM seq_member JOIN sequence USING (sequence_id)";
    my $sth = $compara_dba->dbc->prepare($sql);
    $sth->execute() || die "Could not execute ($sql)";

    while ( my ( $stable_id, $seq_md5 ) = $sth->fetchrow() ) {
        $sequence_set{$stable_id} = lc $seq_md5;
    }
    $sth->finish();

    return \%sequence_set;
}

sub _get_stable_id_root_id_list {
    my ( $self, $compara_dba, $reuse_compara_dba ) = @_;

    my %current_stable_ids;
    my %reused_stable_ids;

    #current root_ids and stable_ids
    my $sql_current = "SELECT root_id, stable_id FROM gene_tree_root WHERE tree_type = \"tree\" AND clusterset_id=\"default\"";
    my $sth_current = $compara_dba->dbc->prepare($sql_current) || die "Could not prepare query.";
    $sth_current->execute() || die "Could not execute ($sql_current)";

    while ( my ( $root_id, $current_stable_id ) = $sth_current->fetchrow() ) {
        $current_stable_ids{$current_stable_id} = $root_id;
    }
    $sth_current->finish();

    #previous root_ids and stable_ids
    my $sql_reused = "SELECT root_id, stable_id FROM gene_tree_root WHERE tree_type = \"tree\" AND clusterset_id=\"default\" AND stable_id IS NOT NULL";
    my $sth_reused = $reuse_compara_dba->dbc->prepare($sql_reused) || die "Could not prepare query.";
    $sth_reused->execute() || die "Could not execute ($sql_reused)";

    while ( my ( $root_id, $reused_stable_id ) = $sth_reused->fetchrow() ) {
        $reused_stable_ids{$reused_stable_id} = $root_id;
    }
    $sth_reused->finish();

    return ( \%current_stable_ids, \%reused_stable_ids );
} ## end sub _get_stable_id_root_id_list

sub _seq_member_map {
    my $reuse_compara_dba = shift;
    my $compara_dba       = shift;

    my %map;

    my $sql_reuse = "SELECT stable_id, seq_member_id FROM seq_member";
    my $sth_reuse = $reuse_compara_dba->dbc->prepare($sql_reuse);
    $sth_reuse->execute() || die "Could not execute ($sql_reuse)";

    while ( my ( $stable_id_reuse, $seq_member_id_reuse ) = $sth_reuse->fetchrow() ) {
        $map{$stable_id_reuse}{'reused'} = $seq_member_id_reuse;
    }
    $sth_reuse->finish();

    my $sql_current = "SELECT stable_id, seq_member_id FROM seq_member";
    my $sth_current = $compara_dba->dbc->prepare($sql_current);
    $sth_current->execute() || die "Could not execute ($sql_current)";

    while ( my ( $stable_id_current, $seq_member_id_current ) = $sth_current->fetchrow() ) {
        $map{$stable_id_current}{'current'} = $seq_member_id_current;
    }
    $sth_current->finish();

    return \%map;
} ## end sub _seq_member_map

1;
