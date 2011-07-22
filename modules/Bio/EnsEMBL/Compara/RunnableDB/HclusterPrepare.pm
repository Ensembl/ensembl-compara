#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HclusterPrepare

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('HclusterPrepare');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::HclusterPrepare(
                         -input_id   => "{'species_set'=>[1,2,3,14]}",
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

package Bio::EnsEMBL::Compara::RunnableDB::HclusterPrepare;

use strict;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Graph::ConnectedComponents;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Time::HiRes qw(time gettimeofday tv_interval);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $gdb_id = $self->param('gdb_id') or die "'gdb_id' is an obligatory parameter";

    my $gdb = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($gdb_id) or die "no genome_db for id='$gdb_id'";
    $self->param('gdb', $gdb);

    my $gdb_in_outgroups = 0;
    foreach my $og_id (@{ $self->param('outgroups') || [] }) {
        if($og_id == $gdb_id) {
            $gdb_in_outgroups = 1;
        }
    }
    $self->param('gdb_in_outgroups', $gdb_in_outgroups);
}


sub run {
    my $self = shift;

    $self->analyze_table();
    $self->fetch_categories();
    $self->fetch_distances();
}


sub write_output {
    my $self = shift;

    return 1;
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

  my $gdb = $self->param('gdb');
  my $gdb_id = $gdb->dbID;
  my $species_name = lc($gdb->name);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";
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

  my $gdb = $self->param('gdb') or die "No genome_db object";

  my $starttime = time();

  my $gdb_id = $gdb->dbID;
  my $species_name = lc($gdb->name);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";
  my $species_set_string = join (",",@{$self->param('species_set')});
  my $sql = "SELECT ".
            "concat(qmember_id,'_',qgenome_db_id), ".
            "concat(hmember_id,'_',hgenome_db_id), ".
            "IF(evalue<1e-199,100,ROUND(-log10(evalue)/2)) ".
             "FROM $tbl_name WHERE qgenome_db_id=$gdb_id and hgenome_db_id in ($species_set_string);";
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

  my $gdb = $self->param('gdb') or die "No genome_db object";

  my $starttime = time();

  my $gdb_id = $gdb->dbID;
  my $species_name = lc($gdb->name);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";
  my $sql = "SELECT DISTINCT ".
            "qmember_id ".
             "FROM $tbl_name WHERE qgenome_db_id=$gdb_id;";
  print("$sql\n");
  my $sth = $self->compara_dba->prepare($sql);
  $sth->execute();
  printf("%1.3f secs to execute\n", (time()-$starttime));
  print("  done with fetch\n");

  my $filename = $self->param('cluster_dir') . "/" . "$tbl_name.hcluster.cat";

  my $outgroup = $self->param('gdb_in_outgroups') ? 2 : 1;

  my $member_id_hash;
  while ( my $ref  = $sth->fetchrow_arrayref() ) {
    my ($member_id) = @$ref;
    $member_id_hash->{$member_id} = 1;
  }
  $sth->finish;
  printf("%1.3f secs to gather distinct\n", (time()-$starttime));
  open FILE, ">$filename" or die "Cannot open $filename: $!";
  foreach my $member_id (keys %$member_id_hash) {
    print FILE "$member_id"."_","$gdb_id\t$outgroup\n";
  }
  close FILE;
  printf("%1.3f secs to process\n", (time()-$starttime));
}

1;
