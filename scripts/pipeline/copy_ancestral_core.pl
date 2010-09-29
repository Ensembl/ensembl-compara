#!/usr/bin/env perl

use warnings;
use strict;

my $description = q{
###########################################################################
##
## PROGRAM copy_ancestral_core.pl
##
## AUTHORS
##    Kathryn Beal (kbeal@ebi.ac.uk)
##
## COPYRIGHT
##    This script is part of the Ensembl project http://www.ensembl.org
##
## DESCRIPTION
##    This script copies ancestral data over core DBs. It has been
##    specifically developed to copy data from a production to a
##    release database.
##
###########################################################################

};

=head1 NAME

copy_data.pl

=head1 AUTHORS

 Kathryn Beal (kbeal@ebi.ac.uk)

=head1 COPYRIGHT

This script is part of the Ensembl project http://www.ensembl.org

=head1 DESCRIPTION

This script copies data over compara DBs. It has been
specifically developped to copy data from a production to a
release database.

This script does not store the homology/family data as these are completely
rebuild for each release. Only the relevant DNA-DNA alignments and syntenic
regions are copied from the old database.

=head1 SYNOPSIS

perl copy_data.pl --help

perl copy_data.pl
    [--reg-conf registry_configuration_file]
    --from production_database_name
    --to release_database_name
    --mlss method_link_species_set_id

perl copy_data.pl
    --from_url production_database_url
    --to_url release_database_url
    --mlss method_link_species_set_id

example:

bsub  -q yesterday -ooutput_file -Jcopy_data -R "select[mem>5000] rusage[mem=5000]" -M5000000 
copy_data.pl --from_url mysql://username@server_name/sf5_production 
--to_url mysql://username:password@server_name/sf5_release --mlss 340



=head1 REQUIREMENTS

This script uses mysql, mysqldump and mysqlimport programs.
It requires at least version 4.1.12 of mysqldump as it uses
the --insert-ignore option.

=head1 ARGUMENTS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 DATABASES using URLs

=over

=item B<--from_url mysql://user[:passwd]@host[:port]/dbname>

URL for the production compara database. Data will be copied from this instance.

=item B<--to_url mysql://user[:passwd]@host[:port]/dbname>

URL for the release compara database. Data will be copied to this instance.

=back

=head2 DATABASES using the Registry

=over

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=item B<--from from_compara_db_name>

The production compara database name as defined in the Registry or any valid alias.
Data will be copied from this instance.

=item B<--to to_compara_db_name>

The release compara database name as defined in the Registry or any valid alias.
Data will be copied to this instance.

=back

=head2 DATA

=over

=item B<--mlss method_link_species_set_id>

Copy data for this species only. This option can be used several times in order to restrict
the copy to several species.

=back

=head1 INTERNAL METHODS

=cut

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Getopt::Long;

my $help;

my $reg_conf;
my $from_name = undef;
my $to_name = undef;
my $from_url = undef;
my $to_url = undef;
my $mlss_id = undef;


GetOptions(
    "help" => \$help,
    "reg-conf|reg_conf|registry=s" => \$reg_conf,
    "from=s" => \$from_name,
    "to=s" => \$to_name,
    "from_url=s" => \$from_url,
    "to_url=s" => \$to_url,
    "mlss_id=i" => \$mlss_id,
  );

# Print Help and exit if help is requested
if ($help or (!$from_name and !$from_url) or (!$to_name and !$to_url) or !$mlss_id) {
  exec("/usr/bin/env perldoc $0");
}

Bio::EnsEMBL::Registry->load_all($reg_conf) if ($from_name or $to_name);
my $from_dba = get_DBAdaptor($from_url, $from_name);
my $to_dba = get_DBAdaptor($to_url, $to_name);

#Check have coord_system set
check_coord_system_table($to_dba);

copy_data($from_dba, $to_dba, $mlss_id);


=head2 get_DBAdaptor

  Arg[1]      : string $dburl
  Arg[2]      : string $registry_dbname
  Description : Uses either the $dburl or the $registry_dbname (and the
                $regsitry_file if needed) to get the DBAdaptor for this
                database. Test that the DB exists.
  Returns     : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor
  Exceptions  : throw if argument test fails

=cut

