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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft

=head1 DESCRIPTION

This RunnableDB implements Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSA
by calling Mafft. It only needs the 'mafft_home' pararameters

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSA');

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'mafft_exe'         => '/bin/mafft',            # where to find the mafft executable from $mafft_home
        'check_seq'         => 1,
    };
}



#
# Abstract methods from the base class (MSA) 
##############################################

sub get_msa_command_line {
    my $self = shift;

    my $mafft_home = $self->param_required('mafft_home');
    my $mafft_exe = $self->param_required('mafft_exe');
    die "Cannot execute '$mafft_exe' in '$mafft_home'" unless(-x $mafft_home.'/'.$mafft_exe);

    return sprintf('%s/%s --anysymbol --thread 1 --auto %s > %s', $mafft_home, $mafft_exe, $self->param('input_fasta'), $self->param('msa_output'));
}

1;
