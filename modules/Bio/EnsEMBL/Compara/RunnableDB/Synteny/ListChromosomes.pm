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

Bio::EnsEMBL::Compara::RunnableDB::Synteny::ListChromosomes

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

This module lists all the chromosomes (or similar sequence structures) that can be used to draw synteny maps.

Supported keys:
 - default_coord_system_names: The default list of coord_system_name to consider when generating the list of dnafrags
                               Make the list empty to test them all. Only the ones that have the has_karyotype() flag
                               switched on the core database will be used
 - include_non_karyotype: boolean (default 0). Set to 1 if you want to list dnafrags that are not on the karyotype

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Synteny::ListChromosomes;

use strict;
use warnings;
use Data::Dumper;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'default_coord_system_names'    => [ 'chromosome', 'group' ],       # The default list of coord_system_name to consider when generating the list of dnafrags
        'include_non_karyotype'  => 0,
    }
}



sub fetch_input {
    my ($self) = @_;

    if ($self->param("registry")) {
        $self->load_registry($self->param("registry"));
    }

    # Get the GenomeDB entry
    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_name_assembly( $self->param_required('species_name') )
    # All the reference dnafrags
        or die "Could not find the species named '".$self->param('species_name')."' in the database\n";
 #   
    my $all_dnafrags = [];
    if (scalar(@{$self->param('default_coord_system_names')})) {
        # Either from a predefined list of coord_system_name
        foreach my $cs_name (@{$self->param('default_coord_system_names')}) {
            push @$all_dnafrags, @{ $self->compara_dba->get_DnaFragAdaptor->fetch_all_by_GenomeDB_region($genome_db, $cs_name, undef, 1) };
        }
    } else {
        # Or all of them
        push @$all_dnafrags, @{ $self->compara_dba->get_DnaFragAdaptor->fetch_all_by_GenomeDB_region($genome_db, undef, undef, 1) };
    }

    if ($self->param('include_non_karyotype')) {
        warn "Using all the dnafrags (".scalar(@$all_dnafrags).") regardless of the has_karyotype() flag\n";
        $self->param('dnafrags_for_karyotype', $all_dnafrags);
        return;
    }

    # All the karyotype-level slices
    print Dumper($genome_db->db_adaptor());
    my $all_karyo_slices = $genome_db->db_adaptor->get_SliceAdaptor->fetch_all_karyotype();
    my %karyo_slice_names = map {$_->seq_region_name => 1} @$all_karyo_slices;

    # Intersect both lists
    my @dnafrags_for_karyotype = sort {$a->name cmp $b->name} grep {$karyo_slice_names{$_->name}} @$all_dnafrags;
    $self->param('dnafrags_for_karyotype', \@dnafrags_for_karyotype);
    warn "Found ".scalar(@dnafrags_for_karyotype)." dnafrags to use\n";
}


sub write_output {
    my ($self) = @_;

    foreach my $dnafrag (@{$self->param('dnafrags_for_karyotype')}) {
        $self->dataflow_output_id( { 'seq_region_name' => $dnafrag->name }, 2);
    }
}

1;