sub get_DBAdaptor {
  my ($url, $name) = @_;
  my $core_db_adaptor = undef;

  if ($url) {
    if ($url =~ /mysql\:\/\/([^\@]+\@)?([^\:\/]+)(\:\d+)?\/(.+)/) {
      my $user_pass = $1;
      my $host = $2;
      my $port = $3;
      my $dbname = $4;

      $user_pass =~ s/\@$//;
      my ($user, $pass) = $user_pass =~ m/([^\:]+)(\:.+)?/;
      $pass =~ s/^\:// if ($pass);
      $port =~ s/^\:// if ($port);

      $core_db_adaptor = new Bio::EnsEMBL::DBSQL::DBAdaptor(
          -host => $host,
          -user => $user,
          -pass => $pass,
          -port => $port,
          -group => "core",
          -dbname => $dbname,
          -species => "ancestral_sequence",
        );
    } else {
      warn("Cannot undestand URL: $url\n");
    }
  } elsif ($name) {
    $core_db_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($name, "core");
  }

  if (!$core_db_adaptor->get_MetaContainer) {
    return undef;
  }

  return $core_db_adaptor;
}

sub check_coord_system_table {
    my ($dba) = @_;
    my $coord_system_name = "ancestralsegment";

    my $coord_system_adpator = $dba->get_CoordSystemAdaptor;
    my $coord_system = $coord_system_adpator->fetch_by_name($coord_system_name);

    if (!defined $coord_system) {
	print "No $coord_system_name coord system defined. Adding one\n";
	my $this_coord_system = Bio::EnsEMBL::CoordSystem->new(
				       -NAME    => $coord_system_name,
				       -RANK    => 1);
	$coord_system_adpator->store($this_coord_system);
    }
}

sub copy_data {
    my ($from_dba, $to_dba, $mlss_id) = @_;
    my $coord_system_name = "ancestralsegment";

    #
    #Check from_dba has correct structure. 
    #
    my $name = "Ancestor_" . $mlss_id;

    my $name_sql = "SELECT count(*) FROM seq_region WHERE name LIKE '$name" . "_%'";
    my $sth = $from_dba->dbc->prepare($name_sql);
    $sth->execute();
    my ($num_sr) = $sth->fetchrow_array();
    $sth->finish;

    if ($num_sr == 0) {
	throw("Invalid seq_region name. Should be of the form: $name" . "_%");
    }
    
    #
    #Check coord_system_id the same in from_db and to_db
    #
    my $cs_sql = "SELECT coord_system_id FROM coord_system WHERE name = '$coord_system_name'";
    $sth = $to_dba->dbc->prepare($cs_sql);
    $sth->execute();
    my ($coord_system_id) = $sth->fetchrow_array();
    $sth->finish;
    #print "cs $coord_system_id\n";

    $cs_sql = "SELECT count(*) FROM seq_region WHERE coord_system_id = $coord_system_id";
    $sth = $from_dba->dbc->prepare($cs_sql);
    $sth->execute();
    my ($num_cs) = $sth->fetchrow_array();
    $sth->finish;

    if ($num_cs == 0) {
	throw("coord_system_id $coord_system_id does not exist in the production database. This needs to be fixed.");
    }
    
    #Check no clashes in to_db
    $sth = $to_dba->dbc->prepare($name_sql);
    $sth->execute();
    my ($num_to_sr) = $sth->fetchrow_array();
    $sth->finish;

    if ($num_to_sr != 0) {
	throw("Already have names of $name in the production database. This needs to be fixed");

    }

    #
    #Find min and max seq_region_id
    #
    my $range_sql = "SELECT min(seq_region_id), max(seq_region_id) FROM seq_region WHERE name LIKE '$name" . "_%'";

    $sth = $from_dba->dbc->prepare($range_sql);
    $sth->execute();
    my ($min_sr, $max_sr) = $sth->fetchrow_array();
    $sth->finish;

    #
    #Create correct number of spaceholder rows in seq_region table in to_db 
    #
    my $query = "SELECT 0, name, coord_system_id, length FROM seq_region ss WHERE name like '$name" . "_%'";
    copy_data_in_text_mode($from_dba, $to_dba, "seq_region", "seq_region_id", $min_sr, $max_sr, $query);

    #
    #Find min and max of new seq_region_ids
    #
    $sth = $to_dba->dbc->prepare($range_sql);
    $sth->execute();
    my ($new_min_sr, $new_max_sr) = $sth->fetchrow_array();
    $sth->finish;

    #
    #Create temporary table in from_db to store mappings
    #
    $sth = $from_dba->dbc->prepare("CREATE TABLE tmp_seq_region_mapping (seq_region_id INT(10) UNSIGNED NOT NULL,new_seq_region_id INT(10) UNSIGNED NOT NULL,  KEY seq_region_idx (seq_region_id))");

    $sth->execute();
    $sth->finish;

    #
    #Create mappings
    #
    my $values="";
    my $new_seq_region_id = $new_min_sr;
    for (my $i = $min_sr; $i <= $max_sr; $i++) {
	$values .= "($i, $new_seq_region_id),";
	$new_seq_region_id++;
    }

    #remove final comma
    chop $values;
    #print "values $values\n";
    $sth = $from_dba->dbc->prepare("INSERT INTO tmp_seq_region_mapping \(seq_region_id, new_seq_region_id\) VALUES $values");
    $sth->execute();
    $sth->finish;

    #
    #Copy over the seq_region with new seq_region_ids
    #
    $query = "SELECT new_seq_region_id, name, coord_system_id,length FROM seq_region LEFT JOIN tmp_seq_region_mapping USING (seq_region_id) WHERE name like '$name" . "_%'";

    print "copying seq_region in replace mode\n";
    copy_data_in_text_mode($from_dba, $to_dba, "seq_region", "seq_region_id", $min_sr, $max_sr, $query, undef, 1);

    #
    #Copy over the dna with new seq_region_ids
    #
    $query = "SELECT new_seq_region_id, sequence FROM tmp_seq_region_mapping JOIN dna USING (seq_region_id) WHERE seq_region_id > 0";

    print "copying dna\n";
    copy_data_in_text_mode($from_dba, $to_dba, "dna", "seq_region_id", $min_sr, $max_sr, $query, 1000);

    #
    #Drop temporary table
    #
    $sth = $from_dba->dbc->prepare("DROP TABLE tmp_seq_region_mapping");
    $sth->execute();
    $sth->finish;

}

