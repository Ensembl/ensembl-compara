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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterPrepareSingleTable

=cut

=head1 CONTACT

  Please email comments or questions to the public Ensembl developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at <http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterPrepareSingleTable;

use strict;
use warnings;

use Time::HiRes qw(time gettimeofday tv_interval);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift @_;

    $self->analyze_table();
    $self->fetch_categories();
    $self->fetch_distances();
}


##########################################
#
# internal methods
#
##########################################


# This will make sure that the indexes for paf are fine
sub analyze_table {
  my $self = shift;

  my $starttime = time();

      # Re-enable the keys before starting the queries
  my $sql = "ALTER TABLE peptide_align_feature ENABLE KEYS";
  print("$sql\n") if ($self->debug);
  my $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute();
  $sth->finish();

  $sql = "ANALYZE TABLE peptide_align_feature";
  print("$sql\n") if ($self->debug);
  $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute();
  $sth->finish();

  printf("  %1.3f secs to ANALYZE TABLE\n", (time()-$starttime));
}


sub fetch_distances {
  my $self = shift;

  my $starttime = time();

  my $sql = qq{
    SELECT qmember_id,
           hmember_id,
           IF(evalue<1e-199,100,ROUND(-log10(evalue)/2))
      FROM peptide_align_feature paf
  };
  print +("$sql\n") if ($self->debug);
  my $sth = $self->compara_dba->dbc->prepare($sql, {'mysql_use_result' => 1});
  $sth->execute();
  printf("%1.3f secs to execute\n", (time()-$starttime));

  my $filename = $self->param('cluster_dir') . "/hcluster.txt";
  open(FILE, ">$filename") or die "Could not open '$filename' for writing : $!";
  my ($query_id, $hit_id, $score);
  $sth->bind_columns(\$query_id, \$hit_id, \$score);
  while ($sth->fetch) {
    print FILE "$query_id\t$hit_id\t$score\n";
  }
  $sth->finish;
  close FILE;
  printf("%1.3f secs to fetch/process\n", (time()-$starttime));
}


sub fetch_categories {
  my $self = shift;

  my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
  my $outgroups = $self->param('outgroups') || {};

  my $starttime = time();

  my $sql = "SELECT seq_member_id, genome_db_id FROM seq_member";
  print +("$sql\n") if ($self->debug);
  #my $sth = $self->compara_dba->dbc->prepare($sql, {'mysql_use_result' => 1});
  my $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute();
  printf("%1.3f secs to execute\n", (time()-$starttime));

  my $filename = $self->param('cluster_dir') . "/hcluster.cat";
  open(FILE, ">$filename") or die "Could not open '$filename' for writing : $!";
  my $seq_member_id;
  my $genome_db_id;
  $sth->bind_columns(\$seq_member_id, \$genome_db_id);
  while ($sth->fetch) {
    my $outgroup_category = $outgroups->{$genome_db_adaptor->fetch_by_dbID($genome_db_id)} || 1;
    print FILE "${seq_member_id}\t${outgroup_category}\n";
  }
  $sth->finish();
  close FILE;
  printf("%1.3f secs to fetch/process\n", (time()-$starttime));
}

1;
