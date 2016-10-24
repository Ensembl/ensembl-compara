=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DumpDnaCollectionFactory

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION


=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DumpDnaCollectionFactory;

use strict;
use warnings;

use File::Path;
use Time::HiRes qw(time gettimeofday tv_interval);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my ($self) = @_;

    $self->param_required('dump_min_size');
}


sub write_output {
  my( $self) = @_;

  $self->dumpNibFilesFactory;

  return 1;
}


##########################################
#
# internal methods
#
##########################################

sub dumpNibFilesFactory {
  my $self = shift;

  my $starttime = time();
  my $dna_collection = $self->compara_dba->get_DnaCollectionAdaptor->fetch_by_set_description($self->param('collection_name'));
  my $dump_loc = $dna_collection->dump_loc;

  unless (defined $dump_loc) {
    die("dump_loc directory is not defined, can not dump nib files\n");
  }

  foreach my $dnafrag_chunk_set (@{$dna_collection->get_all_DnaFragChunkSets}) {
      my $output_id;
      foreach my $dnafrag_chunk (@{$dnafrag_chunk_set->get_all_DnaFragChunks}) {
          next if ($dnafrag_chunk->length <= $self->param('dump_min_size'));

          my $nibfile = "$dump_loc/". $dnafrag_chunk->dnafrag->name . ".nib";
          
          #don't dump nibfile if it already exists
          next if (-e $nibfile);
          
          $output_id->{'DnaFragChunk'} = $dnafrag_chunk->dbID;
          
          #Add dataflow to branch 2
          $self->dataflow_output_id($output_id,2);
          
      }
  }

  if($self->debug){printf("%1.3f secs to dump nib for \"%s\" collection\n", (time()-$starttime), $self->param('collection_name'));}

  return 1;
}


1;
