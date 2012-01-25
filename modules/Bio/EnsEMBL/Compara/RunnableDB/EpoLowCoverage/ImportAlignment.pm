=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::ImportAlignment

=head1 SYNOPSIS

=head1 DESCRIPTION

This module imports a specified alignment. This is used in the low coverage genome alignment pipeline for importing the high coverage alignment which is used to build the low coverage genomes on.

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::ImportAlignment;

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


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
  $self->compara_dba->dbc->disconnect_when_inactive(0);

  my $reg = "Bio::EnsEMBL::Registry";
  $reg->load_registry_from_url($self->param('from_db_url'));
  
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

    #Quick and dirty import, assuming the 2 databases are on the same server. Useful for debugging
    if ($self->param('quick')) {
	$self->importAlignment_quick();
    } else {
	$self->importAlignment();
    }

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
    if ($self->param('from_db_url') =~ /mysql:\/\/.*@.*\/.+/) {
	$self->param('from_comparaDBA', new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$self->param('from_db_url')));
    } else {
	#open the most recent compara database
	$self->param('from_comparaDBA', Bio::EnsEMBL::Registry->get_DBAdaptor("Multi", "compara"));
    }
    my $analysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name("import_alignment");
    
    my $dbname = $self->param('from_comparaDBA')->dbc->dbname;
    my $analysis_id = $analysis->dbID;
    my $mlss_id = $self->param('method_link_species_set_id');

    ##Find min and max of the relevant internal IDs in the FROM database
    my $sth = $self->param('from_comparaDBA')->dbc->prepare("SELECT
        MIN(gab.genomic_align_block_id), MAX(gab.genomic_align_block_id),
        MIN(ga.genomic_align_id), MAX(ga.genomic_align_id),
        MIN(gat.node_id), MAX(gat.node_id),
        MIN(gat.root_id), MAX(gat.root_id)
      FROM genomic_align_block gab
        LEFT JOIN genomic_align ga using (genomic_align_block_id)
	LEFT JOIN genomic_align_tree gat ON gat.node_id = ga.node_id
      WHERE
        gab.method_link_species_set_id = ?");
    
    $sth->execute($mlss_id);
    my ($min_gab, $max_gab, $min_ga, $max_ga, $min_node_id, $max_node_id, 
	$min_root_id, $max_root_id) =
	  $sth->fetchrow_array();
    
    $sth->finish();

    #HACK to just copy over one chr (22) for testing purposes
    #my $dnafrag_id = 905407;
    my $dnafrag_id;

    #Copy the method_link_species_set
    copy_data($self->param('from_comparaDBA'), $self->compara_dba,
	      "method_link_species_set",
	      undef, undef, undef,
	      "SELECT * FROM method_link_species_set WHERE method_link_species_set_id = $mlss_id");

    #Copy the species_set
    copy_data($self->param('from_comparaDBA'), $self->compara_dba,
	      "species_set",
	      undef, undef, undef,
	      "SELECT species_set.* FROM species_set JOIN method_link_species_set USING (species_set_id) WHERE method_link_species_set_id = $mlss_id");

    #copy genomic_align_block table
    if ($dnafrag_id) {
	copy_data($self->param('from_comparaDBA'), $self->compara_dba,
		  "genomic_align_block",
		  "genomic_align_block_id",
		  $min_gab, $max_gab,
		  "SELECT gab.* FROM genomic_align_block gab LEFT JOIN genomic_align ga USING (genomic_align_block_id) WHERE ga.method_link_species_set_id = $mlss_id AND dnafrag_id=$dnafrag_id");
    } else {
	copy_data($self->param('from_comparaDBA'), $self->compara_dba,
		  "genomic_align_block",
		  "genomic_align_block_id",
		  $min_gab, $max_gab,
		  "SELECT * FROM genomic_align_block WHERE method_link_species_set_id = $mlss_id");
    }

    #copy genomic_align table
    if ($dnafrag_id) {
	copy_data($self->param('from_comparaDBA'), $self->compara_dba,
		  "genomic_align",
		  "genomic_align_id",
		  $min_ga, $max_ga,
		  "SELECT ga.*".
		  " FROM genomic_align ga ".
		  " WHERE method_link_species_set_id = $mlss_id AND dnafrag_id=$dnafrag_id");

    } else {
#	copy_data($self->{'from_comparaDBA'}, $self->{'comparaDBA'},
#		  "genomic_align",
#		  "genomic_align_id",
#		  $min_ga, $max_ga,
#		  "SELECT *".
#		  " FROM genomic_align".
#		  " WHERE method_link_species_set_id = $mlss_id");

	#Don't copy over ancestral genomic_aligns 
	copy_data($self->param('from_comparaDBA'), $self->compara_dba,
		  "genomic_align",
		  "genomic_align_id",
		  $min_ga, $max_ga,
		  "SELECT genomic_align.*".
		  " FROM genomic_align JOIN dnafrag USING (dnafrag_id)".
		  " WHERE method_link_species_set_id = $mlss_id AND genome_db_id != 63");
    }
    #copy genomic_align_tree table
    if ($dnafrag_id) {
	copy_data($self->param('from_comparaDBA'), $self->compara_dba,
		  "genomic_align_tree",
		  "root_id",
		  $min_root_id, $max_root_id,
		  "SELECT gat.*".
		  " FROM genomic_align_tree gat LEFT JOIN genomic_align_group USING (node_id)".
		  " LEFT JOIN genomic_align USING (genomic_align_id)".
		  " WHERE node_id IS NOT NULL AND method_link_species_set_id = $mlss_id AND dnafrag_id=$dnafrag_id");

    } else {
	copy_data($self->param('from_comparaDBA'), $self->compara_dba,
		  "genomic_align_tree",
		  "root_id",
		  $min_root_id, $max_root_id,
		  "SELECT gat.*".
		  " FROM genomic_align ga".
		  " JOIN dnafrag USING (dnafrag_id)".
		  " LEFT JOIN genomic_align_group gag USING (genomic_align_id)".
		  " LEFT JOIN genomic_align_tree gat USING (node_id) WHERE gag.node_id IS NOT NULL AND ga.method_link_species_set_id = $mlss_id AND genome_db_id != 63");
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
  my ($from_dba, $to_dba, $table_name, $index_name, $min_id, $max_id, $query) = @_;

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
  #speed up writing of data by disabling keys, write the data, then enable 
  $to_dba->dbc->do("ALTER TABLE `$table_name` DISABLE KEYS");
  if ($binary_mode) {
    #copy_data_in_binary_mode($from_dba, $to_dba, $table_name, $query);
  } else {
    copy_data_in_text_mode($from_dba, $to_dba, $table_name, $index_name, $min_id, $max_id, $query);
  }
  $to_dba->dbc->do("ALTER TABLE `$table_name` ENABLE KEYS");
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
  my ($from_dba, $to_dba, $table_name, $index_name, $min_id, $max_id, $query) = @_;

  my $user = $to_dba->dbc->username;
  my $pass = $to_dba->dbc->password;
  my $host = $to_dba->dbc->host;
  my $port = $to_dba->dbc->port;
  my $dbname = $to_dba->dbc->dbname;
  my $use_limit = 0;
  my $start = $min_id;
#  my $step = 100000;
  my $step = 10000;

  #If not using BETWEEN, revert back to LIMIT
  if (!defined $index_name && !defined $min_id && !defined $max_id) {
      $use_limit = 1;
      $start = 0;
  }

  while (1) {
    my $end = $start + $step - 1;
    my $sth;
    
    if (!$use_limit) {
	$sth = $from_dba->dbc->prepare($query." AND $index_name BETWEEN $start AND $end");
    } else {
	$sth = $from_dba->dbc->prepare($query." LIMIT $start, $step");
    }
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
	unless (system("mysqlimport", "-u$user", "-p$pass", "-h$host", "-P$port", "-L", "-l", "-i", $dbname, $filename) == 0) {
	    throw("Failed mysqlimport -u$user -p$pass -h$host -P$port -L -l -i $dbname $filename");
	}
    } else {
	unless (system("mysqlimport", "-u$user", "-h$host", "-P$port", "-L", "-l", "-i", $dbname, $filename) ==0) {
	    throw("Failed mysqlimport -u$user -h$host -P$port -L -l -i $dbname $filename");
	}
    }
    unlink("$filename");
  }
}

