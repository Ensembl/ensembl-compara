
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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadPanther

=head1 SYNOPSIS

This runnable is used to:
    1 - donwload panther libraries
    2 - create directory
    3 - untar
    4 - concatenate all the profiles into one single file
    5 - run hmmpress
    6 - parse and store outputs

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to download and prepare the PANTHER libraries to be used in the HMM search environment.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadPanther;

use strict;
use warnings;

use File::Find;
use LWP::Simple;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');
use base ('Bio::EnsEMBL::Hive::Process');
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
             'library_name'        => '#hmm_library_name#',
             'hmmpress_exe'        => '#hmmer_home#/hmmpress',
             'panther_hmm_lib'     => '#panther_hmm_library_basedir#',
             'url'                 => '#panther_url#',
             'file'                => '#panther_file#',
         };
}

sub fetch_input {
    my $self = shift @_;

    $self->require_executable('hmmpress_exe');
    $self->param_required('library_name');
    $self->param_required('url');
    $self->param_required('file');
    $self->param_required('hmmer_home');
    $self->param_required('panther_hmm_lib');

    #Avoid running, used for test purposes:
    $self->dataflow_output_id(undef, 1);
    $self->input_job->autoflow(0);
    $self->complete_early("PANTHER is already downloaded.");

}

sub run {
    my $self = shift @_;

    #download families
    $self->_download_panter_families;

    #concatenate the families into one file
    $self->_concatenate_profiles;

    #run hmmpress
    $self->_hmm_press_profiles;

    #cleanup after hmmpress
    $self->_clear_tmp_panther_directory_structure;
}

#No write_output needed here.
#sub write_output {
#    my $self = shift @_;
#}

##########################################
#
# internal methods
#
##########################################

# Used to download and decompress the profiles from the PANTHER ftp site. Make sure the URL is up-to-date.
sub _download_panter_families {
    my $self = shift;

    my $starttime = time();
    print STDERR "fetching PANTHER families ...\n" if ( $self->debug );

    my $worker_temp_directory = $self->worker_temp_directory;

    my $ftp_file = $self->param('url') . $self->param('file');
    my $tmp_file = $self->param('panther_hmm_lib') . "/" . $self->param('file');

    my $panther_dir = $tmp_file;
    $panther_dir =~ s/_ascii\.tgz//;
    $self->param( 'panther_dir', $panther_dir );

    #cleanup before downlading
    my $rm_cmd = [qw(rm), $self->param('panther_hmm_lib')."*.h*"];
    $self->run_command($rm_cmd, { die_on_failure => 0, description => 'delete previous PANTHER library files' } );

    #get fresh file from FTP
    my $status = getstore( $ftp_file, $tmp_file );
    die "_download_panter_families error $status on $ftp_file" unless is_success($status);

    #Avoid downloading, usefull for debugging.
    #system("cp /nfs/production/panda/ensembl/compara/mateus/compara/PANTHER11.1_ascii.tgz $tmp_file");

    #untar file
    my $cmd = "tar -xzvf " . $tmp_file;
    $self->run_command("cd " . $self->param('panther_hmm_lib') . "; $cmd", { die_on_failure => 1, description => 'expand PANTHER families' } );

    printf( "time for fetching and decompressing PANTHER families: %1.3f secs\n", time() - $starttime );
} ## end sub _download_panter_families

# Used to concatenate all the profiles into one single file. It improves efficiency drastically.
sub _concatenate_profiles {
    my $self = shift;

    print STDERR "concatenating the HMM profiles ...\n" if ( $self->debug );
    my @hmm_list;

    find( sub { push @hmm_list, $File::Find::name if -f && /\.hmm$/ }, $self->param('panther_dir') );

    $self->param( 'local_hmm_library', $self->param('panther_dir') . "/" . $self->param('library_name') );
    print ">>concatenating:" . $self->param('local_hmm_library') . "|\n" if ($self->debug);

    open my $library_fh , ">" . $self->param('local_hmm_library') || die "Could not open local_hmm_library file.";
    foreach my $hmm (@hmm_list) {
        open my $hmm_fh, $hmm || die "Could not open $hmm file.";
        my @lines = <$hmm_fh>;
        print $library_fh @lines;
        close($hmm_fh);
    }
    close($library_fh);
}

#Run hmmpress to create binary indices to enhance the searches.
sub _hmm_press_profiles {

    my $self = shift;

    print STDERR "running hmmpress on concatenated profiles ...\n" if ( $self->debug );

    my $cmd = join( ' ', $self->param('hmmpress_exe'), $self->param('local_hmm_library') );

    my $cmd_out = $self->run_command( $cmd, { die_on_failure => 1 } );
    unless ( ( -e $self->param('local_hmm_library') ) and ( -s $self->param('local_hmm_library') ) ) {

        # Add some waiting time to allow the filesystem to distribute the file accross
        sleep 10;
    }
    my $runtime_msec = $cmd_out->runtime_msec;

    #move HMM library into place
    $cmd = "become -- compara_ensembl mv " . $self->param('local_hmm_library') . "* " . $self->param('panther_hmm_lib') . "/";
    $self->run_command($cmd, { die_on_failure => 1, description => 'move the HMM library to "hmm_library_basedir"' } );
}

#After parsing we should clean up the files, since they are quite big.
sub _clear_tmp_panther_directory_structure {
    my $self = shift;

    #remove previous directory structure (books, globals, etc)
    my $cmd = [qw(rm -rf), $self->param('panther_dir')];
    $self->run_command($cmd, { die_on_failure => 0, description => 'delete previous PANTHER directory structure' } );

    #remove previously downloaded file from PANTHER FTP
    $cmd = [qw(rm -rf), $self->param('panther_hmm_lib')."/".$self->param('file')];
    $self->run_command($cmd, { die_on_failure => 0, description => 'delete previous downloaded .tgz file' } );
}

1;
