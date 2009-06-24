#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairwiseSynteny

=cut

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $pairwisesynteny = Bio::EnsEMBL::Compara::RunnableDB::PairwiseSynteny->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$pairwisesynteny->fetch_input(); #reads from DB
$pairwisesynteny->run();
$pairwisesynteny->output();
$pairwisesynteny->write_output(); #writes to DB

=cut


=head1 DESCRIPTION

This Analysis will take the sequences from a cluster, the cm from
nc_profile and run a profiled alignment, storing the results as
cigar_lines for each sequence.

=cut


=head1 CONTACT

  Contact Albert Vilella on module implementation/design detail: avilella@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::EnsEMBL::Compara::RunnableDB::PairwiseSynteny;

use strict;
use Getopt::Long;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Hive;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
  my( $self) = @_;

  $self->{'clusterset_id'} = 1;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new
    (
     -DBCONN=>$self->db->dbc
    );

  # Get the needed adaptors here
  $self->{gdba} = $self->{'comparaDBA'}->get_GenomeDBAdaptor;

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

# # For long parameters, look at analysis_data
#   if($self->{analysis_data_id}) {
#     my $analysis_data_id = $self->{analysis_data_id};
#     my $analysis_data_params = $self->db->get_AnalysisDataAdaptor->fetch_by_dbID($analysis_data_id);
#     $self->get_params($analysis_data_params);
#   }

  $self->fetch_pairwise_blasts;
  $self->fetch_coordinates;

  return 1;
}


sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n") if($self->debug);

  my $params = eval($param_string);
  return unless($params);

  if($self->debug) {
    foreach my $key (keys %$params) {
      print("  $key : ", $params->{$key}, "\n");
    }
  }

  foreach my $key (qw[param1 gdbs analysis_data_id]) {
    my $value = $params->{$key};
    $self->{$key} = $value if defined $value;
  }

  return;
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs something
    Returns :   none
    Args    :   none

=cut

sub run {
  my $self = shift;

  $self->run_pairwise_synteny;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores something
    Returns :   none
    Args    :   none

=cut


sub write_output {
  my $self = shift;

}


##########################################
#
# internal methods
#
##########################################

1;

sub run_pairwise_synteny {
  my $self = shift;

  return 1;
}

sub fetch_pairwise_blasts {
  my $self = shift;

  my @genome_dbs = @{$self->{gdbs}};
  my $genome_db1 = $self->{gdba}->fetch_by_dbID($genome_dbs[0]);
  my $genome_db2 = $self->{gdba}->fetch_by_dbID($genome_dbs[1]);

  my $tmp = $self->worker_temp_directory;
  unlink </tmp/*.blasts>;
  $self->fetch_cross_distances($genome_db1,$genome_db2,1);
  $self->fetch_cross_distances($genome_db2,$genome_db1,2);

  return 1;
}


sub fetch_cross_distances {
  my $self = shift;
  my $gdb = shift;
  my $gdb2 = shift;
  my $filename_prefix = shift;

  my $starttime = time();

  my $gdb_id = $gdb->dbID;
  my $species_name = lc($gdb->name);
  $species_name =~ s/\ /\_/g;
  my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";

  my $gdb_id2 = $gdb2->dbID;
  my $sql = "SELECT ".
            "concat(qmember_id,' ',hmember_id,' ',score) ".
            "FROM $tbl_name where hgenome_db_id=$gdb_id2";

  print("$sql\n");
  my $sth = $self->dbc->prepare($sql);

  $sth->execute();
  printf("%1.3f secs to execute\n", (time()-$starttime));
  print("  done with fetch\n");

  my $gdb_filename = $gdb_id if (1 == $filename_prefix);
  $gdb_filename = $gdb_id2 if (2 == $filename_prefix);
  my $filename = $self->worker_temp_directory . "$gdb_filename.blasts";
  # We append all blasts in one file
  open FILE, ">>$filename" or die $!;
  while ( my $row  = $sth->fetchrow ) {
    print FILE "$row\n";
  }
  $sth->finish;
  close FILE;
  printf("%1.3f secs to process\n", (time()-$starttime));

  return 1;
}

sub fetch_coordinates {
  my $self = shift;

  my $starttime = time();

  foreach my $genome_db_id (@{$self->{gdbs}}) {
    my $sql = "SELECT ".
              "concat(m2.member_id,' ',m1.chr_name,' ',m1.chr_start,' ',m1.chr_end,' ',if(m1.chr_strand=1,'-','+')) ".
              "FROM member m1, member m2, subset_member sm ".
              "WHERE m2.gene_member_id=m1.member_id and ".
              "m2.member_id=sm.member_id and ".
              "m1.source_name='ENSEMBLGENE' and ".
              "m1.genome_db_id=$genome_db_id";

    print("$sql\n");
    my $sth = $self->dbc->prepare($sql);

    $sth->execute();
    printf("%1.3f secs to execute\n", (time()-$starttime));
    print("  done with fetch\n");

    my $filename = $self->worker_temp_directory . "/" . "$genome_db_id.coordinates";
    # We append all blasts in one file
    open FILE, ">$filename" or die $!;
    while ( my $row  = $sth->fetchrow ) {
      print FILE "$row\n";
    }
    $sth->finish;
    close FILE;
    printf("%1.3f secs to process\n", (time()-$starttime));
  }
  $DB::single=1;1;
  return 1;
}
