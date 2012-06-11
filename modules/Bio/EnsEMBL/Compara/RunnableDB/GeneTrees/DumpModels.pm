#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpModels


=head1 SYNOPSIS



=head1 DESCRIPTION

This Analysis/RunnableDB is designed to fetch the HMM models from
the Panther ftp site and load them into the database to be used in the
alignment process.



=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.



=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _


=cut


package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DumpModels;

use strict;
use IO::File; ## ??
use File::Path qw/remove_tree/;
use Time::HiRes qw(time gettimeofday tv_interval);
use LWP::Simple;
use Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Panther::FamLibBuilder;  ## Make sure we have this in PERL5LIB

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
           }
}

sub fetch_input {
    my ($self) = @_;

    die "blast_path has to be set\n" if (!defined $self->param('blast_path'));

    my $basedir = $self->param('hmm_library_basedir') or die "The base dir of the library is needed\n";
    my $hmmLibrary = FamLibBuilder->new($basedir, "prod");

    my $code = $hmmLibrary->assureExists();
    if (!defined $code) {
        die "Error creating the library!\n";
    }
    if ($code == -1) {
        $self->input_job->incomplete(0);
        die "The library already exists. I will reuse it"
    }
    if ($code == 1) {
        print STDERR "OK creating the library\n" if ($self->debug());
    }

    $self->param('hmmLibrary', $hmmLibrary);
    return;
}

sub run {
    my ($self) = @_;
    $self->dump_models();
    $self->create_blast_db();
}

sub write_output {
    my ($self) = @_;
}

################################
## Internal methods ############
################################

sub dump_models {
    my ($self) = @_;

    my $hmmLibrary = $self->param('hmmLibrary');
    my $bookDir = $hmmLibrary->bookDir();

    my $sql = "SELECT model_id, hc_profile FROM hmm_profile";
    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();
    while (my ($model_id, $profile) = $sth->fetchrow) {
        print STDERR "Dumping model_id $model_id\n";
        mkdir "$bookDir/$model_id" or die $!;
        open my $fh, ">", "$bookDir/$model_id/hmmer.hmm" or die $!;
        print $fh $profile;
        close($fh);
    }
}

sub create_blast_db {
    my ($self) = @_;

    my $hmmLibrary = $self->param('hmmLibrary');
    my $globalsDir = $hmmLibrary->globalsDir();

    ## Get all the consensus sequences
    open my $consFh, ">", "$globalsDir/con.Fasta" or die $!;
    my $sql = "SELECT model_id, consensus FROM hmm_profile";
    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();
    while (my ($id, $seq) = $sth->fetchrow) {
        print $consFh ">$id\n$seq\n";
    }
    $sth->finish();
    close($consFh);

    ## Create the blast db
    my $blast_path = $self->param('blast_path');
    my $formatdb_exe = "$blast_path/makeblastdb";
    my $cmd = "$formatdb_exe -dbtype prot -in $globalsDir/con.Fasta";
    if (my $err = system($cmd)) {
        die "Problem creating the blastdb: $err\n";
    }
    return;
}

1;