#Assumes the from and to databases are on the same server and downloads all entries from genomic_align_block, genomic_align,
#genomic_align_group and genomic_align_tree
sub importAlignment_quick {
    my $self = shift;

    #if the database name is defined in the url, then open that
    if ($self->param('from_db_url') =~ /mysql:\/\/.*@.*\/.+/) {
	$self->param('from_comparaDBA', new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$self->param('from_db_url')));
    } else {
	#open the most recent compara database
	$self->param('from_comparaDBA', Bio::EnsEMBL::Registry->get_DBAdaptor("Multi", "compara"));
    }
    my $analysis = $self->db->get_AnalysisAdaptor->fetch_by_logic_name("import_alignment");
    
    my $dbname = $self->param('from_comparaDBA')->dbc->dbname;
    my $analysis_id = $analysis->dbID;
    my $mlss_id = $self->param('method_link_species_set_id');

    #my $sql = "INSERT INTO genomic_align_block SELECT * FROM ?.genomic_align_block WHERE method_link_species_set_id = ?\n";
    my $sql = "INSERT INTO genomic_align_block SELECT * FROM $dbname.genomic_align_block\n";

    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();
    #$sth->execute($dbname, $mlss_id);
    $sth->finish();

     #$sql = "INSERT INTO genomic_align SELECT genomic_align.* FROM ?.genomic_align LEFT JOIN WHERE method_link_species_set_id = ?\n";
    $sql = "INSERT INTO genomic_align SELECT * FROM $dbname.genomic_align\n";
    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute();
    #$sth->execute($dbname, $mlss_id);
    $sth->finish();

    #$sql = "INSERT INTO genomic_align_tree SELECT genomic_align_tree.* FROM ?.genomic_align_tree LEFT JOIN ?.genomic_align_group USING (node_id) LEFT JOIN ?.genomic_align USING (genomic_align_id) LEFT JOIN ?.genomic_align_block WHERE genomic_align_block.method_link_species_set_id = ?\n";
    $sql = "INSERT INTO genomic_align_tree SELECT * FROM $dbname.genomic_align_tree\n";
    my $sth = $self->compara_dba->dbc->prepare($sql);

    #$sth->execute($dbname, $dbname, $dbname, $dbname, $mlss_id);
    $sth->execute();
    $sth->finish();

}

1;
