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

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::MultiHMMLoadModels


=head1 SYNOPSIS

To load RFAM models from the FTP, use these parameters:
 url: ftp://ftp.sanger.ac.uk/pub/databases/Rfam/11.0/
 remote_file: Rfam.cm.gz
 expander: gunzip
 expanded_basename: Rfam.cm
To load the models from a file, do something like:
 cm_file_or_directory: /lustre/scratch110/ensembl/mp12/pfamA_HMM_fs.txt
or
 cm_file_or_directory: /lustre/scratch109/sanger/fs9/treefam8_hmms


=head1 DESCRIPTION

This Analysis/RunnableDB is designed to download a file that contains all
the HMM models, and load them into the database to be used in the
alignment process.
It can also directly process the file if "cm_file_or_directory" is defined.


=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _


=cut


package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::MultiHMMLoadModels;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadModels');

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

    $self->store_hmmprofile();
    $self->clean_directory();
}



1;
