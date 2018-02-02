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

Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Mercator 

=head1 DESCRIPTION

Wrapper around Bio::EnsEMBL::Analysis::Runnable::Mercator
Create Pecan jobs

Supported keys:
    'mlss_id' => <number>
        The id of the pecan method link species set.

     'input_dir' => <directory_path>
        Location of input files

     'output_dir' => <directory_path>
        Location to write output files

     'method_link_type' => <type>
        Synteny method link type 
        eg "method_link_type" => "SYNTENY"

=cut


package Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Mercator;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::Production::Analysis::Mercator;
use Bio::EnsEMBL::Compara::DnaFragRegion;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my ($self) = @_;

    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor()->fetch_by_dbID($self->param_required('mlss_id'));
    my @gdb_ids = map {$_->dbID} @{ $mlss->species_set->genome_dbs };
    $self->param('genome_db_ids', \@gdb_ids);
}

sub run
{
  my $self = shift;

  unless (defined $self->param('output_dir')) {
    my $output_dir = $self->worker_temp_directory . "/output_dir";
    $self->param('output_dir', $output_dir);
  }
  if (! -e $self->param('output_dir')) {
    mkdir($self->param('output_dir'));
  }
  my $mercator_output = Bio::EnsEMBL::Compara::Production::Analysis::Mercator::run_mercator($self);
  $self->param('mercator_output', $mercator_output);
}

sub write_output {
  my ($self) = @_;

  my $synteny_regions = $self->store_synteny();
  foreach my $sr (@{$synteny_regions}) {
    #Flow into pecan
    my $dataflow_output_id = { synteny_region_id => $sr->dbID , dnafrag_count => $sr->{'__dnafrag_count'}, total_residues_count => $sr->{'__total_residues_count'} };
    $self->dataflow_output_id($dataflow_output_id,2);
  }
  return 1;
}

=head2 store_synteny

  Example     : $self->store_synteny();
  Description : This method will store the syntenies defined by Mercator
                into the compara DB. The MethodLinkSpecieSet for these
                syntenies is created and stored if needed at this point.
                The IDs for the new Bio::EnsEMBL::Compara::SyntenyRegion
                objects are returned in an arrayref.
  ReturnType  : arrayref of integer
  Exceptions  :
  Status      : stable

=cut

sub store_synteny {
  my ($self) = @_;

  my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  my $sra = $self->compara_dba->get_SyntenyRegionAdaptor;
  my $dfa = $self->compara_dba->get_DnaFragAdaptor;

  my $mlss_id = $self->param_required('mlss_id');

  # Now we add new regions for the non-nuclear cellular components
  my @extra_synteny_groups;
  my $genome_dbs = $mlssa->fetch_by_dbID($mlss_id)->species_set->genome_dbs;
  foreach my $cellular_component (qw(MT PT)) {
      my @regions;
      foreach my $genome_db (@$genome_dbs) {
          foreach my $dnafrag (@{ $dfa->fetch_all_by_GenomeDB_region($genome_db, undef, undef, 1, $cellular_component) }) {
              push @regions, [$cellular_component, $dnafrag->genome_db_id, $dnafrag->name.'--1', 1, $dnafrag->length, '+'];
          }
      }
      push @extra_synteny_groups, \@regions if scalar(@regions) > 1;
  }

  my $synteny_regions;
  foreach my $sr (@{$self->param('mercator_output')}, @extra_synteny_groups) {
    my @regions;
    my $run_id;
    my $total_residues_count = 0;
    foreach my $dfr (@{$sr}) {
      my ($gdb_id, $seq_region_name, $start, $end, $strand);
      ($run_id, $gdb_id, $seq_region_name, $start, $end, $strand) = @{$dfr};
      next if ($seq_region_name eq 'NA' && $start eq 'NA' && $end eq 'NA' && $strand eq 'NA');
      $seq_region_name =~ s/\-\-\d+$//;
      my $dnafrag = $dfa->fetch_by_GenomeDB_and_name($gdb_id, $seq_region_name);
      $strand = ($strand eq "+")?1:-1;
      my $dnafrag_region = Bio::EnsEMBL::Compara::DnaFragRegion->new_fast( {
              'dnafrag_id'      => $dnafrag->dbID,
              'dnafrag_start'   => $start+1, # because half-open coordinate system
              'dnafrag_end'     => $end,
              'dnafrag_strand'  => $strand,
      } );
      $total_residues_count += $end - $start;
      push @regions, $dnafrag_region;
    }
    my $synteny_region = Bio::EnsEMBL::Compara::SyntenyRegion->new_fast( {
        'method_link_species_set_id' => $mlss_id,
        'regions' => \@regions,
        # These two fields are not part of SyntenyRegion, but needed to populate the dataflow event
        '__dnafrag_count'           => scalar(@regions),
        '__total_residues_count'    => $total_residues_count,
    } );
    $sra->store($synteny_region);
    push @{$synteny_regions}, $synteny_region;
  }

  return $synteny_regions;
}

1;
