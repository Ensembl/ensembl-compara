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

Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::DumpMercatorFiles 

=head1 DESCRIPTION

    Create Chromosome, Anchor and Hit files needed by Mercator.

Supported keys:
    'genome_db_id' => <number>
        The id of the query genome 

     'genome_db_ids' => < list_of_genome_db_ids >
        eg genome_db_ids => [61,108,111,112,38,60,101,43,31]
        List of genome ids to match against

     'all_hits' => <0|1>
        Whether to perform all best hits (1) or best reciprocal hits only (0)

     'input_dir' => < directory_path >
        Location to write files required by Mercator

     'maximum_gap' => <number>
        eg 50000

     'cutoff_score' => <number>
         Filter by score. Not normally used

     'cutoff_evalue' => <number>
         Filter by evalue. Not normally used

=cut

package Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::DumpMercatorFiles;

use strict;
use warnings;

use Time::HiRes qw(time gettimeofday tv_interval);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run
{
  my $self = shift;
  $self->dumpMercatorFiles;
}


sub dumpMercatorFiles {
  my $self = shift;
  
  my $starttime = time();

  unless (defined $self->param('input_dir')) {
    my $input_dir = $self->worker_temp_directory . "/input_dir";
    $self->param('input_dir', $input_dir);
  }
  if (! -e $self->param('input_dir')) {
    mkdir($self->param('input_dir'));
  }

  my $dfa = $self->compara_dba->get_DnaFragAdaptor;
  my $gdba = $self->compara_dba->get_GenomeDBAdaptor;
  my $ma = $self->compara_dba->get_SeqMemberAdaptor;

  my $max_gap = $self->param('maximum_gap');

  my $gdb_id = $self->param('genome_db_id');

  my $dnafrags;

  ## Create the Chromosome file for Mercator
  my $gdb = $gdba->fetch_by_dbID($gdb_id);
  my $file = $self->param('input_dir') . "/$gdb_id.chroms";
  open(my $fh, '>', $file);
  my $core_dba = $gdb->db_adaptor;
 $core_dba->dbc->prevent_disconnect( sub {
  my $coord_system_adaptor = $core_dba->get_CoordSystemAdaptor();
  my $assembly_mapper_adaptor = $core_dba->get_AssemblyMapperAdaptor();
  my $chromosome_coord_system = $coord_system_adaptor->fetch_by_name("chromosome");
  my $seq_level_coord_system = $coord_system_adaptor->fetch_sequence_level;
  my $assembly_mapper = $assembly_mapper_adaptor->fetch_by_CoordSystems($chromosome_coord_system, $seq_level_coord_system);
  foreach my $df (@{$dfa->fetch_all_by_GenomeDB_region($gdb)}) {
      print $fh $df->name . "\t" . $df->length,"\n";
      if ($max_gap and $df->coord_system_name eq "chromosome") {

	  my @mappings = $assembly_mapper->map($df->name, 1, $df->length, 1, $chromosome_coord_system);
	  
	  my $part = 1;
	  foreach my $this_mapping (@mappings) {
	      next if ($this_mapping->isa("Bio::EnsEMBL::Mapper::Coordinate"));
	      next if ($this_mapping->length < $max_gap);
	      # print join(" :: ", $df->name, $this_mapping->length, $this_mapping->start, $this_mapping->end), "\n";
	      print $fh $df->name . "--$part\t" . $df->length,"\n";
	      $dnafrags->{$df->dbID}->{$this_mapping->start} = $df->name."--".$part;
	      $part++;
	  }
      }
  }
 } );
  close $fh;

  ## Create the anchor file for Mercator
  $file = $self->param('input_dir') . "/$gdb_id.anchors";
  open($fh, '>', $file);
  foreach my $member (@{$ma->fetch_all_by_GenomeDB($gdb_id)}) {
      my $strand = "+";
      $strand = "-" if ($member->dnafrag_strand == -1);
      my $dnafrag_name = $member->dnafrag->name;
      if (defined($dnafrags->{$member->dnafrag_id})) {
	  foreach my $this_start (sort {$a <=> $b} keys %{$dnafrags->{$member->dnafrag_id}}) {
	      if ($this_start > $member->dnafrag_start - 1) {
		  last;
	      } else {
		  $dnafrag_name = ($dnafrags->{$member->dnafrag_id}->{$this_start} or $member->dnafrag->name);
	      }
	  }
      }
      print $fh $member->dbID . "\t" .
        $dnafrag_name ."\t" .
          $strand . "\t" .
            ($member->dnafrag_start - 1) ."\t" .
              $member->dnafrag_end ."\t1\n";
  }
  close $fh;

  my $genome_db_ids = $self->param('genome_db_ids');

  my $gdb_id1 = $self->param('genome_db_id');

  foreach my $gdb_id2 (@$genome_db_ids) {
      my $file = $self->param('input_dir') . "/$gdb_id1" . "-$gdb_id2.hits";
      open($fh, '>', $file);
      my $sql = $self->get_sql_for_peptide_hits($gdb_id1, $gdb_id2);
      my $sth = $self->compara_dba->dbc->prepare($sql);
      my ($qmember_id,$hmember_id,$score1,$evalue1,$score2,$evalue2);
      $sth->execute($gdb_id1, $gdb_id2);
      $sth->bind_columns( \$qmember_id,\$hmember_id,\$score1,\$evalue1,\$score2,\$evalue2);
      my %pair_seen = ();
      while ($sth->fetch()) {
        next if ($pair_seen{$qmember_id . "_" . $hmember_id});
        my $score = ($score1>$score2)?$score2:$score1; ## Use smallest score
        my $evalue = ($evalue1>$evalue2)?$evalue1:$evalue2; ## Use largest e-value
        next if (defined $self->param('cutoff_score') && $score < $self->param('cutoff_score'));
        next if (defined $self->param('cutoff_evalue') && $evalue > $self->param('cutoff_evalue'));
        print $fh "$qmember_id\t$hmember_id\t" . int($score). "\t$evalue\n";
        $pair_seen{$qmember_id . "_" . $hmember_id} = 1;
    }
      close $fh;
      $sth->finish();
  }

  if($self->debug){printf("%1.3f secs to dump mercator files for \"%s\"\n", (time()-$starttime), $gdb->name);}

  return 1;
}


