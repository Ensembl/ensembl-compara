
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

use Time::HiRes qw/time gettimeofday tv_interval/;
use Data::Dumper;

use Bio::EnsEMBL::Compara::MemberSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return { 'hmmer_cutoff' => 0.001, 'library_name' => '#hmm_library_name#', };
}

sub fetch_input {
    my ($self) = @_;

    $self->param_required('library_name');
    $self->param_required('hmm_library_basedir');
    $self->param_required('hmmer_home');

    #need to add some quality check on the HMM profile, e.g. expecting X number of prifiles to be in the concatenated file, etc.

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

    # Store into table 'hmm_annot'
    foreach my $seq_id ( keys %$all_hmm_annots ) {
        $adaptor->store_hmmclassify_result( $seq_id, @{ $all_hmm_annots->{$seq_id} } );
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
    my $member_ids =
      $self->compara_dba->get_HMMAnnotAdaptor->fetch_all_seqs_missing_annot_by_range( $start_member_id, $end_member_id );
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
    my $hmmLibrary   = $self->param('hmm_library_basedir') . "/" . $self->param('library_name');
    my $hmmer_home   = $self->param('hmmer_home');
    my $hmmer_cutoff = $self->param('hmmer_cutoff');                                               ## Not used for now!!

    my $worker_temp_directory = $self->worker_temp_directory;
    my $cmd                   = $hmmer_home . "/hmmsearch --noali --tblout $fastafile.out " . $hmmLibrary . " " . $fastafile;

    my $cmd_out = $self->run_command($cmd);

    my %hmm_annot;

    # Detection of failures
    if ( $cmd_out->exit_code ) {
        $self->throw( sprintf( "error running pantherScore [%s]: %d\n%s", $cmd_out->cmd, $cmd_out->exit_code, $cmd_out->err ) );
    }
    if ( $cmd_out->err =~ /^Missing sequence for (.*)$/ ) {
        $self->throw( sprintf( "pantherScore detected a missing sequence for the member %s. Full log is:\n%s", $1, $cmd_out->err ) );
    }

    #Parsing outputs
    open( HMM, "$fastafile.out" );
    while (<HMM>) {

        #get rid of the header lines
        next if $_ =~ /^#/;

        #Only split the initial 6 wanted positions, $accession1-2 are not used.
        my ( $seq_id, $accession1, $hmm_id, $accession2, $eval ) = split /\s+/, $_, 6;

        #print "\n>>>>$seq_id|$hmm_id|$eval\n" if ( $self->debug );
        $hmm_id = ( split /\./, $hmm_id )[0];

        #Only store if e-values are bellow the threshold
        if ( $eval < $hmmer_cutoff ) {

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
    } ## end while (<HMM>)

    foreach my $seq_id ( keys %hmm_annot ) {
        $self->_add_hmm_annot( $seq_id, $hmm_annot{$seq_id}{'hmm_id'}, $hmm_annot{$seq_id}{'eval'} );
    }

} ## end sub _run_HMM_search

sub _add_hmm_annot {
    my ( $self, $seq_id, $hmm_id, $eval ) = @_;
    print STDERR "Found [$seq_id, $hmm_id, $eval]\n" if ( $self->debug() );
    $self->param('all_hmm_annots')->{$seq_id} = [ $hmm_id, $eval ];
}

1;
