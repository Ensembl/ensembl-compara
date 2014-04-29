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

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassify

=head1 DESCRIPTION


=head1 SYNOPSIS


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

use base ('Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassify', 'Bio::EnsEMBL::Compara::RunnableDB::RunCommand');

sub param_defaults {
    return {
            'hmmer_cutoff'        => 0.001,
           };
}

sub fetch_input {
    my ($self) = @_;

    $self->SUPER::fetch_input();

    my $pantherScore_path = $self->param_required('pantherScore_path');

    push @INC, "$pantherScore_path/lib";
    require FamLibBuilder;
#   import FamLibBuilder;

    $self->param_required('blast_bin_dir');
    $self->param_required('hmm_library_basedir');
    my $hmmLibrary = FamLibBuilder->new($self->param('hmm_library_basedir'), 'prod');
    $hmmLibrary->create();

    $self->throw('No valid HMM library found at ' . $self->param('library_path')) unless ($hmmLibrary->exists());
    $self->param('hmmLibrary', $hmmLibrary);

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


##########################################
#
# internal methods
#
##########################################


sub dump_sequences_to_workdir {
    my ($self) = @_;

    my $genome_db_id = $self->param('genome_db_id');
    my $fastafile = $self->worker_temp_directory . "${genome_db_id}.fasta"; ## Include pipeline name to avoid clashing??
    print STDERR "Dumping unannotated members from $genome_db_id in $fastafile\n" if ($self->debug);

    Bio::EnsEMBL::Compara::MemberSet->new(-members => $self->param('unannotated_members'))->print_sequences_to_file($fastafile);
    $self->param('fastafile', $fastafile);

}

sub run_HMM_search {
    my ($self) = @_;

    my $fastafile         = $self->param('fastafile');
    my $pantherScore_path = $self->param('pantherScore_path');
    my $pantherScore_exe  = "$pantherScore_path/pantherScore.pl";
    my $hmmLibrary        = $self->param('hmmLibrary');
    my $blast_bin_dir     = $self->param('blast_bin_dir');
    my $hmmer_path        = $self->param('hmmer_path');
    my $hmmer_cutoff      = $self->param('hmmer_cutoff'); ## Not used for now!!
    my $library_path      = $hmmLibrary->libDir();

    my $worker_temp_directory = $self->worker_temp_directory;
    my $cmd = "PATH=\$PATH:$blast_bin_dir:$hmmer_path; PERL5LIB=\$PERL5LIB:$pantherScore_path/lib; $pantherScore_exe -l $library_path -i $fastafile -D I -b $blast_bin_dir -T $worker_temp_directory -V";
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

    unless ($has_hits) {
        $self->throw("pantherScore did not return any hits. Is it normal ?");
    }
}

1;