sub get_sql_for_peptide_hits {
  my ($self, $gdb_id1, $gdb_id2) = @_;
  my $sql;

  my $table_name1 = "peptide_align_feature_$gdb_id1";
  my $table_name2 = "peptide_align_feature_$gdb_id2";

  if ($self->param('all_hits')) {
    ## Use all best hits
    $sql = "SELECT paf1.qmember_id, paf1.hmember_id, paf1.score, paf1.evalue, paf2.score, paf2.evalue
      FROM $table_name1 paf1, $table_name2 paf2
      WHERE paf1.qgenome_db_id = ? AND paf1.hgenome_db_id = ?
        AND paf1.qmember_id = paf2.hmember_id AND paf1.hmember_id = paf2.qmember_id
        AND (paf1.hit_rank = 1 OR paf2.hit_rank = 1)";
  } else {
    ## Use best reciprocal hits only
    $sql = "SELECT paf1.qmember_id, paf1.hmember_id, paf1.score, paf1.evalue, paf2.score, paf2.evalue
      FROM $table_name1 paf1, $table_name2 paf2
      WHERE paf1.qgenome_db_id = ? AND paf1.hgenome_db_id = ?
        AND paf1.qmember_id = paf2.hmember_id AND paf1.hmember_id = paf2.qmember_id
        AND paf1.hit_rank = 1 AND paf2.hit_rank = 1";
  }

  return $sql;
}


1;
