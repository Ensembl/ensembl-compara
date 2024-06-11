
=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::PrepareHmmProfiles

=head1 SYNOPSIS

This runnable is used to:
    1 - fetch profiles from the database
    2 - create directory
    3 - concatenate all the profiles into one single file
    5 - run hmmpress

=head1 DESCRIPTION

This Analysis/RunnableDB is designed fetch all the recently generated HMM3 profiles from the databases and create the new Compara HMM profiles.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::PrepareHmmProfiles;

use strict;
use warnings;

#use File::Find;
#use LWP::Simple;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
             'library_name'        => '#hmm_library_name#',
             'hmmpress_exe'        => '#hmmer_home#/hmmpress',
         };
}

sub fetch_input {
    my $self = shift @_;

    $self->require_executable('hmmpress_exe');
    $self->param_required('library_name');
    $self->param_required('hmmer_home');
    $self->param_required('worker_compara_hmm_lib');
    $self->param_required('target_compara_hmm_lib') if $self->param('store_in_warehouse');
}

sub run {
    my $self = shift @_;

    #fetch profiles from the database
    $self->_fetch_and_concatenate_hmm_profiles;

    #run hmmpress
    $self->_hmm_press_profiles;

    #copy hmm profile to shared compara dir
    $self->_copy_hmm_profiles;

    #generate README file
    $self->_create_readme;
}

##########################################
#
# internal methods
#
##########################################

# Used to download and decompress the profiles from the PANTHER ftp site. Make sure the URL is up-to-date.
sub _fetch_and_concatenate_hmm_profiles{
    my $self = shift;

    print STDERR "fetching hmm profiles ...\n" if ( $self->debug );

    #New compara HMM library
    my $hmm_file = $self->param('worker_compara_hmm_lib') . "/" . $self->param('library_name');
    open my $hmm_fh , '>', $hmm_file || die "Could not open local hmm_library file.";

    #Running sql query
    my $hmm_sql = "SELECT model_id, UNCOMPRESS(compressed_profile) AS profile_txt FROM hmm_profile";
    my $sth = $self->compara_dba->dbc->prepare($hmm_sql, { 'mysql_use_result' => 1 });
    $sth->execute();
    while( my ($model_id, $profile_txt) = $sth->fetchrow() ) {
        print $hmm_fh $profile_txt . "\n";
    }

    close($hmm_fh);  

} ## end sub _download_panter_families

#Run hmmpress to create binary indices to enhance the searches.
sub _hmm_press_profiles {

    my $self = shift;
    print STDERR "running hmmpress on concatenated profiles ...\n" if ( $self->debug );

    my $local_hmm_library =  $self->param('worker_compara_hmm_lib') . "/" . $self->param('library_name');
    my $cmd = "rm -f $local_hmm_library.* ; ";
    $cmd .= join( ' ', $self->param('hmmpress_exe'), $local_hmm_library );

    #print "\n\n>>>$cmd<<<\n";
    my $cmd_out = $self->run_command( $cmd, { die_on_failure => 1 } );
    unless ( ( -e $self->param('local_hmm_library') ) and ( -s $self->param('local_hmm_library') ) ) {

        # Add some waiting time to allow the filesystem to distribute the file accross
        sleep 10;
    }
}

# Copy the hmm profiles from the faster hps directory to the slower but backedup shared compara directory.
sub _copy_hmm_profiles{
    my $self = shift;
    my $hmm_file = $self->param('worker_compara_hmm_lib') . "/" . $self->param('library_name');
    my $cmd = "cp $hmm_file*";
    $cmd .= join( ' ', $self->param('target_compara_hmm_lib'));
    my $cmd_out = $self->run_command( $cmd, { die_on_failure => 1 } );
}

# Create README file with the list of the genomes considered (name, genebuild, assembly, locator)
sub _create_readme{
    my $self = shift;
    my $filename = $self->param_required('readme_file');
    open my $fh, '>', $filename || die ("Cannot open $filename");

    my $mlss    = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param('mlss_id')) or $self->die_no_retry("Could not fetch mlss with dbID=$self->param('mlss_id')");
    my $genome_dbs = $mlss->species_set->genome_dbs;

    print $fh "species_name\tgenome_db_id\tassembly_name\tlocator\n";
    foreach my $gdb (@{$genome_dbs}) {
        print $fh $gdb->name . "\t" . $gdb->dbID . "\t" . $gdb->assembly . "\t" . $gdb->locator . "\n";
    }
    close($fh);
}

1;
