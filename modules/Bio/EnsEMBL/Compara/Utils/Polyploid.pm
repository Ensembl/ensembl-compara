=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::Utils::Polyploid

=head1 DESCRIPTION

Utility module for handling polyploid genomes.

=cut

package Bio::EnsEMBL::Compara::Utils::Polyploid;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);

use base qw(Exporter);


our @EXPORT_OK = qw(
    map_dnafrag_to_genome_component
);


=head2 map_dnafrag_to_genome_component

  Arg [1]     : Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Example     : my $component_dnafrag = map_dnafrag_to_genome_component($principal_dnafrag);
  Description : Given a DnaFrag in a polyploid principal GenomeDB, this method returns
                the equivalent DnaFrag on its corresponding component GenomeDB,
                or undef if the DnaFrag is not present on any component GenomeDB.
  Returntype  : Bio::EnsEMBL::Compara::DnaFrag or undef
  Exceptions  : none
  Caller      : general
  Status      : Experimental

=cut

sub map_dnafrag_to_genome_component {
    my ($principal_dnafrag) = @_;

    if(!defined($principal_dnafrag->adaptor)) {
        throw('cannot map dnafrag ' . $principal_dnafrag->name . ' without an adaptor');
    }

    my $principal_gdb = $principal_dnafrag->genome_db;
    if (!defined $principal_gdb) {
        throw('cannot map dnafrag ' . $principal_dnafrag->name . ' to a subgenome - no genome defined');
    } elsif (!$principal_gdb->is_polyploid()) {
        throw('cannot map dnafrag ' . $principal_dnafrag->name . ' to a subgenome from non-polyploid genome' . $principal_gdb->name);
    }

    my @component_dnafrags = grep { defined } map {
        $principal_dnafrag->adaptor->fetch_by_GenomeDB_and_name($_, $principal_dnafrag->name)
    } @{$principal_gdb->component_genome_dbs()};

    my $component_dnafrag;
    if (scalar(@component_dnafrags) == 1) {
        $component_dnafrag = $component_dnafrags[0];
    } elsif (scalar(@component_dnafrags) == 0) {
        # A DnaFrag may be present in a polyploid principal GenomeDB but not in any of its subgenomes
        # (e.g. scaffold_v5_108365 in triticum_aestivum_landmark), so we let it off with a warning.
        warning('cannot map dnafrag ' . $principal_dnafrag->name . ' to any subgenome of ' . $principal_gdb->name);
    } else {
        throw('cannot map dnafrag ' . $principal_dnafrag->name . ' to a unique subgenome of ' . $principal_gdb->name);
    }

    return $component_dnafrag;
}


1;
