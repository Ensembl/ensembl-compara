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

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::PantherLoadModels


=head1 SYNOPSIS

To load RFAM models from the FTP, use these parameters:
 url: ftp://ftp.pantherdb.org/panther_library/current_release
 remote_file: PANTHER9.0_ascii.tgz
 expander: tar -xzf
 expanded_basename: PANTHER9.0
To load the models from a file, do something like:
 cm_file_or_directory: /lustre/scratch110/ensembl/mp12/panther_hmms/PANTHER7.2_ascii


=head1 DESCRIPTION

This Analysis/RunnableDB is designed to download an archive that contains all
the HMM models in a Panther-like format, and load them into the database to be used in the
alignment process.
It can also directly process the directory if "cm_file_or_directory" is defined.


=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _


=cut


package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::PantherLoadModels;

use strict;
use warnings;

use File::Basename;

use vars qw/@INC/;

use base ('Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadModels');


sub param_defaults {
    return {
        include_subfamilies => 0,
    }
}

=head2 fetch_input

    Title   :   run
    Usage   :   $self->fetch_input
    Function:   Checks that PantherScore is available
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
    my ($self) = @_;
    my $pantherScore_path = $self->param_required('pantherScore_path');
    my $type              = $self->param_required('type');

    push @INC, "$pantherScore_path/lib";
    require FastaFile;
    import FastaFile;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   Downloads and processes
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift @_;

    $self->download_models() unless (defined $self->param('cm_file_or_directory'));
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores the HMM models
    Returns :   none
    Args    :   none

=cut

sub write_output {
    my $self = shift @_;

    $self->get_profiles();
    $self->clean_directory();
}


##########################################
#
# internal methods
#
##########################################

sub initialize_fasta_index {
    my ($self) = @_;

    my $cm_directory = $self->param_required('cm_file_or_directory');
    my $consensus_fasta = $cm_directory . "/globals/con.Fasta";
    open my $consensus_fh, "<", $consensus_fasta or die "$!: $consensus_fasta";
    $self->param('consensus_fh', $consensus_fh);
    $self->param('index', FastaFile::indexFasta($consensus_fh));
}

sub get_consensus_from_index {
    my ($self, $fam_name) = @_;
    my $consensus_fh = $self->param('consensus_fh');
    my $index = $self->param('index');
    my $cons_seq = FastaFile::getSeq($consensus_fh, $index, $fam_name);
    die "No consensus sequence found for fam $fam_name" unless (defined $cons_seq);
    my (undef, $seq) = split /\n/, $cons_seq, 2;
    return $seq;
}

sub get_profiles {
    my ($self) = @_;

    my $cm_directory = $self->param_required('cm_file_or_directory');
    print STDERR "CM_DIRECTORY = " . $cm_directory . "\n";
    $self->initialize_fasta_index;
    while (my $famPath = glob("$cm_directory/books/*")) {
        my $fam = basename($famPath);
        my $cons_seq = $self->get_consensus_from_index($fam);
        print STDERR "Storing family $famPath($fam) => $famPath/hmmer.hmm\n" if ($self->debug());
        $self->store_hmmprofile("$famPath/hmmer.hmm", $fam, undef, {$fam => $cons_seq});

        next unless $self->param('include_subfamilies');

	## For subfamilies
        while (my $subfamPath = glob("$famPath/*")) {
            my $subfamBasename = basename($subfamPath);
            print $subfamPath, "\n";
            next unless -d $subfamPath;
            my $subfam = "$fam:" . $subfamBasename;
            $cons_seq = $self->get_consensus_from_index($subfam);
            print STDERR "Storing $subfam HMM\n";
            $self->store_hmmprofile("$subfamPath/hmmer.hmm", $subfam, undef, {$subfam => $cons_seq});
        }
    }
}



1;
