=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::DumpMercatorFiles 

=head1 SYNOPSIS


=head1 DESCRIPTION

    Create Chromosome, Anchor and Hit files needed by Mercator.

Supported keys:
    'genome_db_id' => <number>
        The id of the query genome 

     'genome_db_ids' => < list_of_genome_db_ids >
        eg genome_db_ids => ' [61,108,111,112,38,60,101,43,31] '
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
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Analysis::Runnable::Mercator;
use Bio::EnsEMBL::Compara::DnaFragRegion;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
  my( $self) = @_;

  return 1;
}

sub run
{
  my $self = shift;
  $self->dumpMercatorFiles;
}

sub write_output {
  my ($self) = @_;
  return 1;
}

sub dumpMercatorFiles {
  my $self = shift;
  
  my $starttime = time();

  unless (defined $self->param('input_dir')) {
    my $input_dir = $self->worker_temp_directory . "/input_dir";
    $self->param('input_dir', $input_dir);
  }
  if (! -e $self->param('input_dir')) {
    mkdir($self->param('input_dir'), 0777);
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
  open F, ">$file";
  foreach my $df (@{$dfa->fetch_all_by_GenomeDB_region($gdb)}) {
      print F $df->name . "\t" . $df->length,"\n";
      if ($max_gap and $df->coord_system_name eq "chromosome") {
	  my $core_dba = $gdb->db_adaptor;
	  my $coord_system_adaptor = $core_dba->get_CoordSystemAdaptor();
	  my $assembly_mapper_adaptor = $core_dba->get_AssemblyMapperAdaptor();
	  my $chromosome_coord_system = $coord_system_adaptor->fetch_by_name("chromosome");
	  my $seq_level_coord_system = $coord_system_adaptor->fetch_sequence_level;

	  my $assembly_mapper = $assembly_mapper_adaptor->fetch_by_CoordSystems($chromosome_coord_system, $seq_level_coord_system);
	  my @mappings = $assembly_mapper->map($df->name, 1, $df->length, 1, $chromosome_coord_system);
	  
	  my $part = 1;
	  foreach my $this_mapping (@mappings) {
	      next if ($this_mapping->isa("Bio::EnsEMBL::Mapper::Coordinate"));
	      next if ($this_mapping->length < $max_gap);
	      # print join(" :: ", $df->name, $this_mapping->length, $this_mapping->start, $this_mapping->end), "\n";
	      print F $df->name . "--$part\t" . $df->length,"\n";
	      $dnafrags->{$df->name}->{$this_mapping->start} = $df->name."--".$part;
	      $part++;
	  }
      }
  }
  close F;

  ## Create the anchor file for Mercator
  $file = $self->param('input_dir') . "/$gdb_id.anchors";
  open F, ">$file";
  foreach my $member (@{$ma->fetch_all_by_source_genome_db_id('ENSEMBLPEP', $gdb_id)}) {
      my $strand = "+";
      $strand = "-" if ($member->chr_strand == -1);
      my $chr_name = $member->chr_name;
      if (defined($dnafrags->{$member->chr_name})) {
	  foreach my $this_start (sort {$a <=> $b} keys %{$dnafrags->{$member->chr_name}}) {
	      if ($this_start > $member->chr_start - 1) {
		  last;
	      } else {
		  $chr_name = ($dnafrags->{$member->chr_name}->{$this_start} or $member->chr_name);
	      }
	  }
      }
      print F $member->dbID . "\t" .
        $chr_name ."\t" .
          $strand . "\t" .
            ($member->chr_start - 1) ."\t" .
              $member->chr_end ."\t1\n";
  }
  close F;

  my $genome_db_ids = eval $self->param('genome_db_ids');

  my $gdb_id1 = $self->param('genome_db_id');

  foreach my $gdb_id2 (@$genome_db_ids) {
      my $file = $self->param('input_dir') . "/$gdb_id1" . "-$gdb_id2.hits";
      open F, ">$file";
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
        print F "$qmember_id\t$hmember_id\t" . int($score). "\t$evalue\n";
        $pair_seen{$qmember_id . "_" . $hmember_id} = 1;
    }
      close F;
      $sth->finish();
  }

  if($self->debug){printf("%1.3f secs to dump nib for \"%s\" collection\n", (time()-$starttime), $self->collection_name);}

  return 1;
}


sub get_sql_for_peptide_hits {
  my ($self, $gdb_id1, $gdb_id2) = @_;
  my $sql;

  my $table_name1 = $self->get_table_name_from_dbID($gdb_id1);
  my $table_name2 = $self->get_table_name_from_dbID($gdb_id2);

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


sub get_table_name_from_dbID {
  my ($self, $gdb_id) = @_;
  my $table_name = "peptide_align_feature";

  my $gdba = $self->compara_dba->get_GenomeDBAdaptor;
  my $gdb = $gdba->fetch_by_dbID($gdb_id);
  return $table_name if (!$gdb);

  $table_name .= "_" . $gdb_id;
  $table_name =~ s/ /_/g;

  return $table_name;
}

1;
