
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

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {};
}

sub fetch_input {
    my $self = shift @_;

    if ( $self->param('reuse_db') ) {
        #get compara_dba adaptor
        $self->param( 'reuse_compara_dba', Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $self->param('reuse_db') ) );
        $self->param( 'compara_dba', $self->compara_dba);
    }
    else {
        $self->warning("reuse_db hash has not been set, so cannot reuse");
        $self->param( 'reuse_this', 0 );
        return;
    }
}

sub run {
    my $self = shift;

    #Get list of genes:
	print "getting prev_hash\n" if ( $self->debug );
    my $prev_hash = hash_all_sequences_from_db( $self->param('reuse_compara_dba') );
	print "getting curr_hash\n" if ( $self->debug );
    my $curr_hash = hash_all_sequences_from_db( $self->param('compara_dba') );

    #---------------------------------------------------------------------------------
    #deleted, updated & added arent used by the logic.
    #It is just here in case we need to test which genes are different in each case.
    #flag is tha hash used my the module.
    #---------------------------------------------------------------------------------
    my ( %flag, %deleted, %updated, %added );
	print "flagging members\n" if ( $self->debug );
    check_hash_equals( $prev_hash, $curr_hash, \%flag, \%deleted, \%updated, \%added );
    print "DELETED:|" . keys(%deleted) . "|\tUPDATED:|" . keys(%updated) . "|\tADDED:|" . keys(%added) . "|\n" if ( $self->debug );

	print "undef prev_hash\n" if ( $self->debug );
    undef %$prev_hash;

	print "undef curr_hash\n" if ( $self->debug );
    undef %$curr_hash;

    #Get list of root_ids:
	print "getting list of roots\n" if ( $self->debug );
    my $root_ids = get_root_id_list( $self->param('compara_dba') );

    my %root_ids_2_update;
    $self->param( 'root_ids_2_update', \%root_ids_2_update );

    #get tree adaptor
    $self->param( 'tree_adaptor', $self->param('compara_dba')->get_GeneTreeAdaptor ) || die "Could not get GeneTreeAdaptor";

	print "looping root_ids\n" if ( $self->debug );
	#my $count = 0;
    foreach my $gene_tree_id ( keys %$root_ids ) {

		#if ( ( $count % 100 ) == 0 ) {
			#print "$count\n";
		#}
		#$count++;

        #get gene_tree
        $self->param( 'gene_tree', $self->param('tree_adaptor')->fetch_by_dbID($gene_tree_id) ) or die "Could not fetch gene_tree with gene_tree_id='$gene_tree_id'";
        my @members = @{ $self->param('gene_tree')->get_all_Members };

        foreach my $member (@members) {
            if ( exists( $flag{ $member->stable_id } ) ) {
                $root_ids_2_update{$gene_tree_id}{ $member->stable_id } = 1;
            }
        }
    }
} ## end sub run

sub write_output {
    my $self = shift;

	print "writing outs\n" if ( $self->debug );
    if ( $self->param('root_ids_2_update') ) {
        foreach my $gene_tree_id ( keys %{$self->param('root_ids_2_update')} ) {

            my $sql = 'INSERT INTO gene_tree_root_tag (root_id,tag,value) VALUES (?,?,?)';
            my $sth = $self->param('compara_dba')->dbc->prepare($sql);
            $sth->execute( $gene_tree_id, "needs_update", 1 ) || die "Could not execute ($sql)";
            $sth->finish;

            $sql = 'INSERT INTO gene_tree_root_tag (root_id,tag,value) VALUES (?,?,?)';
            $sth = $self->param('compara_dba')->dbc->prepare($sql);
            $sth->execute( $gene_tree_id, "updated_genes_list", join( ",", keys( ${$self->param('root_ids_2_update')}{$gene_tree_id} ) ) ) || die "Could not execute ($sql)";
            $sth->finish;
        }
    }
} ## end sub write_output

# ------------------------- non-interface subroutines -----------------------------------

sub check_hash_equals {
    my ( $prev_hash, $curr_hash, $flag, $deleted, $updated, $added ) = @_;

    foreach my $stable_id ( sort keys %$curr_hash ) {
        if ( !exists( $prev_hash->{$stable_id} ) ) {
            $added->{$stable_id} = 1;
            $flag->{$stable_id}  = 1;
        }
        elsif ( $curr_hash->{$stable_id} ne $prev_hash->{$stable_id} ) {
            $updated->{$stable_id} = 1;
            $flag->{$stable_id}    = 1;
        }
    }

    foreach my $stable_id ( keys %$prev_hash ) {
        if ( !exists( $curr_hash->{$stable_id} ) ) {
            $deleted->{$stable_id} = 1;
            $flag->{$stable_id}    = 1;
        }
    }
}

sub hash_all_sequences_from_db {
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

sub get_root_id_list {
    my $compara_dba = shift;

    my %root_ids;

    my $sql = "SELECT root_id AS gene_tree_id, stable_id FROM gene_tree_root WHERE tree_type = \"tree\" AND clusterset_id=\"default\"";
    my $sth = $compara_dba->dbc->prepare($sql);
    $sth->execute() || die "Could not execute ($sql)";

    while ( my ( $root_id, $stable_id ) = $sth->fetchrow() ) {
        $root_ids{$root_id} = $stable_id;
    }
    $sth->finish();

    return \%root_ids;
}

1;
