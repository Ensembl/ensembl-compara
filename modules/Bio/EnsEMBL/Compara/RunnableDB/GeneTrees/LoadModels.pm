#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadModels


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


package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadModels;

use strict;
use IO::File; ## ??
use File::Path qw/remove_tree/;
use Time::HiRes qw(time gettimeofday tv_interval);
use LWP::Simple;

use Bio::EnsEMBL::Compara::HMMProfile;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

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
    my $expanded_file = $worker_temp_directory . $self->param('expanded_basename');

    unlink ($expanded_file); # retry safe ## Works on directories?
    my $tmp_file = $worker_temp_directory . $self->param('remote_file');
    print STDERR "wget $ftp_file > $tmp_file\n" if ($self->debug());
    my $status = getstore($ftp_file, $tmp_file);
    die "Error $status trying to retrieve $ftp_file" unless (is_success($status));

    my $cmd = $self->param('expander') . " $tmp_file";
    print STDERR "$cmd\n" if ($self->debug());

    unless (system("cd $worker_temp_directory; $cmd") == 0) {
        print STDERR "$cmd\n";
        $self->throw("error expanding models with [$cmd]: $!\n");
    }
    printf ("time for fetching and expanding models : %1.3f secs\n", time()-$starttime);

    $self->param('cm_file_or_directory', $expanded_file);
    $self->param('temp_compressed_file', $tmp_file);
    return;
}

sub store_hmmprofile {
    my ($self, $multicm_file, $hmm_name, $consensus) = @_;

    $multicm_file ||= $self->param('cm_file_or_directory');
    print STDERR "Opening file $multicm_file\n" if ($self->debug());
    open MULTICM, $multicm_file or die "$!\n";
    my ($name, $model_id) = ($hmm_name)x2;
    my $profile_content;
    while(my $line = <MULTICM>) {
        $profile_content .= $line;
        if ($line =~ /NAME/) {
            my ($tag, $this_name) = split(/\s+/,$line);
            $name = defined $hmm_name ? $hmm_name : $this_name;
        } elsif ($line =~ /^ACC/) {
            my ($tag, $accession) = split(/\s+/,$line);
            $model_id = defined $hmm_name ? $hmm_name : $accession;
        } elsif ($line =~ /^\/\//) {
            # End of profile, let's store it
            $self->throw("Error loading profile [$hmm_name, $name, $model_id]\n") unless (defined($model_id) && defined ($profile_content));

            # We create a new HMMProfile object and store it
            my $hmm_profile = Bio::EnsEMBL::Compara::HMMProfile->new();
            $hmm_profile->model_id($model_id);
            $hmm_profile->name($name);
            $hmm_profile->type($self->param('type'));
            $hmm_profile->profile($profile_content);
            $hmm_profile->consensus($consensus);

            $self->compara_dba->get_HMMProfileAdaptor()->store($hmm_profile);

            $model_id = undef;
            $profile_content = undef;
        }

    }
}

sub clean_directory {
    my ($self) = @_;
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

