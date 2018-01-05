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

use strict;
use warnings;

package Bio::EnsEMBL::Compara::Utils::HomologyHash;

use namespace::autoclean;

use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);

use Bio::EnsEMBL::Compara::Utils::Preloader;


## This is like a constructor
sub convert {
    my ($caller, $homologies, @args) = @_;

    my $self = bless {}, $caller;

    my ($format_preset, $no_seq, $seq_type, $aligned, $cigar_line) =
        rearrange([qw(FORMAT_PRESET NO_SEQ SEQ_TYPE ALIGNED CIGAR_LINE)], @args);

    $self->format_preset($format_preset);
    $self->no_seq($no_seq);
    $self->seq_type($seq_type);
    $self->aligned($aligned);
    $self->cigar_line($cigar_line);

    return [] unless scalar(@$homologies);

    my $compara_dba = $homologies->[0]->adaptor->db;    # Should check whether adaptor is defined ?
    my $sms = Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies($compara_dba->get_AlignedMemberAdaptor, $homologies);
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers($compara_dba->get_GeneMemberAdaptor, $sms);
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_SpeciesTreeNodes($compara_dba->get_SpeciesTreeNodeAdaptor, $homologies);
    if ($self->format_preset and ($self->format_preset eq 'full') and !$no_seq) {
        Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($compara_dba->get_SequenceAdaptor, $seq_type, $homologies);
    }

    return [map {$self->_homology_node($_)} @$homologies];
}


## Getters / Setters
#####################

sub format_preset {
    my ($self, $format_preset) = @_;
    if (defined ($format_preset)) {
        $self->{_format_preset} = $format_preset;
    }
    return $self->{_format_preset};
}

sub aligned {
    my ($self, $aligned) = @_;
    if (defined ($aligned)) {
        $self->{_aligned} = $aligned;
    }
    return $self->{_aligned};
}

sub no_seq {
    my ($self, $no_seq) = @_;
    if (defined ($no_seq)) {
        $self->{_no_seq} = $no_seq;
    }
    return $self->{_no_seq};
}

sub seq_type {
    my ($self, $seq_type) = @_;
    if (defined ($seq_type)) {
        $self->{_seq_type} = $seq_type;
    }
    return $self->{_seq_type};
}


sub cigar_line {
    my ($self, $cigar_line) = @_;
    if (defined ($cigar_line)) {
        $self->{_cigar_line} = $cigar_line;
    }
    return $self->{_cigar_line};
}


## Actual convertors
#####################

sub _member_full_node {
    my ($self, $member) = @_;

    my $gene = $member->gene_member();
    my $genome_db = $gene->genome_db();
    my $taxon_id = $genome_db->taxon_id();

    # Note: The "*1" is a trick to fix ENSCORESW-273
    # > We have fixed bad content serialisation when going through the JSON
    # > serialiser (did not cause an issue in Perl but other type safe
    # > languages had a benny).
    my $result = {
        id          => $gene->stable_id(),
        species     => $genome_db->name(),
        perc_id     => ($member->perc_id()*1),
        perc_pos    => ($member->perc_pos()*1),
        protein_id  => $member->stable_id(),
    };

    # Fields that may be missing
    $result->{cigar_line} = $member->cigar_line() if $self->cigar_line;
    $result->{taxon_id}   = ($taxon_id+0) if defined $taxon_id;

    if ($self->aligned && $member->cigar_line()) {
        $result->{align_seq} = $member->alignment_string($self->seq_type);
    } elsif (!$self->no_seq) {
        $result->{seq} = $member->other_sequence($self->seq_type);
    }

    return $result;
}


sub _homology_node {
    my ($self, $homology) = @_;

    assert_ref($homology, 'Bio::EnsEMBL::Compara::Homology', 'homology');

    my ($src, $trg) = @{ $homology->get_all_Members() };

    if ($self->format_preset eq 'full') {

        return {
            type                => $homology->description(),
            taxonomy_level      => $homology->taxonomy_level(),
            method_link_type    => $homology->method_link_species_set()->method()->type(),
            dn_ds               => $homology->dnds_ratio() ? $homology->dnds_ratio()*1 : undef,
            source              => $self->_member_full_node($src),
            target              => $self->_member_full_node($trg),
        };

    } elsif ($self->format_preset eq 'condensed') {

        my $gene_member = $trg->gene_member();

        return {
            type                => $homology->description(),
            taxonomy_level      => $homology->taxonomy_level(),
            method_link_type    => $homology->method_link_species_set()->method()->type(),
            id                  => $gene_member->stable_id(),
            protein_id          => $trg->stable_id(),
            species             => $gene_member->genome_db()->name(),
        };

    } else {

        die "Don't know what the preset '".$self->format_preset."' means\n";
    }
}


1;
