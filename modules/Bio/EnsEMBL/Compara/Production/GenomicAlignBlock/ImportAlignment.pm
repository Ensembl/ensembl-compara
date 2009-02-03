#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::ImportAlignment

=head1 SYNOPSIS


=head1 DESCRIPTION

This module imports a specified alignment. This is used in the low coverage genome alignment pipeline for importing the high coverage alignment which is used to build the low coverage genomes on.

=head1 PARAMETERS

=head1 CONTACT

Post questions to the Ensembl development list: ensembl-dev@ebi.ac.uk


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::ImportAlignment;

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use Bio::EnsEMBL::Hive::Process;

our @ISA = qw(Bio::EnsEMBL::Hive::Process);


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for gerp from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with $self->db (Hive DBAdaptor)
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

   $self->{'hiveDBA'} = Bio::EnsEMBL::Hive::DBSQL::DBAdaptor->new(-DBCONN => $self->{'comparaDBA'}->dbc);

  #read from analysis table
  $self->get_params($self->parameters); 

  #read from analysis_job table
  $self->get_params($self->input_id);

  my $reg = "Bio::EnsEMBL::Registry";
  $reg->load_registry_from_url($self->from_db_url);
  
}

=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   Run gerp
    Returns :   none
    Args    :   none

=cut

sub run {
    my $self = shift;
    $self->importAlignment();
    

}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   Write results to the database
    Returns :   1
    Args    :   none

=cut

sub write_output {
    my ($self) = @_;

    return 1;
}

#Uses copy_data method from copy_data.pl script
sub importAlignment {
    my $self = shift;

    #if the database name is defined in the url, then open that
    if ($self->from_db_url =~ /mysql:\/\/.*@.*\/.+/) {
	$self->{'from_comparaDBA'} = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$self->from_db_url);
    } else {
	#open the most recent compara database
	$self->{'from_comparaDBA'} = Bio::EnsEMBL::Registry->get_DBAdaptor("Multi", "compara");
    }
    my $analysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name("ImportAlignment");
    
    my $dbname = $self->{'from_comparaDBA'}->dbc->dbname;
    my $analysis_id = $analysis->dbID;
    my $mlss_id = $self->method_link_species_set_id;

    
    #copy genomic_align_block table
    copy_data($self->{'from_comparaDBA'}, $self->{'comparaDBA'},
       "genomic_align_block",
       "SELECT * FROM genomic_align_block WHERE method_link_species_set_id = $mlss_id");

    my $do_all = 1; 
    if ($do_all) {
    #copy genomic_align table
    copy_data($self->{'from_comparaDBA'}, $self->{'comparaDBA'},
		"genomic_align",
		"SELECT ga.*".
		" FROM genomic_align_block gab LEFT JOIN genomic_align ga USING (genomic_align_block_id)".
		" WHERE gab.method_link_species_set_id = $mlss_id");

    #copy genomic_align_group table
    copy_data($self->{'from_comparaDBA'}, $self->{'comparaDBA'},
	      "genomic_align_group",
	      "SELECT gag.*".
	      " FROM genomic_align_block gab LEFT JOIN genomic_align ga USING (genomic_align_block_id)".
	      " LEFT JOIN genomic_align_group gag USING (genomic_align_id)".
	      " WHERE gag.group_id IS NOT NULL AND gab.method_link_species_set_id = $mlss_id");

    #copy genomic_align_tree table
    copy_data($self->{'from_comparaDBA'}, $self->{'comparaDBA'},
	      "genomic_align_tree",
	      "SELECT gat.*".
	      " FROM genomic_align_block gab LEFT JOIN genomic_align ga USING (genomic_align_block_id)".
	      " LEFT JOIN genomic_align_group gag USING (genomic_align_id)".
	      " LEFT JOIN genomic_align_tree gat ON (node_id=gag.group_id) WHERE gag.group_id IS NOT NULL AND gab.method_link_species_set_id = $mlss_id");
}
}


=head2 copy_data

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba
  Arg[3]      : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $this_mlss
  Arg[4]      : string $table
  Arg[5]      : string $sql_query

  Description : copy data in this table using this SQL query.
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_data {
  my ($from_dba, $to_dba, $table_name, $query) = @_;

  print "Copying data in table $table_name\n";

  my $sth = $from_dba->dbc->db_handle->column_info($from_dba->dbc->dbname, undef, $table_name, '%');
  $sth->execute;
  my $all_rows = $sth->fetchall_arrayref;
  my $binary_mode = 0;
  foreach my $this_col (@$all_rows) {
    if (($this_col->[5] eq "BINARY") or ($this_col->[5] eq "VARBINARY") or
        ($this_col->[5] eq "BLOB") or ($this_col->[5] eq "BIT")) {
      $binary_mode = 1;
      last;
    }
  }
  if ($binary_mode) {
    #copy_data_in_binary_mode($from_dba, $to_dba, $table_name, $query);
  } else {
    copy_data_in_text_mode($from_dba, $to_dba, $table_name, $query);
  }
}


