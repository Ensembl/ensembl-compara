#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::PantherLoadModels


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


package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::PantherLoadModels;

use strict;
use IO::File; # ??
use File::Basename;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadModels');

sub param_defaults {
    return {
            'type' => 'panther',
            'url' => 'ftp://ftp.pantherdb.org/panther_library/current_release',
            'remote_file' => 'PANTHER7.2_ascii.tgz',
            'expanded_basename' => 'PANTHER7.2',
            'expander' => 'tar -xzf ',
           }
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

    $self->download_models;
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


sub get_profiles {
    my ($self) = @_;

    my $cm_directory = $self->param('cm_file_or_directory');
    $cm_directory .= "/books";

    while (my $famPath = <$cm_directory/*>) {
        my $fam = basename($famPath);
        print STDERR "Storing family $famPath($fam) => $famPath/hmmer.hmm" if ($self->debug());
        $self->store_hmmprofile("$famPath/hmmer.hmm", $fam);
        while (my $subfamPath = <$famPath/*>) {
            my $subfamBasename = basename($subfamPath);
            next if ($subfamBasename eq 'hmmer.hmm');
            my $subfam = $subfamBasename =~ /hmmer\.hmm/ ? $fam : "$fam." . $subfamBasename;
            print STDERR "Storing $subfam HMM\n";
            $self->store_hmmprofile("$subfamPath/hmmer.hmm", $subfam);
        }
    }
}

1;
