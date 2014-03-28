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

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadNewModels


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
package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::LoadNewModels;

use strict;
use IO::File; # ??
use File::Basename;
use Data::Dumper;
use vars qw/@INC/;
use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::LoadModels');

sub param_defaults {

    return {
            'type' => 'panther9.0_treefam',
            'url'  => 'ftp://ftp.pantherdb.org/panther_library/current_release',
            'remote_file' => 'PANTHER9.0_ascii.tgz',
            'expanded_basename' => 'PANTHER9.0',
            'expander' => 'tar -xzf ',
           }
}

sub fetch_input {
    my ($self) = @_;
    my $pantherScore_path = $self->param_required('pantherScore_path');
    my $type              = $self->param_required('type');
    my $hmmemit_exe       = $self->param_required('hmmemit_exe');
    my $cm_directory      = $self->param_required('cm_file_or_directory');

    push @INC, "$pantherScore_path/lib";
    require FastaFile;
    import FastaFile;
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
}

######################
# internal methods
#####################

sub get_profiles {
    my ($self) = @_;

    my $cm_directory = $self->param('cm_file_or_directory');
    print STDERR "CM_DIRECTORY = " . $cm_directory . "\n";

    while (my $famPath = <$cm_directory/*>) {
        my $fam       = basename($famPath);
        print STDERR "Storing family $famPath($fam) => $famPath/hmmer.hmm\n" if ($self->debug());

        my $hmmfile   = "$famPath/hmmer.hmm"; 
        next unless (-e $hmmfile);

        my $consensus = $self->compute_consensus_for_HMM($hmmfile);
        my $name;

        open my $fh, "<", $hmmfile or die $!;
          while (<$fh>) {
            if (/^NAME/) {
              $name   = (split /\s+/, $_)[1];
            }
          }
        close($fh);

        $self->store_hmmprofile("$famPath/hmmer.hmm", $fam, $consensus->{$name});
   }
}

sub compute_consensus_for_HMM {
    my ($self, $hmmfile) = @_;

    my $hmmemit_exe = $self->param('hmmemit_exe');

    open my $pipe, "-|", "$hmmemit_exe -c $hmmfile" or die $!;

    my %consensus;
    my $header;
    my $count = 0;
    my $seq;

    while (<$pipe>) {
        chomp;
        if (/^>/) {
            $consensus{$header} = $seq if (defined $header);
            ($header)           = $_ =~ /^>(.+?)\s/;
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
