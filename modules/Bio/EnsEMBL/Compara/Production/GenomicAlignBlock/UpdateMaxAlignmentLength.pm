#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::FilterDuplicates

=cut

=head1 SYNOPSIS

my $db       = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $runnable = Bio::EnsEMBL::Pipeline::RunnableDB::FilterDuplicates->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$runnable->fetch_input(); #reads from DB
$runnable->run();
$runnable->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This analysis/RunnableDB is designed to run after all GenomicAlignBlock entries for a 
specific MethodLinkSpeciesSet has been completed and filters out all duplicate entries
which can result from jobs being rerun or from regions of overlapping chunks generating
the same HSP hits.  It takes as input (on the input_id string) 

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::UpdateMaxAlignmentLength;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   prepares global variables and DB connections
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #
  # parameters which can be set either via
  # $self->parameters OR
  # $self->input_id
  #
  $self->debug(0);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN => $self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  $self->get_params($self->parameters);
  $self->get_params($self->input_id);

  return 1;
}


sub run
{
  my $self = shift;
  $self->remove_alignment_data_inconsistencies;
  $self->update_meta_table;
  return 1;
}


sub write_output 
{
  my $self = shift;
  return 1;
}

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  return if ($param_string eq "1");

  my $params = eval($param_string);
  return unless($params);

  foreach my $key (keys %$params) {
    print("  $key : ", $params->{$key}, "\n");
  }

  # from input_id
  $self->{'query_genome_db_id'} = $params->{'query_genome_db_id'} if(defined($params->{'query_genome_db_id'}));
  $self->{'target_genome_db_id'} = $params->{'target_genome_db_id'} if(defined($params->{'target_genome_db_id'}));
  # from parameters
  $self->{'method_link'} = $params->{'method_link'} if(defined($params->{'method_link'}));
  # get the mlss object;

  if (defined $self->{'method_link'} && defined $self->{'query_genome_db_id'} && $self->{'target_genome_db_id'}) {
    my $mlssa = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlssa->fetch_by_method_link_type_genome_db_ids($self->{'method_link'}, [$self->{'query_genome_db_id'},$self->{'target_genome_db_id'}]);
    
    $self->{'mlss'} = $mlss if (defined $mlss);
  }

  return 1;
}


######################################
#
# subroutines
#
#####################################

sub update_meta_table {
  my $self = shift;

  my $dba = $self->{'comparaDBA'};
  my $mc = $dba->get_MetaContainer;

  $dba->dbc->do("analyze table genomic_align_block");
  $dba->dbc->do("analyze table genomic_align");
  $dba->dbc->do("analyze table genomic_align_group");

  my $sth = $dba->dbc->prepare("SELECT method_link_species_set_id,max(dnafrag_end - dnafrag_start + 1) FROM genomic_align group by method_link_species_set_id");
  $sth->execute();
  my $max_alignment_length = 0;
  my ($method_link_species_set_id,$max_align);
  $sth->bind_columns(\$method_link_species_set_id,\$max_align);

  while ($sth->fetch()) {
    my $key = "max_align_".$method_link_species_set_id;
    $mc->delete_key($key);
    $mc->store_key_value($key, $max_align + 1);
    $max_alignment_length = $max_align if ($max_align > $max_alignment_length);
    print STDERR "Stored key:$key value:",$max_align + 1," in meta table\n";
  }
  $mc->delete_key("max_alignment_length");
  $mc->store_key_value("max_alignment_length", $max_alignment_length + 1);
  print STDERR "Stored key:max_alignment_length value:",$max_alignment_length + 1," in meta table\n";

  $sth->finish;

}

