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

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassifyPantherScore;

use strict;
use warnings;

use Time::HiRes qw/time gettimeofday tv_interval/;
use Data::Dumper;

use Bio::EnsEMBL::Compara::MemberSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
            'hmmer_cutoff'        => 0.001,
           };
}

sub fetch_input {
    my ($self) = @_;

    my $pantherScore_path = $self->param_required('pantherScore_path');

    push @INC, "$pantherScore_path/libexec";
    require FamLibBuilder;
#   import FamLibBuilder;

    $self->param_required('blast_bin_dir');
    $self->param_required('hmm_library_basedir');
    my $hmmLibrary = FamLibBuilder->new($self->param('hmm_library_basedir'), 'prod');
    $hmmLibrary->create();

    $self->throw('No valid HMM library found at ' . $self->param('library_path')) unless ($hmmLibrary->exists());
    $self->param('hmmLibrary', $hmmLibrary);

    my $members_to_query = $self->get_queries;
    unless (scalar(@$members_to_query)) {
        $self->complete_early('No members to query. They seem to all have an entry in hmm_annot !');
    }
    $self->param('query_set', Bio::EnsEMBL::Compara::MemberSet->new(-members => $members_to_query));
    $self->param('all_hmm_annots', {});
}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs hmmbuild
    Returns :   none
    Args    :   none

=cut

sub run {
    my ($self) = @_;

    $self->dump_sequences_to_workdir;
    $self->run_HMM_search;
}


sub write_output {
    my ($self) = @_;
    my $adaptor = $self->compara_dba->get_HMMAnnotAdaptor();
    my $all_hmm_annots = $self->param('all_hmm_annots');
        # Store into table 'hmm_annot'
    foreach my $seq_id (keys %$all_hmm_annots) {
        $adaptor->store_hmmclassify_result($seq_id, @{$all_hmm_annots->{$seq_id}});
    }
}


##########################################
#
# internal methods
#
##########################################

sub get_queries {
    my $self = shift @_;

    my $start_member_id = $self->param_required('start_member_id');
    my $end_member_id   = $self->param_required('end_member_id');

    #Get list of members and sequences
    my $member_ids = $self->compara_dba->get_HMMAnnotAdaptor->fetch_all_seqs_missing_annot_by_range($start_member_id, $end_member_id);
    return $self->compara_dba->get_SeqMemberAdaptor->fetch_all_by_dbID_list($member_ids);
}



sub dump_sequences_to_workdir {
    my ($self) = @_;

    my $fastafile = $self->worker_temp_directory . "/unannotated.fasta"; ## Include pipeline name to avoid clashing??
    print STDERR "Dumping unannotated members in $fastafile\n" if ($self->debug);

    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($self->compara_dba->get_SequenceAdaptor, undef, $self->param('query_set'));
    $self->param('query_set')->print_sequences_to_file($fastafile);
    $self->param('fastafile', $fastafile);

}

sub run_HMM_search {
    my ($self) = @_;

    my $fastafile         = $self->param('fastafile');
    my $pantherScore_path = $self->param('pantherScore_path');
    my $pantherScore_exe  = "$pantherScore_path/bin/pantherScore.pl";
    my $hmmLibrary        = $self->param('hmmLibrary');
    my $blast_bin_dir     = $self->param('blast_bin_dir');
    my $hmmer_path        = $self->param('hmmer_path');
    my $hmmer_cutoff      = $self->param('hmmer_cutoff'); ## Not used for now!!
    my $library_path      = $hmmLibrary->libDir();

    my $worker_temp_directory = $self->worker_temp_directory;
    my $cmd = "PATH=$blast_bin_dir:$hmmer_path:\$PATH; $pantherScore_exe -l $library_path -i $fastafile -D I -b $blast_bin_dir -T $worker_temp_directory -V";
    my $cmd_out = $self->run_command($cmd);

    # Detection of failures
    if ($cmd_out->exit_code) {
        $self->throw(sprintf("error running pantherScore [%s]: %d\n%s", $cmd_out->cmd, $cmd_out->exit_code, $cmd_out->err));
    }
    if ($cmd_out->err =~ /^Problem with blast on (.*)$/) {
        $self->throw(sprintf("pantherScore detected an error with blast on the member %s. Full log is:\n%s", $1, $cmd_out->err));
    }
    if ($cmd_out->err =~ /^Missing sequence for (.*)$/) {
        $self->throw(sprintf("pantherScore detected a missing sequence for the member %s. Full log is:\n%s", $1, $cmd_out->err));
    }

    my $has_hits = 0;
    for (split /^/, $cmd_out->out) {
        chomp;
        my ($seq_id, $hmm_id, $eval) = split /\s+/, $_, 4;
        # Hits to a sub-family are also reported to its family
        next if $hmm_id =~ /:/;
        $self->add_hmm_annot($seq_id, $hmm_id, $eval);
        $has_hits = 1;
    }
}

sub add_hmm_annot {
    my ($self, $seq_id, $hmm_id, $eval) = @_;
    print STDERR "Found [$seq_id, $hmm_id, $eval]\n" if ($self->debug());
    if (exists $self->param('all_hmm_annots')->{$seq_id}) {
        if ($self->param('all_hmm_annots')->{$seq_id}->[1] < $eval) {
            print STDERR "Not registering it because the evalue is higher than the currently stored one: ", $self->param('all_hmm_annots')->{$seq_id}->[1], "\n" if $self->debug();
        }
    }
    $self->param('all_hmm_annots')->{$seq_id} = [$hmm_id, $eval];
}


1;
