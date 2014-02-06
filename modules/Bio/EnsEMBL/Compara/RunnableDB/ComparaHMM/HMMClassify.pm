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
package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassify;

use strict;
use warnings;
use Time::HiRes qw/time gettimeofday tv_interval/;
use Data::Dumper;
use DBI;
use Bio::EnsEMBL::Compara::MemberSet;
use Bio::EnsEMBL::Registry;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
            'hmmer_cutoff'        => 0.001,
           };
}

my $genome_db_id;
my $non_annot_member;
my $cluster_dir_count;

sub fetch_input {
    my ($self) = @_;

    $genome_db_id      = $self->param('genomeDB_id');
    $non_annot_member  = $self->param('non_annot_member');
    $cluster_dir_count = $self->param('cluster_dir_count');

    $self->throw('genomeDB_id is an obligatory parameter') unless (defined $self->param('genomeDB_id'));
    $self->throw('non_annot_member is an obligatory parameter') unless (defined $self->param('non_annot_member'));
    $self->throw('cluster_dir_count is an obligatory parameter') unless (defined $self->param('cluster_dir_count'));
    
    my $pantherScore_path = $self->param('pantherScore_path');
    $self->throw('pantherScore_path is an obligatory parameter') unless (defined $pantherScore_path);
    
    push @INC, "$pantherScore_path/lib";
    require FamLibBuilder;
#   import FamLibBuilder;

    $self->throw('hmm_library_basedir is an obligatory parameter') unless (defined $self->param('hmm_library_basedir'));
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

return;
}

sub write_output {
    my ($self) = @_;

    my $store_unclassify = $self->param('store_unclassify');
    $self->throw('store_unclassify is an obligatory parameter') unless (defined $self->param('store_unclassify'));
    $self->store_unclassify_member if($store_unclassify==1); 

return;
}
###################
# internal methods
###################
sub dump_sequences_to_workdir {
    my ($self) = @_;

    my $blast_tmp_dir     = $self->param('blast_tmp_dir');
    $self->throw('blast_tmp_dir is an obligatory parameter') unless (defined $self->param('blast_tmp_dir'));

    print STDERR "Dumping member $non_annot_member from $genome_db_id\n" if ($self->debug);

    my $fasta_filename = $genome_db_id.'_'.$non_annot_member; 
    my $fastafile      = $blast_tmp_dir."/${fasta_filename}.fasta"; ## Include pipeline name to avoid clashing??

    print STDERR "fastafile: $fastafile\n" if ($self->debug);

    open my $fastafh, ">", $fastafile or $self->throw("I can't open sequence file $fastafile for writing\n");

    my $count          = 0;
    my $undefMembers   = 0;
    my $memberAdaptor  = $self->compara_dba->get_MemberAdaptor;
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
  
    $self->throw('cluster_dir is an obligatory parameter') unless (defined $self->param('cluster_dir'));
    $cluster_dir          = $cluster_dir.$cluster_dir_count;
   
    $self->check_directory($cluster_dir); 

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
    my $hmmres = "$cluster_dir/${fasta_filename}.hmmres";
    $self->param('hmmres',$hmmres);
 
    unlink $fastafile;
return;
}

sub store_unclassify_member {
   my ($self) = @_;

   my $hmmres = $self->param('hmmres');
   my $sql    = "INSERT INTO sequence_unclassify(member_id,genome_db_id,cluster_dir_id)VALUES(?,?,?)";
   my $sth    = $self->compara_dba->dbc->prepare($sql);

   if(-z $hmmres){
         $sth->execute($non_annot_member,$genome_db_id,$cluster_dir_count);
   };
  
return;
}

=head2 check_directory

  Arg[1]     : -none-
  Example    : $self->check_directory;
  Function   : Check if the directory exists, if not create it
  Returns    : None
  Exceptions : dies if fail when creating directory 

=cut
sub check_directory {
    my ($self,$dir) = @_;

    unless (-e $dir) {
        print STDERR "$dir doesn't exists. I will try to create it\n" if ($self->debug());
        print STDERR "mkdir $dir (0755)\n" if ($self->debug());
        die "Impossible create directory $dir\n" unless (mkdir $dir, 0755 );
    }

return;
}

1;
