#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::UpdatePAFIds

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('UpdatePAFIds');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::UpdatePAFIds(
                         -input_id   => 1,
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

=cut

=head1 DESCRIPTION

This is a compara specific runnableDB, that based on an input_id
of arrayrefs of genome_db_ids, and from this species set relationship
it will search through the peptide_align_feature data and build 
SingleLinkage Clusters and store them into a NestedSet datastructure.
This is the first step in the ProteinTree analysis production system.

=cut

=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL/Compara: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::UpdatePAFIds;

use strict;
use Switch;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive;
use Time::HiRes qw(time gettimeofday tv_interval);

our @ISA = qw(Bio::EnsEMBL::Hive::Process);

sub fetch_input {
  my( $self) = @_;

  $self->{'species_set'} = undef;
  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the pipeline DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{gdba} = $self->{'comparaDBA'}->get_GenomeDBAdaptor;

  $self->get_params($self->parameters);

  my @species_set = @{$self->{'species_set'}};
  my %seen;
  foreach my $gdb_id (@species_set) {
    next if (defined($seen{$gdb_id})); # Make sure we dont have repeated gdbs, specially for setS in Old Homology
    my $gdb = $self->{gdba}->fetch_by_dbID($gdb_id);
    push @{$self->{'genomeDB_set'}}, $gdb;
    $seen{$gdb_id} = 1;
  }

  # Before we were using all the species in genome_db, which is ok for
  # EnsEMBL Compara, but could cause problems for people running their
  # stuff on subsets of genome_db
  # $self->{'genomeDB_set'} = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_all;

  return 1;
}

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  foreach my $key (keys %$params) {
    print("  $key : ", $params->{$key}, "\n");
  }

  # Species_set is usually for the new genetree pipeline
  if (defined $params->{'species_set'}) {
    $self->{'species_set'} = $params->{'species_set'};
  }

  # Species_sets is usually for the old homology pipeline
  if (defined $params->{'species_sets'}) {
    foreach my $species_set (@{$params->{'species_sets'}}) {
      push @{$self->{'species_set'}}, @$species_set;
    }
  }

  return;
}

sub run
{
  my $self = shift;

  $self->updatepafids();
  return 1;
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
sub updatepafids {
  my $self = shift;

  my $starttime = time();

  my @tbl_names;
  foreach my $gdb (@{$self->{'genomeDB_set'}}) {
    my $gdb_id = $gdb->dbID;
    my $species_name = lc($gdb->name);
    $species_name =~ s/\ /\_/g;
    my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";
    push @tbl_names, $tbl_name;
  }
  # Find all the max, start from the smallest
  my $top_max;
  foreach my $tbl_name (sort @tbl_names) {
    my $sql = "SELECT MAX(peptide_align_feature_id) as max".
      " FROM $tbl_name";
    my $sth = $self->dbc->prepare($sql);
    $sth->execute();
    my $first_offset_hash = $sth->fetchrow_hashref;
    my $first_offset = $first_offset_hash->{max};
    $top_max->{$first_offset} = $tbl_name;
  }
  my ($first_tbl_name, @rest_tbl_names) = map {$top_max->{$_}} sort {$b<=>$a} keys %{$top_max};
  # First offset -- first table remains as it is
  my $sql = "SELECT MAX(peptide_align_feature_id) as max".
            " FROM $first_tbl_name";
  my $sth = $self->dbc->prepare($sql);
  $sth->execute();
  my $first_offset_hash = $sth->fetchrow_hashref;
  my $first_offset = $first_offset_hash->{max};
  # Subsequent offsets -- subsequent tables are offsetted
  foreach my $tbl_name (sort @rest_tbl_names) {
    my $sql = "SELECT MIN(peptide_align_feature_id) as min".
            " FROM $tbl_name";
    my $sth = $self->dbc->prepare($sql);
    $sth->execute();
    my $offset_hash = $sth->fetchrow_hashref;
    my $offset = $offset_hash->{min};
    if ($offset > 1) {
      $sql = "SELECT MAX(peptide_align_feature_id) as max".
              " FROM $tbl_name";
      $sth = $self->dbc->prepare($sql);
      $sth->execute();
      my $second_offset_hash = $sth->fetchrow_hashref;
      my $second_offset = $second_offset_hash->{max};
      $first_offset = $second_offset;
      next;
    } # Dont reupdate it if done before

    $sql = "SELECT MAX(peptide_align_feature_id) as max".
              " FROM $tbl_name";
    $sth = $self->dbc->prepare($sql);
    $sth->execute();

    my $second_offset_hash = $sth->fetchrow_hashref;
    my $second_offset = $second_offset_hash->{max};

#     my $sql2 = "UPDATE $tbl_name".
#                " SET peptide_align_feature_id=peptide_align_feature_id+$first_offset";
#     my $sth2 = $self->dbc->prepare($sql2);
#     print STDERR "Executing [", $sth2->sql, "].\n";
#     $sth2->execute();
    #####
    my $temp_tbl_name = $tbl_name . "_temp";
    my $sql2 = "CREATE TABLE $temp_tbl_name LIKE $tbl_name";
    my $sth2 = $self->dbc->prepare($sql2);
    print STDERR "Executing [", $sth2->sql, "].\n";
    $sth2->execute();

    $sql2 = "ALTER TABLE $temp_tbl_name AUTO_INCREMENT=$first_offset";
    $sth2 = $self->dbc->prepare($sql2);
    print STDERR "Executing [", $sth2->sql, "].\n";
    $sth2->execute();

    $sql2 = "ALTER TABLE $temp_tbl_name DISABLE KEYS";
    $sth2 = $self->dbc->prepare($sql2);
    print STDERR "Executing [", $sth2->sql, "].\n";
    $sth2->execute();

    $sql2 = "INSERT INTO $temp_tbl_name (qmember_id, hmember_id, qgenome_db_id, hgenome_db_id, analysis_id, qstart, qend, hstart, hend, score, evalue, align_length, identical_matches, perc_ident, positive_matches, perc_pos, hit_rank, cigar_line) select qmember_id, hmember_id, qgenome_db_id, hgenome_db_id, analysis_id, qstart, qend, hstart, hend, score, evalue, align_length, identical_matches, perc_ident, positive_matches, perc_pos, hit_rank, cigar_line FROM $tbl_name";
    $sth2 = $self->dbc->prepare($sql2);
    print STDERR "Executing [", $sth2->sql, "].\n";
    $sth2->execute();

    $sql2 = "DROP TABLE $tbl_name";
    $sth2 = $self->dbc->prepare($sql2);
    print STDERR "Executing [", $sth2->sql, "].\n";
    $sth2->execute();

    $sql2 = "RENAME TABLE $temp_tbl_name TO $tbl_name";
    $sth2 = $self->dbc->prepare($sql2);
    print STDERR "Executing [", $sth2->sql, "].\n";
    $sth2->execute();
    #####

    $first_offset += $second_offset;
  }

  printf("  %1.3f secs to Update PAF Ids\n", (time()-$starttime));
}

1;
