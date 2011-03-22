#
# You may distribute this module under the same terms as perl itself
#
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

=head1 DESCRIPTION

Blah

=cut

=head1 CONTACT

  Contact Albert Vilella on module implemetation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HclusterPrepare;

use strict;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Time::HiRes qw(time gettimeofday tv_interval);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $mlss_id      = $self->param('mlss_id') or die "'mlss_id' is an obligatory parameter";

    my $genome_db_id = $self->param('genome_db_id') or die "'genome_db_id' is an obligatory parameter";
    my $genome_db    = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) or die "no genome_db for id='$genome_db_id'";

    my $per_genome_suffix = $self->param('per_genome_suffix') || ($genome_db->name . '_' . $genome_db_id);
    my $table_name  = 'peptide_align_feature_' . $per_genome_suffix;
    $self->param('table_name', $table_name);

    unless(defined($self->param('outgroup_category'))) {    # it can either be passed in or computed
        my $outgroups = $self->param('outgroups') || [];
        my $gdb_in_outgroups  = { map { ($_ => 1) } @$outgroups }->{ $genome_db_id } || 0;
        my $outgroup_category = $gdb_in_outgroups ? 2 : 1;
        $self->param('outgroup_category', $outgroup_category);
    }
}


sub run {
    my $self = shift @_;

    $self->analyze_table();
    $self->fetch_categories();
    $self->fetch_distances();
}


sub write_output {
    my $self = shift @_;

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
  my $sth = $self->compara_dba->prepare($sql);
  $sth->execute();

  $sql = "ANALYZE TABLE $table_name";
  print("$sql\n") if ($self->debug);
  $sth = $self->compara_dba->prepare($sql);
  $sth->execute();

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
  print("$sql\n") if ($self->debug);
  my $sth = $self->compara_dba->prepare($sql);
  $sth->execute();
  printf("%1.3f secs to execute\n", (time()-$starttime));
  print("  done with fetch\n");

  my $filename = $self->param('cluster_dir') . '/' . "$table_name.hcluster.txt";
  open(FILE, ">$filename") or die "Could not open '$filename' for writing : $!";
  while ( my $ref  = $sth->fetchrow_arrayref() ) {
    my ($query_id, $hit_id, $score) = @$ref;
    print FILE "$query_id\t$hit_id\t$score\n";
  }
  $sth->finish;
  close FILE;
  printf("%1.3f secs to process\n", (time()-$starttime));
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
  print("$sql\n");
  my $sth = $self->compara_dba->prepare($sql);
  $sth->execute();
  printf("%1.3f secs to execute\n", (time()-$starttime));
  print("  done with fetch\n");

  my $filename = $self->param('cluster_dir') . '/' . "$table_name.hcluster.cat";
  my $member_id_hash;
  while ( my $ref  = $sth->fetchrow_arrayref() ) {
    my ($member_id) = @$ref;
    $member_id_hash->{$member_id} = 1;
  }
  $sth->finish;
  printf("%1.3f secs to gather distinct\n", (time()-$starttime));
  open(FILE, ">$filename") or die "Could not open '$filename' for writing : $!";
  foreach my $member_id (keys %$member_id_hash) {
    print FILE "${member_id}_${genome_db_id}\t${outgroup_category}\n";
  }
  close FILE;
  printf("%1.3f secs to process\n", (time()-$starttime));
}

1;
