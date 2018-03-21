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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

    Bio::EnsEMBL::Compara::HAL::HALXS::HALAdaptor

=cut

package Bio::EnsEMBL::Compara::HAL::HALXS::HALAdaptor;

use strict;
use warnings;
no warnings 'uninitialized';

BEGIN {
    use File::Spec;
    my ($volume, $directory, $file) = File::Spec->splitpath(__FILE__);
    unshift @INC, "$volume$directory/lib"; # path to HALXS.xs
    unshift @INC, "$volume$directory/blib/arch"; # path to built .so file
}

use ExtUtils::testlib;
use HALXS;

=head2 new

  Arg [1]    : list of args to super class constructor
  Example    : $ga_a = Bio::EnsEMBL::Compara::HAL::HALAdaptor->new("/tmp/test.hal");
  Description: Creates a new HALAdaptor from an lod.txt file or hal file.
  Returntype : none
  Exceptions : none

=cut

sub new {
    my($class, $path, $use_hal_genomes) = @_;
    my $self = {};
    bless $self, $class;
    unless (-r $path) {
        if (-e $path) {
            die "'$path' cannot be read";
        } else {
            die "'$path' doesn\'t exist";
        }
    }
    $self->{'hal_fd'} = HALXS::_open_hal($path);
    # if (defined $use_hal_genomes && $use_hal_genomes) {
    #     $self->{'use_hal_genomes'} = 1;
    # } else {
    #     $self->{'use_hal_genomes'} = 0;
    # }

    return $self;
}

# sub path {
#     my $self = shift;
#     return $self->{'path'};
# }

sub hal_filehandle {
    my $self = shift;
    return $self->{'hal_fd'};
}

sub genome_metadata {
    my ($self, $genome) = @_;
    return HALXS::_get_genome_metadata($self->{'hal_fd'}, $genome);
}

sub genomes {
    my $self = shift;
    return HALXS::_get_genome_names($self->{'hal_fd'});
}

sub seqs_in_genome {
    my ($self, $genome) = @_;
    return HALXS::_get_seqs_in_genome($self->{'hal_fd'}, $genome);
}

sub msa_blocks {
    my ( $self, $targets_str, $ref, $hal_seq_reg, $start, $end, $max_ref_gap ) = @_;
    $max_ref_gap ||= 0;
    die "Need some target species" unless $targets_str;
    return HALXS::_get_multiple_aln_blocks( $self->{'hal_fd'}, $targets_str, $ref, $hal_seq_reg, $start, $end, $max_ref_gap );
}

sub pairwise_blocks {
    my ( $self, $target, $ref, $hal_seq_reg, $start, $end, $target_seq_reg ) = @_;

    die "Need the name of the target species" unless $target;
    my @blocks;
    if ( $target_seq_reg ){
        @blocks = HALXS::_get_pairwise_blocks_filtered($self->{'hal_fd'}, $target, $ref, $hal_seq_reg, $start, $end, $target_seq_reg);
    }
    else {
        @blocks = HALXS::_get_pairwise_blocks($self->{'hal_fd'}, $target, $ref, $hal_seq_reg, $start, $end);
    }

    return \@blocks;
}

1;
