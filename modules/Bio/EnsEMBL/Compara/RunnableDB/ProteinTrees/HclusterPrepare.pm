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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterPrepare

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('HclusterPrepare');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterPrepare(
                         -input_id   => "{'mlss_id'=>40069,'genome_db_id'=>90}",
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

=cut

=head1 CONTACT

  Please email comments or questions to the public Ensembl developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at <http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterPrepare;

use strict;
use warnings;

use Time::HiRes qw(time gettimeofday tv_interval);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'outgroup_category' => undef,
        'outgroups'         => {},
    };
}


sub fetch_input {
    my $self = shift @_;

    my $mlss_id      = $self->param_required('mlss_id');

    my $genome_db_id = $self->param_required('genome_db_id');
    my $genome_db    = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) or die "no genome_db for id='$genome_db_id'";

    if ($genome_db->is_polyploid) {
        $self->complete_early("Polyploid genomes don't have blastp hits attached to them\n");
    }

    my $table_name  = 'peptide_align_feature_' . $genome_db_id;
    $self->param('table_name', $table_name);

    unless(defined($self->param('outgroup_category'))) {    # it can either be passed in or computed
        my $outgroups = $self->param('outgroups');
        my $outgroup_category =  $outgroups->{$genome_db->name} || 1;
        $self->param('outgroup_category', $outgroup_category);
    }
}


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

  my $table_name = $self->param('table_name');

  my $starttime = time();

      # Re-enable the keys before starting the queries
  my $sql = "ALTER TABLE $table_name ENABLE KEYS";
  print("$sql\n") if ($self->debug);
  my $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute();
  $sth->finish();

  $sql = "ANALYZE TABLE $table_name";
  print("$sql\n") if ($self->debug);
  $sth = $self->compara_dba->dbc->prepare($sql);
  $sth->execute();
  $sth->finish();

  printf("  %1.3f secs to ANALYZE TABLE\n", (time()-$starttime));
}


sub fetch_distances {
  my $self = shift;

  my $table_name        = $self->param('table_name');
  my $genome_db_id      = $self->param('genome_db_id');
  my $mlss_id           = $self->param('mlss_id');

  my $starttime = time();

  my $sql = qq{
    SELECT concat(qmember_id,'_',qgenome_db_id),
           concat(hmember_id,'_',hgenome_db_id),
           IF(evalue<1e-199,100,ROUND(-log10(evalue)/2))
      FROM $table_name paf, species_set ss, method_link_species_set mlss
     WHERE mlss.method_link_species_set_id=$mlss_id
       AND mlss.species_set_id=ss.species_set_id
       AND ss.genome_db_id=paf.hgenome_db_id
       AND paf.qgenome_db_id=$genome_db_id
  };
  print +("$sql\n") if ($self->debug);
  my $sth = $self->compara_dba->dbc->prepare($sql, { 'mysql_use_result' => 1 });
  $sth->execute();
  printf("%1.3f secs to execute\n", (time()-$starttime));

  my $filename = $self->param('cluster_dir') . "/$table_name.hcluster.txt";
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

  my $table_name        = $self->param('table_name');
  my $genome_db_id      = $self->param('genome_db_id');
  my $outgroup_category = $self->param('outgroup_category');

  my $starttime = time();

  my $sql = "SELECT DISTINCT ".
            "qmember_id ".
             "FROM $table_name WHERE qgenome_db_id=$genome_db_id;";
  print +("$sql\n") if ($self->debug);
  my $sth = $self->compara_dba->dbc->prepare($sql, { 'mysql_use_result' => 1 });
  $sth->execute();
  printf("%1.3f secs to execute\n", (time()-$starttime));

  my $filename = $self->param('cluster_dir') . "/$table_name.hcluster.cat";
  open(FILE, ">$filename") or die "Could not open '$filename' for writing : $!";
  my $seq_member_id;
  $sth->bind_columns(\$seq_member_id);
  while ($sth->fetch) {
    print FILE "${seq_member_id}_${genome_db_id}\t${outgroup_category}\n";
  }
  $sth->finish();
  close FILE;
  printf("%1.3f secs to fetch/process\n", (time()-$starttime));
}

1;
