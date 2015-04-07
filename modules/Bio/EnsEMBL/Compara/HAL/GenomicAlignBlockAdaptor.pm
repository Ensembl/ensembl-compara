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

Bio::EnsEMBL::DBSQL::Compara::GenomicAlignBlockAdaptor

=cut

package Bio::EnsEMBL::Compara::HAL::GenomicAlignBlockAdaptor;

use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::DnaFrag;

sub new {
    my $class = shift;
    my $hal_fd = shift;
    my $adaptor = shift;
    my $self = {};
    bless $self, $class;
    $self->{'hal_fd'} = $hal_fd;
    $self->{'hal_adaptor'} = $adaptor;
    return $self;
}

sub store {
    die 'store unimplemented';
}

sub delete_by_dbID {
    die 'delete_by_dbID unimplemented';
}

sub fetch_by_dbID {
    die 'fetch_by_dbID unimplemented';
}

sub fetch_all_dbIDs_by_MethodLinkSpeciesSet_Dnafrag {
    die 'fetch_all_dbIDs_by_MethodLinkSpeciesSet_Dnafrag unimplemented';
}

sub fetch_all_by_MethodLinkSpeciesSet {
    die 'need ref for now until MultiBlockMapper.cpp works again.'
}

sub fetch_all_by_MethodLinkSpeciesSet_Slice {
    my ($self, $mlss, $ref_slice, $limit_number, $limit_index_start, $restrict, $pairwiseOnly) = @_;
    $pairwiseOnly = 0 unless defined($pairwiseOnly);
    # Get the hal genome name corresponding to the reference slice.
    my $ref_core_dba = $ref_slice->adaptor->db();
    my $ref_species_name = $ref_core_dba->get_MetaContainer->get_production_name();
    my $ref_assembly = $ref_core_dba->assembly_name();
    my $ref_name = $self->{'hal_adaptor'}->genome_name_from_species_and_assembly($ref_species_name, $ref_assembly);
    my @targets = grep {$_ ne $ref_name } $self->{'hal_adaptor'}->ensembl_genomes();
    my $hal_seq_name = $self->{'hal_adaptor'}->hal_sequence_name($ref_name, $ref_slice->seq_region_name());
    return $self->_getGenomicAlignBlocks(
        $ref_name,
#        $mlss->species_set_obj()->get_all_values_for_tag("hal_genome_name"),
        \@targets,
        $hal_seq_name, $ref_slice->start(),
        $ref_slice->end(),
        pairwiseOnly);
}

sub fetch_all_by_MethodLinkSpeciesSet_DnaFrag {
}

sub _getGenomicAlignBlocks {
    my ($self, $ref, $targets, $seq, $start, $end) = @_;
    my @gabs = ();
    foreach my $target (@$targets) {
        print "hal_fd is ".$self->{'hal_fd'};
        print "target is $target\n";
        print "ref is $ref\n";
        print "seq is $seq\n";
        print "start is $start\n";
        print "end is $end\n";
        my @blocks = Bio::EnsEMBL::Compara::HAL::HALAdaptor::_get_pairwise_blocks($self->{'hal_fd'}, $target, $ref, $seq, $start, $end);
        foreach my $entry (@blocks) {
            if (defined $entry) {
                my $gab = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                    -length => @$entry[3]);
                # normalize seq by removing "chr" prefix.
                # FIXME: remove
                my $seq_name = @$entry[0] =~ s/^chr//;
                my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                    -genomic_align_block => $gab,
                    -aligned-sequence => @$entry[5],
                    -dnafrag => Bio::EnsEMBL::Compara::DnaFrag->new(
                         -name => $seq_name,
                         -genome_db => $self->{'hal_adaptor'}->_get_GenomeDB($target),
                         -coord_system_name => "chromosome"),
                    -dnafrag_start => @$entry[2],
                    -dnafrag_end => @$entry[2] + @$entry[3],
                    -dnafrag_strand => @$entry[4] eq '+' ? 1 : -1
                    );
                my $ref_seq_name = $seq;
                $ref_seq_name =~ s/^chr//;
                my $ref_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
                    -genomic_align_block => $gab,
                    -aligned-sequence => @$entry[6],
                    -dnafrag => Bio::EnsEMBL::Compara::DnaFrag->new(
                         -name => $ref_seq_name,
                         -genome_db => $self->{'hal_adaptor'}->_get_GenomeDB($ref),
                         -coord_system_name => "chromosome"),
                    -dnafrag_start => @$entry[1],
                    -dnafrag_end => @$entry[1] + @$entry[3],
                    -dnafrag_strand => 1);
                    
                $gab->genomic_align_array([$ref_genomic_align, $genomic_align]);
                $gab->reference_genomic_align($ref_genomic_align);
                push(@gabs, $gab);
            }
        }
    }
    return @gabs;
}

sub _check_gabs {
    my ($self, $gabs) = @_;
    
}

1;
