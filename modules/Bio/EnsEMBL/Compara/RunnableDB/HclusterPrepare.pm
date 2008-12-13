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
use Switch;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive;
use Bio::EnsEMBL::Compara::NestedSet;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Graph::ConnectedComponents;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Time::HiRes qw(time gettimeofday tv_interval);

our @ISA = qw(Bio::EnsEMBL::Hive::Process);

sub fetch_input {
  my( $self) = @_;

  $self->{'species_set'} = undef;
  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{gdba} = $self->{'comparaDBA'}->get_GenomeDBAdaptor;

  $self->get_params($self->parameters);

  my $input_gdb_id = $self->input_id;
  my $gdb = $self->{gdba}->fetch_by_dbID($input_gdb_id);
  throw("no genome_db for $input_gdb_id") unless(defined($gdb));
  $self->{gdb} = $gdb;

  return 1;
}


sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return if ($param_string eq "1");

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  foreach my $key (keys %$params) {
    print("  $key : ", $params->{$key}, "\n");
  }

  if (defined $params->{'species_set'}) {
    $self->{'species_set'} = $params->{'species_set'};
  }
  if (defined $params->{'fasta_dir'}) {
    $self->{'fasta_dir'} = $params->{'fasta_dir'};
  }
  if (defined $params->{'outgroups'}) {
    foreach my $outgroup (@{$params->{'outgroups'}}) {
      $self->{outgroups}{$outgroup} = 1;
    }
  }

  print("parameters...\n");
  printf("  fasta_dir    : %d\n", $self->{'fasta_dir'});
  printf("  species_set  : (%s)\n", join(',', @{$self->{'species_set'}}));
  printf("  outgroups    : (%s)\n", join(',', keys %{$self->{'outgroups'}}));

  return;
}

sub run
{
  my $self = shift;

  $self->analyze_table();
  $self->fetch_categories();
  $self->fetch_distances();
  return 1;
}

sub write_output {
  my $self = shift;

#   $self->store_clusters;
#   $self->dataflow_clusters;

#   # modify input_job so that it now contains the clusterset_id
#   my $outputHash = {};
#   $outputHash = eval($self->input_id) if(defined($self->input_id) && $self->input_id =~ /^\s*\{.*\}\s*$/);
#   $outputHash->{'clusterset_id'} = $self->{'clusterset_id'};
#   my $output_id = $self->encode_hash($outputHash);
#   $self->input_job->input_id($output_id);

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

  my $gdb = $self->{gdb};
  my $gdb_id = $gdb->dbID;
  my $species_name = lc($gdb->name);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";
  # Re-enable the keys before starting the queries
  my $sql = "ALTER TABLE $tbl_name ENABLE KEYS";

  print("$sql\n") if ($self->debug);
  my $sth = $self->dbc->prepare($sql);
  $sth->execute();

  $sql = "ANALYZE TABLE $tbl_name";

  #print("$sql\n");
  $sth = $self->dbc->prepare($sql);
  $sth->execute();
  printf("  %1.3f secs to ANALYZE TABLE\n", (time()-$starttime));
}


sub fetch_distances {
  my $self = shift;

  return unless($self->{'gdb'});
  my $gdb = $self->{'gdb'};
  return unless $gdb;

  my $starttime = time();

  $DB::single=1;1;#??
  my $gdb_id = $gdb->dbID;
  my $species_name = lc($gdb->name);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";
  my $species_set_string = join (",",@{$self->{species_set}});
  my $sql = "SELECT ".
            "concat(qmember_id,'_',qgenome_db_id), ".
            "concat(hmember_id,'_',hgenome_db_id), ".
            "IF(evalue<1e-199,100,ROUND(-log10(evalue)/2)) ".
             "FROM $tbl_name WHERE qgenome_db_id=$gdb_id and hgenome_db_id in ($species_set_string);";
  print("$sql\n");
  my $sth = $self->dbc->prepare($sql);
  $sth->execute();
  printf("%1.3f secs to execute\n", (time()-$starttime));
  print("  done with fetch\n");
  my $filename = $self->{fasta_dir} . "/" . "$tbl_name.hcluster.txt";
  open FILE, ">$filename" or die $!;
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

  return unless($self->{'gdb'});
  my $gdb = $self->{'gdb'};
  return unless $gdb;

  my $starttime = time();


  my $gdb_id = $gdb->dbID;
  my $species_name = lc($gdb->name);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";
  my $sql = "SELECT m.member_id".
        " FROM member m, subset_member sm WHERE m.member_id=sm.member_id AND m.genome_db_id=$gdb_id;";
  print("$sql\n");
  my $sth = $self->dbc->prepare($sql);
  $sth->execute();
  printf("%1.3f secs to execute\n", (time()-$starttime));
  print("  done with fetch\n");
  $DB::single=1;1;
  my $filename = $self->{fasta_dir} . "/" . "$tbl_name.hcluster.cat";
  open FILE, ">$filename" or die $!;

  my $outgroup = 1;
  $outgroup = 2 if (defined($self->{outgroups}{$gdb_id}));

  while ( my $ref  = $sth->fetchrow_arrayref() ) {
    my ($member_id) = @$ref;
    print FILE "$member_id"."_","$gdb_id\t$outgroup\n";
  }
  $sth->finish;
  close FILE;
  printf("%1.3f secs to process\n", (time()-$starttime));
}

1;
