#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::RFAMLoadModels

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $rfamloadmodels = Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::RFAMLoadModels->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$rfamloadmodels->fetch_input(); #reads from DB
$rfamloadmodels->run();
$rfamloadmodels->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis/RunnableDB is designed to fetch the Infernal models from
the RFAM ftp site and load them into the database to be used in the
alignment process.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::RFAMLoadModels;

use strict;
use IO::File;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);
use LWP::Simple;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadModels');

sub param_defaults {
    return {
            'type'  => 'infernal',
            'url' => 'ftp://ftp.sanger.ac.uk/pub/databases/Rfam/11.0/',
            'remote_file' => 'Rfam.cm.gz',
            'expanded_basename' => 'Rfam.cm',
            'expander' => 'gunzip ',
    };
}


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
    my $self = shift @_;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs hmmbuild
    Returns :   none
    Args    :   none

=cut


sub run {
    my $self = shift @_;

    $self->download_models();
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores the RFAM models
    Returns :   none
    Args    :   none

=cut


sub write_output {
    my ($self) = @_;

    $self->store_hmmprofile;
}

sub post_cleanup {
    my ($self) = @_;
    $self->clean_directory();
}

1;

