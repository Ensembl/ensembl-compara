=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::PantherLoadModels


=head1 SYNOPSIS



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


package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MultiHMMLoadModels;

use strict;
use IO::File; # ??
use File::Basename;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadModels');

sub param_defaults {
    return {
            'type' => 'MultiHMM',
            'hmmemit_path' => "/software/ensembl/compara/hmmer-2.3.2/src/hmmemit",
            'expanded_basename' => 'PANTHER7.2',
            'expander' => 'tar -xzf ',
            'cm_file_or_directory' => '/lustre/scratch110/ensembl/mp12/pfamA_HMM_fs.txt',
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

    $self->download_models unless (defined $self->param('cm_file_or_directory'));
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
#    $self->clean_directory();
}

##########################################
#
# internal methods
#
##########################################


sub get_profiles {
    my ($self) = @_;

    my $hmmfile = $self->param('cm_file_or_directory');

    my $consensus = $self->get_consensus_from_HMMs();

    open my $fh, "<", $hmmfile or die $!;
    my $hmm;
    my $acc;
    my $name;
    while (<$fh>) {
        if (/^\/\//) {
            $hmm .= $_;
            $self->load_hmmprofile($hmm, $acc, $name, $consensus->{$name});
            $hmm = undef;
            next;
        }
        if (/^HMMER2\.0/) {
            $hmm = $_;
            next;
        }
        if (/^ACC/) {
            $acc = (split /\s+/, $_)[1];
        }
        if (/^NAME/) {
            $name = (split /\s+/, $_)[1];
        }
        $hmm .= $_ if (defined $hmm);
    }
    $self->load_hmmprofile($hmm, $acc, $name, $consensus->{$name});
    close($fh);
}

sub load_hmm_profile {
    my ($self, $hmm, $acc, $name, $consensus) = @_;
    my $hmm_profile = Bio::EnsEMBL::Compara::HMMProfile->new();
    $hmm_profile->model_id($acc);
    $hmm_profile->name($name);
    $hmm_profile->type($self->param('type')); ##
    $hmm_profile->profile($hmm);
    $hmm_profile->consensus($consensus);
    $self->compara_dba->get_HMMProfileAdaptor()->store($hmm_profile);
    return;
}

sub get_consensus_from_HMMs {
    my ($self) = @_;

    my $hmmemit_path = $self->param('hmmemit_path');
    my $hmmfile = $self->param('cm_file_or_directory');

    open my $pipe, "-|", "$hmmemit_path -c $hmmfile" or die $!;

    my %consensus;
    my $header;
    my $count = 0;
    my $seq;
    while (<$pipe>) {
        chomp;
        if (/^>/) {
            $consensus{$header} = $seq if (defined $header);
            ($header) = $_ =~ /^>(.+?)\s/;
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

1;
