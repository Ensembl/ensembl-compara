# Intended to mimic the registry or compara_db objects for providing compara adaptors.
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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME
=cut

package Bio::EnsEMBL::Compara::HAL::HALAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::HAL::GenomicAlignBlockAdaptor;
use Bio::EnsEMBL::Compara::HAL::MethodLinkSpeciesSetAdaptor;

use Inline C => Config =>
             LIBS => "-L$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/hdf5/lib -L$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/hal/lib -lhalChain -lhalLod -lhalLiftover -lhalLib -L$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/sonLib/lib -lsonLib  -lstdc++ -lhdf5 -lhdf5_cpp",
             MYEXTLIB => ["$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/hal/lib/halChain.a", "$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/hal/lib/halLod.a", "$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/hal/lib/halLiftover.a", "$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/hal/lib/halLib.a", "$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/sonLib/lib/sonLib.a"],
             INC => "-I$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/hal/chain/inc/";
use Inline 'C' => "./HALAdaptorSupport.c";
             #LIBS => "-L$ENV{'PROGRESSIVE_CACTUS_DIR'}/submodules/hdf5/lib -lstdc++ -lhdf5 -lhdf5_cpp",

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
    $self->{'path'} = $path;
    $self->{'hal_fd'} = _open_hal($self->path);
    if (defined $use_hal_genomes && $use_hal_genomes) {
        $self->{'use_hal_genomes'} = 1;
    } else {
        $self->{'use_hal_genomes'} = 0;
    }
    return $self;
}

sub path {
    my $self = shift;
    return $self->{'path'};
}

# FIXME: this is really bad and not at *all* what goes on in other
# get_adaptor methods. But I'm planning on rewriting all of this
# (there isn't much to it!) after getting the hang of perl anyway.
sub get_adaptor {
    my $self = shift;
    my $class_name = shift;
    if ($class_name eq 'GenomicAlignBlock') {
        return Bio::EnsEMBL::Compara::HAL::GenomicAlignBlockAdaptor->new($self->{'hal_fd'}, $self);
    } elsif ($class_name eq 'MethodLinkSpeciesSet') {
        return Bio::EnsEMBL::Compara::HAL::MethodLinkSpeciesSetAdaptor->new($self);
    } else {
        die "can't get adaptor for class $class_name";
    }
}

sub genome_name_from_species_and_assembly {
    my ($self, $species_name, $assembly_name) = @_;
    foreach my $genome (_get_genome_names($self->{'hal_fd'})) {
        my $genome_metadata = _get_genome_metadata($self->{'hal_fd'}, $genome);
        if ((exists $genome_metadata->{'ensembl_species'} && $genome_metadata->{'ensembl_species'} eq $species_name) &&
            (exists $genome_metadata->{'ensembl_assembly'} && $genome_metadata->{'ensembl_assembly'} eq $assembly_name)) {
            return $genome;
        }
    }
    die "Could not find genome with metadata indicating it corresponds to ensembl species='".$species_name."', ensembl_assembly='".$assembly_name."'"
}

sub genome_metadata {
    my ($self, $genome) = @_;
    return _get_genome_metadata($self->{'hal_fd'}, $genome);
}

sub ensembl_genomes {
    my $self = shift;
    my @ensembl_genomes = grep { exists($self->genome_metadata($_)->{'ensembl_species'}) && exists($self->genome_metadata($_)->{'ensembl_assembly'}) } $self->genomes();
    return @ensembl_genomes;
}

sub genomes {
    my $self = shift;
    return _get_genome_names($self->{'hal_fd'});
}

# FIXME: not really sure this quite belongs Convert an Ensembl
# sequence name to a hal sequence name (adding "chr" if the
# "ucscChrNames" metadata attribute is set to "true")
sub hal_sequence_name {
    my ($self, $genome_name, $seq_name) = @_;
    if ($self->genome_metadata($genome_name)->{'ucscChrNames'} eq "true") {
        # Try to see if there is a sequence named "chr___" first, if
        # not, try just "____" as usual
        my $chr_seq_name = "chr".$seq_name;
        if (grep($chr_seq_name, _get_seqs_in_genome($self->{'hal_fd'}, $genome_name))) {
            return $chr_seq_name;
        }
    }
    return $seq_name;
}

sub _get_GenomeDB {
    my ($self, $genome_name) = @_;
    if ($self->{'use_hal_genomes'}) {

    } else {
        my $species_name = $self->genome_metadata($genome_name)->{'ensembl_species'};
        if (!defined $species_name) {
            die("Could not find ensembl species name for genome with hal ".
                "genome $genome_name, and we are not using hal GenomeDBs.");
        }
        my $assembly_name = $self->genome_metadata($genome_name)->{'ensembl_assembly'};
        if (!defined $assembly_name) {
            warn("Could not find ensembl assembly name for genome with hal ".
                 "name $genome_name, and we are not using hal GenomeDBs.");
        }
        my $gdba = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "GenomeDB");
        return $gdba->fetch_by_name_assembly($species_name, $assembly_name);
    }
}

1;