sub copy_data_in_text_mode {
  my ($from_dba, $to_dba, $table_name, $index_name, $min_id, $max_id,$query, $step,$replace) = @_;
   print "start copy_data_in_text_mode\n";

  my $user = $to_dba->dbc->username;
  my $pass = $to_dba->dbc->password;
  my $host = $to_dba->dbc->host;
  my $port = $to_dba->dbc->port;
  my $dbname = $to_dba->dbc->dbname;
  my $use_limit = 0;
  my $start = $min_id;

  #If not using BETWEEN, revert back to LIMIT
  if (!defined $index_name && !defined $min_id && !defined $max_id) {
      $use_limit = 1;
      $start = 0;
  }

  #constrained elements need smaller step than default
  if (!defined $step) {
      $step = 100000;
  }
  while (1) {
    my $start_time = time();
    my $end = $start + $step - 1;
    my $sth;
    #print "start $start end $end\n";
    #print "query $query\n";
    if (!$use_limit) {
	$sth = $from_dba->dbc->prepare($query." AND $index_name BETWEEN $start AND $end");
    } else {
	$sth = $from_dba->dbc->prepare($query." LIMIT $start, $step");
    }
    $start += $step;
    $sth->execute();
    my $all_rows = $sth->fetchall_arrayref;
    $sth->finish;
    ## EXIT CONDITION
    return if (!@$all_rows);
    my $time=time(); 
    my $filename = "/tmp/$table_name.copy_data.$$.$time.txt";
    #print "filename $filename\n";
    open(TEMP, ">$filename") or die "could not open the file '$filename' for writing";
    foreach my $this_row (@$all_rows) {
      print TEMP join("\t", map {defined($_)?$_:'\N'} @$this_row), "\n";
    }
    close(TEMP);
    #print "time " . ($start-$min_id) . " " . (time - $start_time) . "\n";

    if (defined $replace && $replace) {
	#print "replace mode\n";
	system("mysqlimport -h$host -P$port -u$user ".($pass ? "-p$pass" : '')." -L -l -r $dbname $filename");
    } else {
	#print "ignore mode\n";
	system("mysqlimport -h$host -P$port -u$user ".($pass ? "-p$pass" : '')." -L -l -i $dbname $filename");
    }
    unlink("$filename");
    #print "total time " . ($start-$min_id) . " " . (time - $start_time) . "\n";
  }
}
