=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClassify

=head1 DESCRIPTION


=head1 SYNOPSIS


=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClassify;

use strict;
use warnings;

use Time::HiRes qw/time gettimeofday tv_interval/;
use Data::Dumper;

# To be deprecated:
use DBI;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
            'sort_clusters'       => 1,
            'immediate_dataflow'  => 1,
            'member_type'         => 'protein',
            'input_id_prefix'     => 'protein',
#            'pantherScore_path'   => '/software/ensembl/compara/pantherScore1.03',
#            'library_path'        => '/lustre/scratch110/ensembl/mp12/pfam_hmms/',
#            'blast_path'          => '/software/ensembl/compara/ncbi-blast-2.2.26+/bin/',
            'hmmer_cutoff'        => 0.001,
#            'hmmer_path'          => '/software/ensembl/compara/hmmer-2.3.2/src/',
           };
}

sub fetch_input {
    my ($self) = @_;

    my $pantherScore_path = $self->param('pantherScore_path');
    $self->throw('pantherScore_path is an obligatory parameter') unless (defined $pantherScore_path);

    push @INC, "$pantherScore_path/lib";
    require FamLibBuilder;
#    import FamLibBuilder;

    my $genome_db_id = $self->param('genome_db_id');
    if (! defined $genome_db_id) {
        $self->throw('genome_db_id is an obligatory parameter');
    }
    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
    $self->param('genome_db', $genome_db);

    $self->throw('cluster_dir is an obligatory parameter') unless (defined $self->param('cluster_dir'));
    $self->throw('blast_path is an obligatory parameter') unless (defined $self->param('blast_path'));
    $self->throw('hmm_library_basedir is an obligatory parameter') unless (defined $self->param('hmm_library_basedir'));
    my $hmmLibrary = FamLibBuilder->new($self->param('hmm_library_basedir'), 'prod');
    $self->throw('No valid HMM library found at ' . $self->param('library_path')) unless ($hmmLibrary->exists());
    $self->param('hmmLibrary', $hmmLibrary);

    return;
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
#    $self->store_and_dataflow_clusterset('default', $self->param('allclusters'));
}


##########################################
#
# internal methods
#
##########################################


sub dump_sequences_to_workdir {
    my ($self) = @_;

    my $genome_db = $self->param('genome_db');
    my $genome_db_id = $self->param('genome_db_id');

    print STDERR "Dumping members from $genome_db_id\n" if ($self->debug);

    my $fastafile = $self->worker_temp_directory . "${genome_db_id}.fasta"; ## Include pipeline name to avoid clashing??
    print STDERR "fastafile: $fastafile\n" if ($self->debug);
    open my $fastafh, ">", $fastafile or $self->throw("I can't open sequence file $fastafile for writing\n");

    my $count = 0;
    my $memberAdaptor = $self->compara_dba->get_MemberAdaptor;
    my $undefMembers = 0;

    my $subset = $self->compara_dba->get_SubsetAdaptor->fetch_by_description_pattern("gdb:$genome_db_id % translations");

    for my $member_id (@{$subset->member_id_list}) {
        my $member = $memberAdaptor->fetch_by_dbID($member_id);
        if (!defined $member) {
            print STDERR "Member $member_id is not found in the db\n";
            $undefMembers++;
        }
        $count++;
        my $seq = $member->sequence;
        $seq =~ s/(.{72})/$1\n/g;
        chomp $seq;
        print $fastafh ">" . $member->member_id . "\n$seq\n";
    }

    close ($fastafh);
    $self->param('fastafile', $fastafile);

    return;
}

sub run_HMM_search {
    my ($self) = @_;

    my $fastafile = $self->param('fastafile');
    my $pantherScore_path = $self->param('pantherScore_path');
    my $pantherScore_exe = "$pantherScore_path/pantherScore.pl";
    my $hmmLibrary = $self->param('hmmLibrary');
    my $blast_path = $self->param('blast_path');
    my $hmmer_path = $self->param('hmmer_path');
    my $hmmer_cutoff = $self->param('hmmer_cutoff'); ## Not used for now!!
    my $library_path = $hmmLibrary->libDir();

    my $genome_db_id = $self->param('genome_db_id');
    my $cluster_dir  = $self->param('cluster_dir');

    print STDERR "Results are going to be stored in $cluster_dir/${genome_db_id}.hmmres\n" if ($self->debug());
    open my $hmm_res, ">", "$cluster_dir/${genome_db_id}.hmmres" or die $!;


    my $cmd = "PATH=\$PATH:$blast_path:$hmmer_path; PERL5LIB=\$PERL5LIB:$pantherScore_path/lib; $pantherScore_exe -l $library_path -i $fastafile -D I -b $blast_path 2>/dev/null";
    print STDERR "$cmd\n" if ($self->debug());

    open my $pipe, "-|", $cmd or die $!;
    while (<$pipe>) {
        chomp;
        my ($seq_id, $hmm_id, $eval) = split /\s+/, $_, 4;
        next if ($hmm_id =~ /:SF\d+/); ## Needed?
        print STDERR "Writting [$seq_id, $hmm_id, $eval] to file $cluster_dir/${genome_db_id}.hmmres\n" if ($self->debug());
        print $hmm_res join "\t", ($seq_id, $hmm_id, $eval);
        print $hmm_res "\n";
    }
    close($hmm_res);
    close($pipe);

    return;
}

1;