sub remove_alignment_data_inconsistencies {
  my $self = shift;

  my $dba = $self->{'comparaDBA'};

  $dba->dbc->do("analyze table genomic_align_block");
  $dba->dbc->do("analyze table genomic_align");
  $dba->dbc->do("analyze table genomic_align_group");

  #Delete genomic align blocks which have no genomic aligns. Assume not many of these
  #

  my $sql_gab = "delete from genomic_align_block where genomic_align_block_id in ";
  my $sql_ga = "delete from genomic_align where genomic_align_id in ";
  my $sql_gag = "delete from genomic_align_group where genomic_align_id in ";

  my $sql = "SELECT gab.genomic_align_block_id FROM genomic_align_block gab LEFT JOIN genomic_align  ga ON gab.genomic_align_block_id=ga.genomic_align_block_id WHERE ga.genomic_align_block_id IS NULL;";
  my $sth = $dba->dbc->prepare($sql);
  $sth->execute();

  my @gab_ids;
  while (my $aref = $sth->fetchrow_arrayref) {
    my ($gab_id) = @$aref;
    push @gab_ids, $gab_id;
  }
  $sth->finish;

  #check if any results found
  if (scalar @gab_ids) {
    my $sql_gab_to_exec = $sql_gab . "(" . join(",", @gab_ids) . ");";
    my $sth = $dba->dbc->prepare($sql_gab_to_exec);
    $sth->execute;
    $sth->finish;
  }

  #
  #Delete genomic align blocks which have 1 genomic align. Assume not many of these
  #
  
  $sql = "SELECT genomic_align_block_id, genomic_align_id FROM genomic_align GROUP BY genomic_align_block_id HAVING count(*)<2;";
  $sth = $dba->dbc->prepare($sql);
  $sth->execute;

  @gab_ids = ();
  my @ga_ids;
  while (my $aref = $sth->fetchrow_arrayref) {
    my ($gab_id, $ga_id) = @$aref;
    push @gab_ids, $gab_id;
    push @ga_ids, $ga_id;
  }
  $sth->finish;

  if (scalar @gab_ids) {
    my $sql_gab_to_exec = $sql_gab . "(" . join(",", @gab_ids) . ")";
    my $sql_ga_to_exec = $sql_ga . "(" . join(",", @ga_ids) . ")";
    my $sql_gag_to_exec = $sql_gag . "(" . join(",", @ga_ids) . ")";

    foreach my $sql ($sql_gab_to_exec,$sql_ga_to_exec,$sql_gag_to_exec) {
      my $sth = $dba->dbc->prepare($sql);
      $sth->execute;
      $sth->finish;
    }
  }
  if (defined $self->{'mlss'}) {

    #
    # Delete genomic aligns that have no genomic align group. Assume not many of these
    #

    $sql = "SELECT DISTINCT ga.genomic_align_block_id FROM genomic_align ga LEFT JOIN genomic_align_group  gag ON ga.genomic_align_id=gag.genomic_align_id WHERE gag.genomic_align_id IS NULL and method_link_species_set_id=?;";

    $sth = $dba->dbc->prepare($sql);
    $sth->execute($self->{'mlss'}->dbID);
    @gab_ids = ();
    @ga_ids = ();
    while (my $aref = $sth->fetchrow_arrayref) {
      my ($gab_id) = @$aref;
      push @gab_ids, $gab_id;
    }
    $sth->finish;
    
    for (my $i=0; $i < scalar @gab_ids; $i++) {
      $sql = "select genomic_align_id from genomic_align where genomic_align_block_id = ?;";
      
      $sth = $dba->dbc->prepare($sql);
      $sth->execute($gab_ids[$i]);
      
      while (my $aref = $sth->fetchrow_arrayref) {
        my ($ga_id) = @$aref;
        
        #Need to leave this to print in case things go wrong and I need to recover.
#        print STDOUT "$ga_id\n";
        push @ga_ids, $ga_id;
      }
    }
    
    if (scalar @gab_ids) {
      for (my $i=0; $i < scalar @gab_ids; $i=$i+20000) {
        my (@gab_ids_to_delete);
        for (my $j = $i; ($j < scalar @gab_ids && $j < $i+20000); $j++) {
          push @gab_ids_to_delete, $gab_ids[$j];
        }
        my $sql_gab_to_exec = $sql_gab . "(" . join(",", @gab_ids_to_delete) . ");";
        my $sth = $dba->dbc->prepare($sql_gab_to_exec);
        $sth->execute;
        $sth->finish;
      }
    }
    if (scalar @ga_ids) {
      for (my $i=0; $i < scalar @ga_ids; $i=$i+20000) {
        my (@ga_ids_to_delete);
        for (my $j = $i; ($j < scalar @ga_ids && $j < $i+20000); $j++) {
          push @ga_ids_to_delete, $ga_ids[$j];
        }
        my $sql_ga_to_exec = $sql_ga . "(" . join(",", @ga_ids_to_delete) . ");";
        my $sql_gag_to_exec = $sql_gag . "(" . join(",", @ga_ids_to_delete) . ");";
        
        foreach my $sql ($sql_ga_to_exec,$sql_gag_to_exec) {
          my $sth = $dba->dbc->prepare($sql);
          $sth->execute;
          $sth->finish;
        }
      }
    }
  }
}


1;
