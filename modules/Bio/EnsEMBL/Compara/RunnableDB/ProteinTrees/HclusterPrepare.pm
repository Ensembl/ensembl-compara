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
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Graph::ConnectedComponents;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Time::HiRes qw(time gettimeofday tv_interval);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $genome_db_id = $self->param('genome_db_id') or die "'genome_db_id' is an obligatory parameter";

    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id) or die "no genome_db for id='$genome_db_id'";
    $self->param('genome_db', $genome_db);

    my $outgroups = $self->param('outgroups') || [];
    my $gdb_in_outgroups = { map { ($_ => 1) } @$outgroups }->{ $genome_db_id } || 0;
    $self->param('gdb_in_outgroups', $gdb_in_outgroups);

    my $mlss_id          = $self->param('mlss_id') or die "'mlss_id' is an obligatory parameter";
    my $mlss             = $self->compara_dba()->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id) or die "Could not fetch mlss with dbID=$mlss_id";
    my $species_set      = $mlss->species_set;
    my $genome_db_list   = (ref($species_set) eq 'ARRAY') ? $species_set : $species_set->genome_dbs();
    my $genome_db_id_csv = join(',', map { $_->dbID() } @$genome_db_list );

    $self->param('genome_db_id_csv', $genome_db_id_csv);
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

  my $starttime = time();

  my $genome_db = $self->param('genome_db');
  my $genome_db_id = $genome_db->dbID;
  my $species_name = lc($genome_db->name);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$genome_db_id";
  # Re-enable the keys before starting the queries
  my $sql = "ALTER TABLE $tbl_name ENABLE KEYS";

  print("$sql\n") if ($self->debug);
  my $sth = $self->compara_dba->prepare($sql);
  $sth->execute();

  $sql = "ANALYZE TABLE $tbl_name";

  #print("$sql\n");
  $sth = $self->compara_dba->prepare($sql);
  $sth->execute();
  printf("  %1.3f secs to ANALYZE TABLE\n", (time()-$starttime));
}


sub fetch_distances {
  my $self = shift;

  my $genome_db = $self->param('genome_db') or die "No genome_db object";

  my $starttime = time();

  my $genome_db_id = $genome_db->dbID;
  my $species_name = lc($genome_db->name);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$genome_db_id";
  my $genome_db_id_csv = $self->param('genome_db_id_csv');
  my $sql = "SELECT ".
            "concat(qmember_id,'_',qgenome_db_id), ".
            "concat(hmember_id,'_',hgenome_db_id), ".
            "IF(evalue<1e-199,100,ROUND(-log10(evalue)/2)) ".
             "FROM $tbl_name WHERE qgenome_db_id=$genome_db_id and hgenome_db_id in ($genome_db_id_csv);";
  print("$sql\n");
  my $sth = $self->compara_dba->prepare($sql);
  $sth->execute();
  printf("%1.3f secs to execute\n", (time()-$starttime));
  print("  done with fetch\n");
  my $filename = $self->param('cluster_dir') . "/" . "$tbl_name.hcluster.txt";
  open FILE, ">$filename" or die "Cannot open $filename: $!";
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

  my $genome_db = $self->param('genome_db') or die "No genome_db object";

  my $starttime = time();

  my $genome_db_id = $genome_db->dbID;
  my $species_name = lc($genome_db->name);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$genome_db_id";
  my $sql = "SELECT DISTINCT ".
            "qmember_id ".
             "FROM $tbl_name WHERE qgenome_db_id=$genome_db_id;";
  print("$sql\n");
  my $sth = $self->compara_dba->prepare($sql);
  $sth->execute();
  printf("%1.3f secs to execute\n", (time()-$starttime));
  print("  done with fetch\n");

  my $filename = $self->param('cluster_dir') . "/" . "$tbl_name.hcluster.cat";

  my $outgroup_index = $self->param('gdb_in_outgroups') ? 2 : 1;

  my $member_id_hash;
  while ( my $ref  = $sth->fetchrow_arrayref() ) {
    my ($member_id) = @$ref;
    $member_id_hash->{$member_id} = 1;
  }
  $sth->finish;
  printf("%1.3f secs to gather distinct\n", (time()-$starttime));
  open FILE, ">$filename" or die "Cannot open $filename: $!";
  foreach my $member_id (keys %$member_id_hash) {
    print FILE "$member_id"."_","$genome_db_id\t$outgroup_index\n";
  }
  close FILE;
  printf("%1.3f secs to process\n", (time()-$starttime));
}

1;