=head2 copy_data_in_text_mode

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba
  Arg[3]      : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $this_mlss
  Arg[4]      : string $table
  Arg[5]      : string $sql_query

  Description : copy data in this table using this SQL query.
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_data_in_text_mode {
  my ($from_dba, $to_dba, $table_name, $query) = @_;

  my $user = $to_dba->dbc->username;
  my $pass = $to_dba->dbc->password;
  my $host = $to_dba->dbc->host;
  my $port = $to_dba->dbc->port;
  my $dbname = $to_dba->dbc->dbname;

  my $start = 0;
  #my $step = 1000000;
  my $step = 10000;

  while (1) {
    my $sth = $from_dba->dbc->prepare($query." LIMIT $start, $step");
    $start += $step;
    $sth->execute();
    my $all_rows = $sth->fetchall_arrayref;
    ## EXIT CONDITION
    return if (!@$all_rows);
  
    my $filename = "/tmp/$table_name.copy_data.$$.txt";
    open(TEMP, ">$filename") or die;
    foreach my $this_row (@$all_rows) {
      print TEMP join("\t", map {defined($_)?$_:'\N'} @$this_row), "\n";
    }
    close(TEMP);
    if ($pass) {
      system("mysqlimport", "-u$user", "-p$pass", "-h$host", "-P$port", "-L", "-l", "-i", $dbname, $filename);
    } else {
      system("mysqlimport", "-u$user", "-h$host", "-P$port", "-L", "-l", "-i", $dbname, $filename);
    }
    unlink("$filename");
  }

}

#this assumes the from and to databases are on the same server.
sub importAlignment_old {
    my $self = shift;

    #if the database name is defined in the url, then open that
    if ($self->from_db_url =~ /mysql:\/\/.*@.*\/.+/) {
	$self->{'from_comparaDBA'} = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$self->from_db_url);
    } else {
	#open the most recent compara database
	$self->{'from_comparaDBA'} = Bio::EnsEMBL::Registry->get_DBAdaptor("Multi", "compara");
    }
    my $analysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name("ImportAlignment");
    
    my $dbname = $self->{'from_comparaDBA'}->dbc->dbname;
    my $analysis_id = $analysis->dbID;
    my $mlss_id = $self->method_link_species_set_id;

    my $sql = "INSERT INTO genomic_align_block SELECT * FROM ?.genomic_align_block WHERE method_link_species_set_id = ?\n";

    my $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
    $sth->execute($dbname, $mlss_id);
    $sth->finish();

     $sql = "INSERT INTO genomic_align SELECT genomic_align.* FROM ?.genomic_align LEFT JOIN WHERE method_link_species_set_id = ?\n";
    my $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
    $sth->execute($dbname, $mlss_id);
    $sth->finish();

    $sql = "INSERT INTO genomic_align_group SELECT genomic_align_group.* FROM ?.genomic_align_group LEFT JOIN ?.genomic_align USING (genomic_align_id) LEFT JOIN ?.genomic_align_block USING (genomic_align_block_id) WHERE genomic_align_block.method_link_species_set_id = ?\n";
    my $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
    $sth->execute($dbname, $dbname, $mlss_id);
    $sth->finish();

    $sql = "INSERT INTO genomic_align_tree SELECT genomic_align_tree.* FROM ?.genomic_align_tree LEFT JOIN ?.genomic_align_group ON (node_id=group_id) LEFT JOIN ?.genomic_align USING (genomic_align_id) LEFT JOIN ?.genomic_align_block WHERE genomic_align_block.method_link_species_set_id = ?\n";
    my $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
    $sth->execute($dbname, $dbname, $dbname, $dbname, $mlss_id);
    $sth->finish();

}

##########################################
#
# getter/setter methods
# 
##########################################

sub method_link_species_set_id {
  my $self = shift;
  $self->{'_method_link_species_set_id'} = shift if(@_);
  return $self->{'_method_link_species_set_id'};
}

sub from_db_url {
  my $self = shift;
  $self->{'_from_db_url'} = shift if(@_);
  return $self->{'_from_db_url'};
}

##########################################
#
# internal methods
#
##########################################

sub get_params {
  my $self         = shift;
  my $param_string = shift;

  return unless($param_string);
  print("parsing parameter string : ",$param_string,"\n");

  my $params = eval($param_string);
  return unless($params);

  if(defined($params->{'method_link_species_set_id'})) {
    $self->method_link_species_set_id($params->{'method_link_species_set_id'});
  }
  if (defined($params->{'from_db_url'})) {
      $self->from_db_url($params->{'from_db_url'});
  }
  return 1;
}
