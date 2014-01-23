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

Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Mercator 

=head1 SYNOPSIS


=head1 DESCRIPTION

Wrapper around Bio::EnsEMBL::Analysis::Runnable::Mercator
Create Pecan jobs

Supported keys:
    'genome_db_ids' => <list of genome_db_ids>
        The genome_db_ids for the Pecan method link species set

    'mlss_id' => <number>
        The id of the pecan method link species set. Used to retreive the genome_db_ids
        if not set by 'genome_db_ids'

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
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Analysis::Runnable::Mercator;
use Bio::EnsEMBL::Compara::DnaFragRegion;
use Bio::EnsEMBL::Analysis;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
  my( $self) = @_;

  if (!defined $self->param('genome_db_ids')) {
      my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor()->fetch_by_dbID($self->param('mlss_id'));
      my $species_set = $mlss->species_set_obj->genome_dbs;
      my $gdb_ids;
      foreach my $gdb (@$species_set) {
	    push @$gdb_ids, $gdb->dbID;
      }
      $self->param('genome_db_ids', $gdb_ids);
  }

  return 1;
}

sub run
{
  my $self = shift;
  my $fake_analysis     = Bio::EnsEMBL::Analysis->new;

  unless (defined $self->param('output_dir')) {
    my $output_dir = $self->worker_temp_directory . "/output_dir";
    $self->param('output_dir', $output_dir);
  }
  if (! -e $self->param('output_dir')) {
    mkdir($self->param('output_dir'), 0777);
  }
  my $runnable = new Bio::EnsEMBL::Analysis::Runnable::Mercator
    (-input_dir => $self->param('input_dir'),
     -output_dir => $self->param('output_dir'),
     -genome_names => $self->param('genome_db_ids'),
     -analysis => $fake_analysis,
     -program => $self->param('mercator_exe'));
  $self->param('runnable', $runnable);
  $runnable->run_analysis;
}

sub write_output {
  my ($self) = @_;

  my %run_ids2synteny_and_constraints;
  my $synteny_region_ids = $self->store_synteny(\%run_ids2synteny_and_constraints);
  foreach my $sr_id (@{$synteny_region_ids}) {

    #Flow into pecan
    my $dataflow_output_id = { synteny_region_id => $sr_id };
    $self->dataflow_output_id($dataflow_output_id,2);
  }

  return 1;
}

=head2 store_synteny

  Arg[1]      : hashref $run_ids2synteny_and_constraints (unused)
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
  my ($self, $run_ids2synteny_and_constraints) = @_;

  my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
  my $sra = $self->compara_dba->get_SyntenyRegionAdaptor;
  my $dfa = $self->compara_dba->get_DnaFragAdaptor;
  my $gdba = $self->compara_dba->get_GenomeDBAdaptor;

  my @genome_dbs;
  foreach my $gdb_id (@{$self->param('genome_db_ids')}) {
    my $gdb = $gdba->fetch_by_dbID($gdb_id);
    push @genome_dbs, $gdb;
  }
  my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
     -method => new Bio::EnsEMBL::Compara::Method( -type => $self->param('method_link_type') ),
     -species_set_obj => new Bio::EnsEMBL::Compara::SpeciesSet( -genome_dbs => \@genome_dbs ));
  $mlssa->store($mlss);

  my $synteny_region_ids;
  my %dnafrag_hash;
  foreach my $sr (@{$self->param('runnable')->output}) {
    my $synteny_region = new Bio::EnsEMBL::Compara::SyntenyRegion
      (-method_link_species_set_id => $mlss->dbID);
    my $run_id;
    foreach my $dfr (@{$sr}) {
      my ($gdb_id, $seq_region_name, $start, $end, $strand);
      ($run_id, $gdb_id, $seq_region_name, $start, $end, $strand) = @{$dfr};
      next if ($seq_region_name eq 'NA' && $start eq 'NA' && $end eq 'NA' && $strand eq 'NA');
      $seq_region_name =~ s/\-\-\d+$//;
      my $dnafrag = $dnafrag_hash{$gdb_id."_".$seq_region_name};
      unless (defined $dnafrag) {
        $dnafrag = $dfa->fetch_by_GenomeDB_and_name($gdb_id, $seq_region_name);
        $dnafrag_hash{$gdb_id."_".$seq_region_name} = $dnafrag;
      }
      $strand = ($strand eq "+")?1:-1;
      my $dnafrag_region = new Bio::EnsEMBL::Compara::DnaFragRegion
        (-dnafrag_id => $dnafrag->dbID,
         -dnafrag_start => $start+1, # because half-open coordinate system
         -dnafrag_end => $end,
         -dnafrag_strand => $strand);
      my $regions = $synteny_region->regions;
      push @$regions, $dnafrag_region;
      $synteny_region->regions($regions);
    }
    $sra->store($synteny_region);
    push @{$synteny_region_ids}, $synteny_region->dbID;
    push @{$run_ids2synteny_and_constraints->{$run_id}}, $synteny_region->dbID;
  }

  return $synteny_region_ids;
}

1;
