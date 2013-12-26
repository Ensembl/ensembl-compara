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

Bio::EnsEMBL::Hive::RunnableDB::ComparaHMM::HMMClassify
#Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClassify

=head1 DESCRIPTION


=head1 SYNOPSIS


=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author: mm14 $

=head VERSION

$Revision: 1.8 $

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Hive::RunnableDB::ComparaHMM::HMMClassify;
#package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClassify;

use strict;
use warnings;

use Time::HiRes qw/time gettimeofday tv_interval/;
use Data::Dumper;

# To be deprecated:
use DBI;
use Bio::EnsEMBL::Compara::MemberSet;

use Bio::EnsEMBL::Registry;
#use Bio::EnsEMBL::DBSQL::DBAdaptor;
#use EGHmm::Utils::GeneGrammar;


use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
            'hmmer_cutoff'        => 0.001,
           };
}

my $non_annot_member;
my $genome_db_id;
my $blast_tmp_dir;
my $cluster_dir_count;

sub fetch_input {
    my ($self) = @_;

    my $pantherScore_path = $self->param('pantherScore_path');
    $self->throw('pantherScore_path is an obligatory parameter') unless (defined $pantherScore_path);

    push @INC, "$pantherScore_path/lib";
    require FamLibBuilder;
#   import FamLibBuilder;

    $genome_db_id      = $self->param('genomeDB_id');#pass from HMMClassifyInterpro
    $non_annot_member  = $self->param('non_annot_member');#pass from HMMClassifyInterpro
    $cluster_dir_count = $self->param('cluster_dir_count');#pass from HMMClassifyInterpro
 
    $self->throw('cluster_dir is an obligatory parameter') unless (defined $self->param('cluster_dir'));
    $self->throw('blast_path is an obligatory parameter') unless (defined $self->param('blast_bin_dir'));
    $self->throw('hmm_library_basedir is an obligatory parameter') unless (defined $self->param('hmm_library_basedir'));
   
    $blast_tmp_dir   = $self->param('blast_tmp_dir');


    unless (-e $blast_tmp_dir) { ## Make sure the directory exists
            print STDERR "$blast_tmp_dir doesn't exists. I will try to create it\n" if ($self->debug());
            print STDERR "mkdir $blast_tmp_dir (0755)\n" if ($self->debug());
            die "Impossible create directory $blast_tmp_dir\n" unless (mkdir $blast_tmp_dir, 0755);
    }
    
    my $hmmLibrary   = FamLibBuilder->new($self->param('hmm_library_basedir'), 'prod');
    $hmmLibrary->create();
	
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
}

##########################################
# internal methods
##########################################
sub dump_sequences_to_workdir {
    my ($self) = @_;

    print STDERR "Dumping members from $genome_db_id\n" if ($self->debug);

    my $fasta_filename = $genome_db_id.'_'.$non_annot_member; 
    my $fastafile      = $blast_tmp_dir."/${fasta_filename}.fasta"; ## Include pipeline name to avoid clashing??
    #my $fastafile      = $self->worker_temp_directory . "${fasta_filename}.fasta"; ## Include pipeline name to avoid clashing??
    print STDERR "fastafile: $fastafile\n" if ($self->debug);

    open my $fastafh, ">", $fastafile or $self->throw("I can't open sequence file $fastafile for writing\n");

    my $count          = 0;
    my $memberAdaptor  = $self->compara_dba->get_MemberAdaptor;
    my $undefMembers   = 0;
    my $member         = $memberAdaptor->fetch_by_dbID($non_annot_member);
        
    if (!defined $member) {
    	print STDERR "Member $non_annot_member is not found in the db\n";
        $undefMembers++;
    }
    $count++;
    my $seq 	       = $member->sequence;
       $seq            =~ s/(.{72})/$1\n/g;
    chomp $seq;
    print $fastafh ">" . $member->member_id . "\n$seq\n";
    close ($fastafh);

    $self->param('fastafile', $fastafile);

return;
}

sub run_HMM_search {
    my ($self) = @_;

    my $fastafile         = $self->param('fastafile');
    my $pantherScore_path = $self->param('pantherScore_path');
    my $pantherScore_exe  = "$pantherScore_path/pantherScore.pl";
    my $hmmLibrary        = $self->param('hmmLibrary');
    my $blast_path        = $self->param('blast_bin_dir');
    my $hmmer_path        = $self->param('hmmer_path');
    my $hmmer_cutoff      = $self->param('hmmer_cutoff'); ## Not used for now!!
    my $library_path      = $hmmLibrary->libDir();
    my $fasta_filename    = $genome_db_id.'_'.$non_annot_member; 
    my $cluster_dir       = $self->param('cluster_dir');
    $cluster_dir          = $cluster_dir.$cluster_dir_count;
=pod
    # Ensuring there is no more than 1000 files in a folder
    chdir $cluster_dir;
    #my $files_count  = `find ./ -type f -name '*.hmmres' | wc -l`;
    my $files_count  = `ls -R | grep .hmmres | wc -l`;

    if ($files_count < 1000){
       $cluster_dir      = $cluster_dir.'/cluster_0';
    }
    else {
       my $remainder = $files_count % 1000;
       my $quotient  = ($files_count - $remainder)/1000;
       $cluster_dir  = $cluster_dir.'/cluster_'.$quotient;
    }
=cut

    unless (-e $cluster_dir) { ## Make sure the directory exists
        print STDERR "$cluster_dir doesn't exists. I will try to create it\n" if ($self->debug());
        print STDERR "mkdir $cluster_dir (0755)\n" if ($self->debug());
        die "Impossible create directory $cluster_dir\n" unless (mkdir($cluster_dir, 0755));
    }

    print STDERR "Results are going to be stored in $cluster_dir/${fasta_filename}.hmmres\n" if ($self->debug());
    open my $hmm_res, ">", "$cluster_dir/${fasta_filename}.hmmres" or die $!;

    my $cmd = "PATH=\$PATH:$blast_path:$hmmer_path; PERL5LIB=\$PERL5LIB:$pantherScore_path/lib; $pantherScore_exe -l $library_path -i $fastafile -D I -b $blast_path 2>/dev/null";
    print STDERR "$cmd\n" if ($self->debug());

    $self->compara_dba->dbc->disconnect_when_inactive(1);
    open my $pipe, "-|", $cmd or die $!;

    while (<$pipe>) {
        chomp;
        
	my ($seq_id, $hmm_id, $eval) = split /\s+/, $_, 4;
        print STDERR "Writting [$seq_id, $hmm_id, $eval] to file $cluster_dir/${fasta_filename}.hmmres\n" if ($self->debug());
        print $hmm_res join "\t", ($seq_id, $hmm_id, $eval);
        print $hmm_res "\n";
    }

    close($hmm_res);
    close($pipe);

    $self->compara_dba->dbc->disconnect_if_idle() if $self->compara_dba->dbc->connected();   
    #$self->compara_dba->dbc->reconnect_when_lost(1);
    #$self->compara_dba->dbc->disconnect_when_inactive(0);

unlink $fastafile;
return;
}

1;
