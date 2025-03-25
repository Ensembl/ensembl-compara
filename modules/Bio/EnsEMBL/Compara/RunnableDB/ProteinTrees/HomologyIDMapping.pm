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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping

=cut

=head1 SYNOPSIS

Required inputs:
	- homology mlss_id
	- optionally a "previous_mlss_id"
	- URL pointing to the previous release database
	- pointer to current database (usually doesn't require explicit definition)

Example:
	standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping -mlss_id 20285 -compara_db mysql://ensro@compara5/cc21_protein_trees_no_reuse_86 -prev_rel_db mysql://ensro@compara2/mp14_protein_trees_85

=cut

=head1 DESCRIPTION

Homology ids can change from one release to the next. This runnable detects
the homology id from the previous release database based on the gene members
of the current homologies.

Data should be flowed out to a table to be queried later by pipelines aiming
to reuse homology data.

=cut

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::CopyData qw(:insert);
use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;

    my $mlss_id         = $self->param_required('mlss_id');
    my $prev_mlss_id    = $self->param('previous_mlss_id');

    if (defined $prev_mlss_id) {
        if ( $self->param_exists('prev_homology_flatfile') ) {
            $self->_fetch_and_map_previous_homologies_from_file;
        } else {
            $self->_fetch_and_map_previous_homologies_from_db;
        }
    } else {
        $self->param( 'homology_mapping', [] );
    }
}

sub _fetch_and_map_previous_homologies_from_db {
    my ($self) = @_;

    $self->compara_dba->dbc->disconnect_if_idle;

    my $previous_mlss_id        = $self->param('previous_mlss_id');
    my $previous_compara_dba    = $self->get_cached_compara_dba('prev_rel_db');
    my $previous_homologies     = $previous_compara_dba->get_HomologyAdaptor->fetch_all_by_MethodLinkSpeciesSet($previous_mlss_id);

    my $sms = Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies($previous_compara_dba->get_AlignedMemberAdaptor, $previous_homologies);
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers($previous_compara_dba->get_GeneMemberAdaptor, $sms);
    $previous_compara_dba->dbc->disconnect_if_idle;
    undef $sms;

    my %hash_previous_homologies;
    foreach my $prev_homology (@$previous_homologies) {
        $hash_previous_homologies{$prev_homology->_unique_homology_key} = $prev_homology->dbID;
    }
    undef $previous_homologies;

    my $mlss_id             = $self->param('mlss_id');
    my $current_homologies  = $self->compara_dba->get_HomologyAdaptor->fetch_all_by_MethodLinkSpeciesSet($mlss_id);
    $sms = Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies($self->compara_dba->get_AlignedMemberAdaptor, $current_homologies);
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers($self->compara_dba->get_GeneMemberAdaptor, $sms);
    $self->compara_dba->dbc->disconnect_if_idle;

    my @homology_mapping;
    foreach my $curr_homology (@$current_homologies) {
        my $prev_homology_id    = $hash_previous_homologies{$curr_homology->_unique_homology_key};

        push( @homology_mapping, [$mlss_id, $prev_homology_id, $curr_homology->dbID] ) if $prev_homology_id;

    }

    $self->param( 'homology_mapping', \@homology_mapping );
}

sub _fetch_and_map_previous_homologies_from_file {
    my ($self) = @_;

    my $mlss_id = $self->param('mlss_id');
    my (%hash_previous_homologies, @homology_mapping);

    my $prev_homology_flatfile = $self->param_required('prev_homology_flatfile');
    unless ( -e $prev_homology_flatfile ) {
        # it's a brand new homology and no previous dump exists
        $self->param('homology_mapping', []);
        return;
    }
    
    open(my $p_hom_handle, '<', $prev_homology_flatfile) or die "Cannot read previous homologies from $prev_homology_flatfile";
    my $pff_header = <$p_hom_handle>;
    my @pff_head_cols = split(/\s+/, $pff_header);
    while ( my $line = <$p_hom_handle> ) {
        my $row = map_row_to_header($line, \@pff_head_cols);
        my $homology_key = $self->_unique_homology_key_from_rowhash($row);
        $hash_previous_homologies{$homology_key} = $row->{homology_id};
    }
    close $p_hom_handle;
    
    my $curr_homology_flatfile = $self->param_required('homology_flatfile');
    open(my $hom_handle, '<', $curr_homology_flatfile) or die "Cannot read current homologies from $curr_homology_flatfile";
    my $hff_header = <$hom_handle>;
    my @hff_head_cols = split(/\s+/, $hff_header);
    while ( my $line = <$hom_handle> ) {
        my $row = map_row_to_header($line, \@hff_head_cols);
        my $curr_homology_id = $row->{homology_id};
        my $homology_key = $self->_unique_homology_key_from_rowhash($row);
        my $prev_homology_id = $hash_previous_homologies{$homology_key};
        
        push( @homology_mapping, [$prev_homology_id, $curr_homology_id] ) if $prev_homology_id;
    }
    close $hom_handle;
        
    $self->param( 'homology_mapping', \@homology_mapping );
}


sub _unique_homology_key_from_rowhash {
    my ($self, $row) = @_;

    my $member = { genome_db_id => $row->{genome_db_id}, stable_id => $row->{stable_id} };
    my $homology_member = { genome_db_id => $row->{homology_genome_db_id}, stable_id => $row->{homology_stable_id} };

    my @seq_members = sort {
        $a->{genome_db_id} <=> $b->{genome_db_id}
        || $a->{stable_id} cmp $b->{stable_id}
    } ($member, $homology_member);

    my @seq_member_keys = map { $_->{genome_db_id} . '|' . $_->{stable_id} } @seq_members;

    return join('|', @seq_member_keys);
}


sub write_output {
    my $self = shift;

    my $homology_mapping = $self->param('homology_mapping');
    my $homology_mapping_file = $self->param_required('homology_mapping_flatfile');
    print "Writing mapping to $homology_mapping_file" if $self->debug;
    open( my $hmfh, '>', $homology_mapping_file );
    print $hmfh "prev_release_homology_id\tcurr_release_homology_id\n";
    foreach my $map ( @$homology_mapping ) {
        print $hmfh join("\t", @$map) . "\n";
    }
    close $hmfh;
}

1;
