
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

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassify

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMerSearch;

use strict;
use warnings;

use DBI qw(:sql_types);

use Time::HiRes qw/time gettimeofday tv_interval/;
use Data::Dumper;

use Bio::EnsEMBL::Compara::MemberSet;
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:insert);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my ($self) = @_;

    $self->param_required('hmmer_home');
    $self->param_required('library_basedir');
    $self->param_required('library_name');

    #need to add some quality check on the HMM profile, e.g. expecting X number of profiles to be in the concatenated file, etc.
    $self->param( 'query_set', Bio::EnsEMBL::Compara::MemberSet->new( -members => $self->_get_queries ) );
    $self->param( 'all_hmm_annots', {} );
}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs hmmsearch
    Returns :   none
    Args    :   none

=cut

sub run {
    my ($self) = @_;

    $self->_dump_sequences_to_workdir;
    $self->_run_HMM_search;
}

sub write_output {
    my ($self)         = @_;
    my $adaptor        = $self->compara_dba->get_HMMAnnotAdaptor();
    my $all_hmm_annots = $self->param('all_hmm_annots');

    if ( $self->param('store_all_hits') ) {

        my $target_table = $self->param_required('target_table');

        #Individual queries are too slow in this case, so we need to bulk the INSERT statements.
        my @bulk_array;

        foreach my $seq_id ( keys %{ $self->param('all_hmm_annots') } ) {
            foreach my $hmm_id ( keys %{ $self->param('all_hmm_annots')->{$seq_id} } ) {
                #$adaptor->store_hmmclassify_all_results( $seq_id, $hmm_id, $all_hmm_annots->{$seq_id}->{$hmm_id}, $target_table );
                my @hit_array = [ $seq_id, $hmm_id, $all_hmm_annots->{$seq_id}->{$hmm_id}->{'eval'}, $all_hmm_annots->{$seq_id}->{$hmm_id}->{'score'}, $all_hmm_annots->{$seq_id}->{$hmm_id}->{'bias'} ];
                push(@bulk_array, @hit_array);
            }
        }

        #Store all at once:
        print "Storing all the hits at once:\n" if ($self->debug);
        bulk_insert($self->compara_dba->dbc, 'hmm_thresholding', \@bulk_array, ['seq_member_id', 'root_id', 'evalue', 'score', 'bias'], 'INSERT IGNORE');

    }
    else {
        foreach my $seq_id ( keys %$all_hmm_annots ) {
            $adaptor->store_hmmclassify_result( $seq_id, @{ $all_hmm_annots->{$seq_id} } );
        }
    }
}

##########################################
#
# internal methods
#
##########################################

sub _get_queries {
    my $self = shift @_;

    my $start_member_id = $self->param_required('start_member_id');
    my $end_member_id   = $self->param_required('end_member_id');

    #Get list of members and sequences
    my $member_ids;
    if ( $self->param('fetch_all_seqs') == 1 ) {
        my $source_clusterset_id = $self->param_required('source_clusterset_id');
        $member_ids = $self->compara_dba->get_HMMAnnotAdaptor->fetch_all_seqs_in_trees_by_range( $start_member_id, $end_member_id, $source_clusterset_id );
    }
    else {
        $member_ids = $self->compara_dba->get_HMMAnnotAdaptor->fetch_all_seqs_missing_annot_by_range( $start_member_id, $end_member_id );
    }

    return $self->compara_dba->get_SeqMemberAdaptor->fetch_all_by_dbID_list($member_ids);
}

sub _dump_sequences_to_workdir {
    my ($self) = @_;

    my $fastafile = $self->worker_temp_directory . "/unannotated.fasta";    ## Include pipeline name to avoid clashing??
    print STDERR "Dumping unannotated members in $fastafile\n" if ( $self->debug );

    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences( $self->compara_dba->get_SequenceAdaptor, undef, $self->param('query_set') );
    $self->param('query_set')->print_sequences_to_file($fastafile);
    $self->param( 'fastafile', $fastafile );

}

