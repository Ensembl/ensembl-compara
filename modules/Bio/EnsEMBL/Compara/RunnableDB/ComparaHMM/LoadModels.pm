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

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadModels

=head1 DESCRIPTION

This Analysis/RunnableDB provides methods to load HMMs into the
database. It can also download fresh data from suppliers' websites


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.



=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _


=cut


package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadModels;

use strict;
use warnings;

use File::Path qw/remove_tree/;
use Time::HiRes qw(time gettimeofday tv_interval);
use LWP::Simple;

use Bio::EnsEMBL::Compara::HMMProfile;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


# Default values for the parameters used in this Runnable
# Make sure the sub-classes import this with $self->SUPER::param_defaults() !
sub param_defaults {
    return {
        'cm_file_or_directory'  => undef,
        'temp_dir'              => undef,
    }
}



=head2 download_models

    Parameters:
        url : where to download the data from
        remote_file : file than can be found at "url"
        expander : program to expand / uncompress the data
        expanded_basename : name (once uncompressed)
        temp_dir (optionnal, defaults to the worker's temp directory) : where to download the data

    Description:
        Method to download some HMM models from a remote URL.
        It then sets the following parameters:
            cm_file_or_directory
            temp_compressed_file

=cut

sub download_models {
    my ($self) = @_;

    my $starttime = time();

    my $ftp_file = $self->param('url') . '/' . $self->param('remote_file');
    my $worker_temp_directory = defined $self->param('temp_dir') ? $self->param('temp_dir') : $self->worker_temp_directory;
    unless (-e $worker_temp_directory) { ## Make sure the directory exists
        print STDERR "$worker_temp_directory doesn't exists. I will try to create it\n" if ($self->debug());
        print STDERR "mkdir $worker_temp_directory (0755)\n" if ($self->debug());
        die "Impossible create directory $worker_temp_directory\n" unless (mkdir($worker_temp_directory, 0755));
    }
    my $expanded_file = $worker_temp_directory . "/" . $self->param('expanded_basename');

    unlink ($expanded_file); # retry safe ## Works on directories?
    my $tmp_file = $worker_temp_directory . "/" . $self->param('remote_file');
    print STDERR "wget $ftp_file > $tmp_file\n" if ($self->debug());
    my $status = getstore($ftp_file, $tmp_file);
    die "Error $status trying to retrieve $ftp_file" unless (is_success($status));

    my $cmd = $self->param('expander') . " $tmp_file";
    $self->run_command("cd $worker_temp_directory; $cmd", { die_on_failure => 1, description => 'expand models' } );

    printf ("time for fetching and expanding models : %1.3f secs\n", time()-$starttime);

    $self->param('cm_file_or_directory', $expanded_file);
    $self->param('temp_compressed_file', $tmp_file);
}


=head2 store_hmmprofile

    Parameters:
        cm_file_or_directory : HMM file
        type : value of the "type" field in the hmm_profile table
        skip_consensus : [Optional] -- If we should skip building the consensus sequence of the HMM

    Description:
        Reads an HMM file and loads all the HMMs it contains

=cut

sub store_hmmprofile {
    my ($self, $multicm_file, $hmm_model_id, $hmm_name, $consensus) = @_;

    $multicm_file ||= $self->param('cm_file_or_directory');
    print STDERR "Opening file $multicm_file\n" if ($self->debug());
    open MULTICM, $multicm_file or die "$!\n";
    my ($name, $model_id) = ($hmm_name, $hmm_model_id);
    my $profile_content;

    print STDERR "SKIP_CONSENSUS:", $self->param('skip_consensus'), "\n";
    if ((!$consensus) && (!$self->param('skip_consensus'))) {
        $consensus = $self->get_consensus_from_HMMs($multicm_file);
    }

    while(my $line = <MULTICM>) {
        $profile_content .= $line;
        if ($line =~ /NAME/) {
            my ($tag, $this_name) = split(/\s+/,$line);
            $name = defined $hmm_name ? $hmm_name : $this_name;
        } elsif ($line =~ /^ACC/) {
            my ($tag, $accession) = split(/\s+/,$line);
            $model_id = defined $hmm_model_id ? $hmm_model_id : $accession;
        } elsif ($line =~ /^\/\//) {
            # End of profile, let's store it
            $self->throw("Error loading profile [$hmm_name, $name, $model_id]\n") unless (defined($model_id) && defined ($profile_content));

            # We create a new HMMProfile object and store it
            my $hmm_profile = Bio::EnsEMBL::Compara::HMMProfile->new();
            $hmm_profile->model_id($model_id);
            $hmm_profile->name($name);
            $hmm_profile->type($self->param('type'));
            $hmm_profile->profile($profile_content);
            $hmm_profile->consensus($consensus->{$name});

            warn "Storing a new model: $model_id / $name".($hmm_profile->consensus ? " with a consensus sequence\n" : "\n");
            $self->compara_dba->get_HMMProfileAdaptor()->store($hmm_profile);

            $model_id = undef;
            $profile_content = undef;
        }

    }
}

=head2 store_infernalhmmprofile

    Parameters:
        cm_file_or_directory : HMM file
        type : value of the "type" field in the hmm_profile table
        skip_consensus : [Optional] -- If we should skip building the consensus sequence of the HMM

    Description:
        Reads an  HMM file and loads all the infernal HMMs it contains

=cut

sub store_infernalhmmprofile {
    my ($self, $multicm_file, $hmm_model_id, $hmm_name, $consensus) = @_;

    $multicm_file ||= $self->param('cm_file_or_directory');
    print STDERR "Opening file $multicm_file\n" if ($self->debug());
    open MULTICM, $multicm_file or die "$!\n";
    my ($name, $model_id) = ($hmm_name, $hmm_model_id);
    my $profile_content;

    print STDERR "SKIP_CONSENSUS:", $self->param('skip_consensus'), "\n";
    if ((!$consensus) && (!$self->param('skip_consensus'))) {
        $consensus = $self->get_consensus_from_HMMs($multicm_file);
    }

    while(my $line = <MULTICM>) {
        if (   (($line =~ /INFERNAL/) && defined($model_id)) || (eof)) {
                # End of profile, let's store it

            $self->throw("Error loading profile [$hmm_name, $name, $model_id]\n") unless (defined($model_id) && defined ($profile_content));

                # We create a new HMMProfile object and store it
            my $hmm_profile = Bio::EnsEMBL::Compara::HMMProfile->new();
            $hmm_profile->model_id($model_id);
            $hmm_profile->name($name);
            $hmm_profile->type($self->param('type'));
            $hmm_profile->profile($profile_content);
            $hmm_profile->consensus($consensus->{$name});

            warn "Storing a new model: $model_id / $name".($hmm_profile->consensus ? " with a consensus sequence\n" : "\n");
            $self->compara_dba->get_HMMProfileAdaptor()->store($hmm_profile);

            $model_id = undef;
            $profile_content = undef;
#            unless (eof) {
#                $profile_content .= $line;
#            }
        } elsif ($line =~ /NAME/) {
            my ($tag, $this_name) = split(/\s+/,$line);
            $name = defined $hmm_name ? $hmm_name : $this_name;
        } elsif ($line =~ /^ACC/) {
            
            my ($tag, $accession) = split(/\s+/,$line);
            $model_id = defined $hmm_model_id ? $hmm_model_id : $accession;
        } 
        $profile_content .= $line;
    }
}
=head2 get_consensus_from_HMMs

    Parameters:
        hmmemit_exe : path to hmmemit

    Description:
        Runs hmmemit on a HMM and returns its consensus sequences

=cut

sub get_consensus_from_HMMs {
    my ($self, $hmm_file) = @_;

    my $hmmemit_exe = $self->param_required('hmmemit_exe');

    warn "Getting a consensus sequence with: $hmmemit_exe -c $hmm_file\n";
    open my $pipe, "-|", "$hmmemit_exe -c $hmm_file" or die $!;

    my %consensus;
    my $header;
    my $count = 0;
    my $seq;
    while (<$pipe>) {
        chomp;
        if (/^>/) {
            $consensus{$header} = $seq if (defined $header);
            ($header) = $_ =~ /^>(\w+)/;
            $count++;
            $seq = "";
            next;
        }
        $seq .= $_ if (defined $header);
    }
    $consensus{$header} = $seq;
    close($pipe);
    return \%consensus;
}


=head2 clean_directory

    Parameters:
        temp_compressed_file : downloaded compressed dile
        cm_file_or_directory : uncompressed file

    Description:
        Removes the files that have been downloaded

=cut

sub clean_directory {
    my ($self) = @_;

    return unless $self->param('temp_compressed_file');
    unlink ($self->param('temp_compressed_file')); ## In case it has not been already deleted by the expander

    my $tmp_file = $self->param('cm_file_or_directory');
    if (-d $tmp_file) {
        my $res;
        remove_tree($tmp_file, \$res);
#        print STDERR "Files removed: ". scalar @$res . "\n" if ($self->debug());
        print STDERR Dumper $res if ($self->debug());
    } elsif (-f $tmp_file) {
        unlink($tmp_file);
    }
}

1;

