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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::DumpModels

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to fetch the HMM models from
the Panther ftp site and load them into the database to be used in the
alignment process.



=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.



=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _


=cut


package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::DumpModels;

use strict;
use warnings;
use IO::File; ## ??
use File::Path qw/remove_tree make_path/;
use Time::HiRes qw(time gettimeofday tv_interval);
use LWP::Simple;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my ($self) = @_;

    $self->param_required('blast_bin_dir');
    my $pantherScore_path = $self->param_required('pantherScore_path');

    push @INC, "$pantherScore_path/lib";
    require FamLibBuilder;
    #import FamLibBuilder;


    my $basedir = $self->param_required('hmm_library_basedir');
    my $hmmLibrary = FamLibBuilder->new($basedir, "prod");

    my $code = $hmmLibrary->create();
    if (!defined $code) {
        $self->throw("Error creating the library!\n");
    }
    if ($code == -1) {
        $self->complete_early("The library already exists. I will reuse it (but have you set the stripe on it?)\n");
    } elsif ($code == 1) {
        print STDERR "OK creating the library\n" if ($self->debug());

      if (`which lfs`) {
        my $book_stripe_cmd = "lfs setstripe " . $hmmLibrary->bookDir() . " -c -1";
        my $global_stripe_cmd = "lfs setstripe " . $hmmLibrary->globalsDir() . " -c -1";

        for my $dir ($hmmLibrary->bookDir(), $hmmLibrary->globalsDir()) {
            my $stripe_cmd = "lfs setstripe $dir -c -1";
            print STDERR "$stripe_cmd\n" if ($self->debug());
            if (system $stripe_cmd) {
                $self->throw("Impossible to set stripe on $dir");
            }
        }
      }
      $self->param('hmmLibrary', $hmmLibrary);
    }
}

sub run {
    my ($self) = @_;
    return unless $self->param('hmmLibrary');  # if the library already exists
    $self->dump_models();
    $self->create_blast_db();
}


################################
## Internal methods ############
################################

sub dump_models {
    my ($self) = @_;

    my $hmmLibrary = $self->param('hmmLibrary');
    my $bookDir = $hmmLibrary->bookDir();

    my $sql = "SELECT model_id FROM hmm_profile"; ## mysql runs out of memory if we include here all the profiles
    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();
    while (my ($model_id) = $sth->fetchrow) {
        print STDERR "Dumping model_id $model_id into $bookDir/$model_id\n";
        my $path = "$bookDir/$model_id";
        $path =~ s/:/\//;
        make_path($path);
        my $hmm_object = $self->compara_dba->get_HMMProfileAdaptor->fetch_all_by_model_id_type($model_id, $self->param('type'))->[0];
        $self->_spurt("$path/hmmer.hmm", $hmm_object->profile);
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
        chomp ($seq);
        print $consFh ">$id\n$seq\n";
    }
    $sth->finish();
    close($consFh);

    ## Create the blast db
    my $blast_bin_dir = $self->param('blast_bin_dir');
    my $formatdb_exe = "$blast_bin_dir/makeblastdb";
    my $cmd = [$formatdb_exe, qw(-dbtype prot -in), $globalsDir.'/con.Fasta'];
    $self->run_command($cmd, { die_on_failure => 1, description => 'create the blastdb' } );
}

1;