sub _run_HMM_search {
    my ($self) = @_;

    my $fastafile    = $self->param('fastafile');
    my $hmmLibrary   = $self->param('library_basedir') . "/" . $self->param('library_name');
    my $hmmer_home   = $self->param('hmmer_home');
    my $hmmer_cutoff = $self->param('hmmer_cutoff');

    my $worker_temp_directory = $self->worker_temp_directory;
    my $cmd;
    if ( $self->param('hmmer_cutoff') ) {
        $cmd = $hmmer_home . "/hmmsearch --cpu 1 -E $hmmer_cutoff --noali --tblout $fastafile.out " . $hmmLibrary . " " . $fastafile;
    }
    else {
        $cmd = $hmmer_home . "/hmmsearch --cpu 1 --noali --tblout $fastafile.out " . $hmmLibrary . " " . $fastafile;
    }

    my $cmd_out = $self->run_command($cmd);

    # Detection of failures
    if ( $cmd_out->exit_code ) {
        $self->throw( sprintf( "error running hmmsearch [%s]: %d\n%s", $cmd_out->cmd, $cmd_out->exit_code, $cmd_out->err ) );
    }
    if ( $cmd_out->err =~ /^Missing sequence for (.*)$/ ) {
        $self->throw( sprintf( "pantherScore detected a missing sequence for the member %s. Full log is:\n%s", $1, $cmd_out->err ) );
    }

    #Parsing outputs
    open( HMM, "$fastafile.out" );

    if ( $self->param('store_all_hits') ) {

        #store all the hmm annotations
        my %hmm_annot;

        #map of the stable_ids with their corresponding stable_ids
        my %stable_root_id_map;

        #list of stable_ids
        my %stable_id_list;

        #Map of the stable_ids and root_id
        while (<HMM>) {

            #get rid of the header lines
            next if $_ =~ /^#/;

            #Only split the initial 6 wanted positions, $accession1-2 are not used.
            my ( $seq_id, $accession1, $hmm_id, $accession2, $eval, $score, $bias ) = split /\s+/, $_, 8;

            $hmm_annot{$seq_id}{$hmm_id}{'eval'}  = $eval;
            $hmm_annot{$seq_id}{$hmm_id}{'score'} = $score;
            $hmm_annot{$seq_id}{$hmm_id}{'bias'}  = $bias;
            $stable_id_list{$hmm_id} = 1;
        }

        my @stable_id_array = keys(%stable_id_list);

        $self->map_stableIds_to_rootIds(\@stable_id_array, \%stable_root_id_map);

        #Create the final hash
        foreach my $seq_id ( keys %hmm_annot ) {
            foreach my $hmm_id ( keys %{ $hmm_annot{$seq_id} } ) {
                $self->param('all_hmm_annots')->{$seq_id}->{ $stable_root_id_map{$hmm_id} }->{'eval'}  = $hmm_annot{$seq_id}{$hmm_id}{'eval'};
                $self->param('all_hmm_annots')->{$seq_id}->{ $stable_root_id_map{$hmm_id} }->{'score'} = $hmm_annot{$seq_id}{$hmm_id}{'score'};
                $self->param('all_hmm_annots')->{$seq_id}->{ $stable_root_id_map{$hmm_id} }->{'bias'}  = $hmm_annot{$seq_id}{$hmm_id}{'bias'};
            }
        }

    } ## end if ( $self->param('store_all_hits'...))
    else {
        my %hmm_annot;

        while (<HMM>) {

            #get rid of the header lines
            next if $_ =~ /^#/;

            #Only split the initial 6 wanted positions, $accession1-2 are not used.
            my ( $seq_id, $accession1, $hmm_id, $accession2, $eval ) = split /\s+/, $_, 6;

            #if hash exists we need to compare the already existing value, so that we only store the best e-value
            if ( exists( $hmm_annot{$seq_id} ) ) {
                if ( $eval < $hmm_annot{$seq_id}{'eval'} ) {
                    $hmm_annot{$seq_id}{'eval'}   = $eval;
                    $hmm_annot{$seq_id}{'hmm_id'} = $hmm_id;
                }
            }
            else {
                #storing evalues for the firt time
                $hmm_annot{$seq_id}{'eval'}   = $eval;
                $hmm_annot{$seq_id}{'hmm_id'} = $hmm_id;
            }

        }

        foreach my $seq_id ( keys %hmm_annot ) {
            $self->param('all_hmm_annots')->{$seq_id} = [ $hmm_annot{$seq_id}{'hmm_id'}, $hmm_annot{$seq_id}{'eval'} ];
        }
    } ## end else [ if ( $self->param('store_all_hits'...))]

} ## end sub _run_HMM_search

#Used to fetch the root_ids for the list of stable_ids.
# Its is useful to avoid having huge 'SELECT .. WHERE .. IN' statements.
# It receives an array with the stable_ids and a reference to a hash to map them with the root_ids.
sub map_stableIds_to_rootIds {
    my ( $self, $model_ids_ref, $model_id_hash_ref ) = @_;

    my $select_sql = "SELECT root_id, stable_id FROM gene_tree_root WHERE ";

    my $gene_tree_adaptor = $self->compara_dba->get_GeneTreeAdaptor();
    $gene_tree_adaptor->split_and_callback( $model_ids_ref, 'stable_id', SQL_VARCHAR, sub {
            my $sql = $select_sql . (shift);
            my $sth = $self->compara_dba->dbc->prepare($sql);
            $sth->execute();
            my ( $root_id, $stable_id );
            $sth->bind_columns( \$root_id, \$stable_id );
            while ( $sth->fetch ) {
                $model_id_hash_ref->{$stable_id} = $root_id;
            }
            $sth->finish;
    } );
}

1;
