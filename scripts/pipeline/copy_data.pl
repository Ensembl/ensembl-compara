#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use warnings;
use strict;

my $description = q{
###########################################################################
##
## PROGRAM copy_data.pl
##
## AUTHORS
##    Javier Herrero
##
## DESCRIPTION
##    This script copies data over compara DBs. It has been
##    specifically developped to copy data from a production to a
##    release database.
##
###########################################################################

};

=head1 NAME

copy_data.pl

=head1 AUTHORS

 Javier Herrero

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

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
    [--reg_conf registry_configuration_file]
    --from_reg_name production_database_name
    --to_reg_name release_database_name
    --mlss_id method_link_species_set_id1 --mlss_id method_link_species_set_id2 --mlss_id method_link_species_set_id3

perl copy_data.pl
    --from_url production_database_url
    --to_url release_database_url
    --method_link_type LASTZ_NET --method_link_type BLASTZ_NET

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

Copy data for this mlss only. This option can be used several times in order to restrict
the copy to several mlss.

=item B<[--merge boolean]>

If true, add new data to an existing data set in the release database. Default FALSE. 

=back

=head1 INTERNAL METHODS

=cut

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:table_copy);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);
use Getopt::Long;

$| = 1;

my $help;

my $reg_conf;
my $from_reg_name = undef;
my $from_url = undef;
my $to_reg_name = undef;
my $to_url = undef;
my @method_link_types = ();
my @mlss_id = ();

    # Re-enable or not indices on tables after copying the data.
    # Re-enabling takes a lot of time and can be skipped if followed
    # by another execution of copy_data scipt that will disable them first anyway.
my $re_enable = 1;

my $disable_keys;

#If true, then trust the TO database tables and update the FROM tables if 
#necessary. Currently only applies to differences in the dnafrag table and 
#will only update the genomic_align table.
my $trust_to = 0; 

#If true, assume that the range of ce_ids does not need to be shifted.
my $trust_ce = 0;

#If true, then add new data to existing set of alignments
my $merge = 0;

my $dry_run = 0;    # if set, will stop just before any data has been copied

GetOptions(
           'help'                           => \$help,
           'reg_conf|reg-conf|registry=s'   => \$reg_conf,
           'from_reg_name=s'                => \$from_reg_name,
           'to_reg_name=s'                  => \$to_reg_name,
           'from_url=s'                     => \$from_url,
           'to_url=s'                       => \$to_url,

           'method_link_type=s@'            => \@method_link_types,
           'mlss_id=i@'                     => \@mlss_id,
           'disable_keys=i'                 => \$disable_keys,
           're_enable=i'                    => \$re_enable,
           'dry_run|dry-run!'               => \$dry_run,

           'trust_to!'                      => \$trust_to,
           'trust_ce!'                      => \$trust_ce,
           'merge!'                         => \$merge,
);

# Print Help and exit if help is requested
if ($help or (!$from_reg_name and !$from_url) or (!$to_reg_name and !$to_url) or (!scalar(@mlss_id) and !scalar(@method_link_types) ) ) {
  exec("/usr/bin/env perldoc $0");
}

Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing") if ($from_reg_name or $to_reg_name);

my $to_dba = get_DBAdaptor($to_url, $to_reg_name);
my $from_dba = get_DBAdaptor($from_url, $from_reg_name);
my $from_ga_adaptor = $from_dba->get_GenomicAlignAdaptor();
my $from_cs_adaptor = $from_dba->get_ConservationScoreAdaptor();
my $from_ce_adaptor = $from_dba->get_ConstrainedElementAdaptor();
my $from_sr_adaptor = $from_dba->get_SyntenyRegionAdaptor();

my $ancestor_genome_db = $from_dba->get_GenomeDBAdaptor()->fetch_by_name_assembly("ancestral_sequences");
my $ancestral_dbID = $ancestor_genome_db ? $ancestor_genome_db->dbID : -1;

print "\n\n";   # to clear from possible warnings

my %type_to_adaptor = (
                       'LASTZ_NET'              => $from_ga_adaptor,
                       'BLASTZ_NET'             => $from_ga_adaptor,
                       'TRANSLATED_BLAT_NET'    => $from_ga_adaptor,
                       'LASTZ_PATCH'            => $from_ga_adaptor,
                       'SYNTENY'                => $from_sr_adaptor,
                       'EPO'                    => $from_ga_adaptor,
                       'EPO_LOW_COVERAGE'       => $from_ga_adaptor,
                       'PECAN'                  => $from_ga_adaptor,
                       'GERP_CONSERVATION_SCORE'    => $from_cs_adaptor,
                       'GERP_CONSTRAINED_ELEMENT'   => $from_ce_adaptor,
);

my %all_mlss_objects = ();

# By default, $disable_keys depends on $merge
$disable_keys //= !$merge;

    # First adding MLSS objects via method_link_type values (the most portable way)
foreach my $one_method_link_type (@method_link_types) {
    my $group_mlss_objects = $from_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type($one_method_link_type);
    if( scalar(@$group_mlss_objects) ) {
        foreach my $one_mlss_object (@$group_mlss_objects) {
            my $one_mlss_id = $one_mlss_object->dbID;
            my $one_mlss_name = $one_mlss_object->name;
            if (my $adaptor = $type_to_adaptor{$one_method_link_type}) {
                if(my $count = $adaptor->count_by_mlss_id($one_mlss_id)) {
                    $all_mlss_objects{ $one_mlss_id } = $one_mlss_object;
                    print "Will be adding MLSS '$one_mlss_name' with dbID '$one_mlss_id' found using method_link_type '$one_method_link_type' ($count entries)\n";
                } else {
                    print "\tSkipping empty MLSS '$one_mlss_name' with dbID '$one_mlss_id' found using method_link_type '$one_method_link_type'\n";
                }
            } else {
                die ("Not recognised mlss_type ($one_method_link_type)");
            }
        }
    } else {
        print "** Warning ** Cannot find any MLSS objects using method_link_type '$one_method_link_type' in this database\n";
    }
}

    # Adding the rest MLSS objects using specific mlss_ids provided
foreach my $one_mlss_id (@mlss_id) {
    if( my $one_mlss_object = $from_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($one_mlss_id) ) {
        my $one_mlss_id = $one_mlss_object->dbID;
        my $one_mlss_name = $one_mlss_object->name;
        $all_mlss_objects{ $one_mlss_id } = $one_mlss_object;
        print "Will be adding MLSS '$one_mlss_name' with dbID '$one_mlss_id' requested\n";
    } else {
        die " ** ERROR ** Cannot find any MLSS object with dbID '$one_mlss_id'";
    }
}

my @all_method_link_species_sets = values %all_mlss_objects;

print "\n-------------------------------\nWill be adding a total of ".scalar(@all_method_link_species_sets)." MLSS objects\n";

if($dry_run) {
    print "\n\t*** This is the dry_run mode. Please remove the --dry_run flag if you want the script to copy anything\n\n";
}

my $from_dbc = $from_dba->dbc;
my $to_dbc = $to_dba->dbc;

while (my $method_link_species_set = shift @all_method_link_species_sets) {
  my $mlss_id = $method_link_species_set->dbID;
  my $class = $method_link_species_set->method->class;

  exit(1) if !check_table("method_link", $from_dbc, $to_dbc, undef,
    "method_link_id = ".$method_link_species_set->method->dbID);
  exit(1) if !check_table("method_link_species_set", $from_dbc, $to_dbc, undef,
    "method_link_species_set_id = $mlss_id");

  #Copy the species_tree_node data if present
  copy_data($from_dbc, $to_dbc,
            "species_tree_node",
            "SELECT stn.* " .
            " FROM species_tree_node stn" .
            " JOIN species_tree_root str using(root_id)" .
            " WHERE str.method_link_species_set_id = $mlss_id") unless $dry_run;

  #Copy the species_tree_root data if present
  copy_table($from_dbc, $to_dbc,
            "species_tree_root",
            "method_link_species_set_id = $mlss_id") unless $dry_run;

  #Copy all entries in method_link_species_set_attr table for a method_link_speceies_set_id
  copy_table($from_dbc, $to_dbc,
          "method_link_species_set_attr",
	  "method_link_species_set_id = $mlss_id") unless $dry_run;

  #Copy all entries in method_link_species_set_tag table for a method_link_speceies_set_id
  copy_table($from_dbc, $to_dbc,
	  "method_link_species_set_tag",
	  "method_link_species_set_id = $mlss_id") unless $dry_run;

  if ($class =~ /^GenomicAlignBlock/ or $class =~ /^GenomicAlignTree/) {
    copy_genomic_align_blocks($from_dbc, $to_dbc, $method_link_species_set);
  } elsif ($class =~ /^ConservationScore.conservation_score/) {
    copy_conservation_scores($from_dbc, $to_dbc, $method_link_species_set);
  } elsif ($class =~ /^ConstrainedElement.constrained_element/) {
    copy_constrained_elements($from_dbc, $to_dbc, $method_link_species_set);
  } elsif ($class =~ /^SyntenyRegion.synteny/) {
    copy_synteny_regions($from_dba, $to_dba, $method_link_species_set);
  } else {
    print " ** ERROR **  Copying data of class $class is not supported yet!\n";
    exit(1);
  }
}

_reenable_all_disabled_keys($to_dba->dbc) if $re_enable;

exit(0);

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
  my $compara_db_adaptor = undef;

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

      $compara_db_adaptor = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(
          -host => $host,
          -user => $user,
          -pass => $pass,
          -port => $port,
          -group => "compara",
          -dbname => $dbname,
          -species => $dbname,
        );
    } else {
      warn("Cannot undestand URL: $url\n");
    }
  } elsif ($name) {
    $compara_db_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($name, "compara");
  }

  return $compara_db_adaptor;
}


=head2 check_table

  Arg[1]      : string $table_name
  Arg[2]      : Bio::EnsEMBL::DBSQL::DBConnection $from_dbc
  Arg[3]      : Bio::EnsEMBL::DBSQL::DBConnection $to_dbc
  Arg[4]      : [optional] string columns (whatever comes between
                'SELECT' and 'FROM')
  Arg[5]      : [optional] string where (whatever comes after
                'WHERE')
  Description : Check the content of the table in $from DB against
                $to DB
  Returns     : bool
  Exceptions  : throw if argument test fails

=cut

sub check_table {
  my ($table_name, $from_dbc, $to_dbc, $columns, $where) = @_;

  print "Checking ".($columns ? "columns [$columns] of the" : '')." table $table_name ".($where ? "where [$where]" : '')."...";

  assert_ref($from_dbc, 'Bio::EnsEMBL::DBSQL::DBConnection', 'from_dbc');
  assert_ref($to_dbc, 'Bio::EnsEMBL::DBSQL::DBConnection', 'from_dbc');

  my $from_entries;
  ## Write SQL query
  my $sql;
  if ($columns) {
    $sql = "SELECT $columns FROM $table_name";
  } else {
    $sql = "SELECT * FROM $table_name";
  }
  if ($where) {
    $sql .= " WHERE $where";
  }

  ## Execute on FROM
  my $sth = $from_dbc->prepare($sql, { 'mysql_use_result' => 1 });
  $sth->execute();
  while (my $row = $sth->fetchrow_arrayref) {
    my $key = join("..", map {defined $_ ? $_ : '<NULL>'} @$row);
    $from_entries->{$key} = 1;
  }
  $sth->finish;

  ## Execute on TO
  $sth = $to_dbc->prepare($sql, { 'mysql_use_result' => 1 });
  $sth->execute();
  while (my $row = $sth->fetchrow_arrayref) {
    my $key = join("..", map {defined $_ ? $_ : '<NULL>'} @$row);
    $from_entries->{$key} -= 1;
  }
  $sth->finish;

  ## Check results
  my $result;
  foreach my $value (values %$from_entries) {
    $result->{$value} ++;
  }

  print "  from = ", ($result->{1} or 0), "; to = ", ($result->{-1} or 0),
      "; both = ", ($result->{0} or 0), "   ";
  if ($result->{1}) {
    print "FAIL\n\n ** ERROR ** $result->{1} rows from the production",
        " database (FROM) are not found on the release one.\n\n";
    return 0;
  } elsif (!$result->{0}) {
    print "WARN\n\n ** WARNING ** the production database (FROM) has",
        " no data in $table_name.\n\n";
  } else {
    print "ok.\n";
  }

  return 1;
}


=head2 copy_genomic_align_blocks

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBConnection $from_dbc
  Arg[2]      : Bio::EnsEMBL::DBSQL::DBConnection $to_dbc
  Arg[3]      : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $this_mlss

  Description : copies GenomicAlignBlocks for this MethodLinkSpeciesSet.
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_genomic_align_blocks {
  my ($from_dbc, $to_dbc, $mlss) = @_;
  my $fix_dnafrag = 0;

  my $mlss_id = $mlss->dbID;
  my $gdb_ids = join(', ', map { $_->dbID() } @{ $mlss->species_set->genome_dbs });

  exit(1) if !check_table("genome_db", $from_dbc, $to_dbc, "genome_db_id, name, assembly, genebuild", "genome_db_id IN ($gdb_ids)" );
  #ignore ancestral dnafrags, will add those later
  if (!check_table("dnafrag", $from_dbc, $to_dbc, undef, "genome_db_id != $ancestral_dbID AND genome_db_id IN ($gdb_ids)")) {
      $fix_dnafrag = 1;
      if ($fix_dnafrag && !$trust_to) {
          print " To fix the dnafrags in the genomic_align table, you can use the trust_to flag\n\n";
          exit(1);
      }
  }

  my $minmax_sql = qq{ SELECT
        MIN(gab.genomic_align_block_id), MAX(gab.genomic_align_block_id),
        MIN(gab.group_id), MAX(gab.group_id),
        MIN(ga.genomic_align_id), MAX(ga.genomic_align_id),
        MIN(gat.node_id), MAX(gat.node_id),
        MIN(gat.root_id), MAX(gat.root_id)
    FROM genomic_align_block gab
    LEFT JOIN genomic_align ga using (genomic_align_block_id)
	LEFT JOIN genomic_align_tree gat ON gat.node_id = ga.node_id
      WHERE
        gab.method_link_species_set_id = ? };

  ## Check min and max of the relevant internal IDs in the FROM database
  my $sth = $from_dbc->prepare( $minmax_sql );

  $sth->execute($mlss_id);
  my ($min_gab, $max_gab, $min_gab_gid, $max_gab_gid, $min_ga, $max_ga, 
		$min_gat, $max_gat, $min_root_id, $max_root_id) =
      $sth->fetchrow_array();

  $sth->finish();

  my $fix_gab;
  my $fix_ga;
  my $fix_gab_gid;
  my $fix_gat;

  #Want to add more data. Must find out current max(genomic_align_block) in TO
  #database and start from there
  #Currently only tested for pairwise alignments
  my ($to_min_gab, $to_max_gab, $to_min_gab_gid, $to_max_gab_gid, $to_min_ga, $to_max_ga, $to_min_gat, $to_max_gat, $to_min_root_id, $to_max_root_id, $to_from_index_range_start);

  if ($merge) {
        # make sure keys are on if we are merging
      foreach my $table_name ('genomic_align', 'genomic_align_block', 'genomic_align_tree') {
          last if $dry_run;
          print "Enabling keys on '$table_name' in merge mode...\n";
          $to_dbc->do("ALTER TABLE `$table_name` ENABLE KEYS");
          print "done enabling keys on '$table_name'.\n";
      }

      my $sth = $to_dbc->prepare( $minmax_sql );

      $sth->execute($mlss_id);
      ($to_min_gab, $to_max_gab, $to_min_gab_gid, $to_max_gab_gid, $to_min_ga, $to_max_ga, $to_min_gat, $to_max_gat, $to_min_root_id, $to_max_root_id, $to_from_index_range_start) =  $sth->fetchrow_array();

      $sth->finish();
      $fix_gab = $to_max_gab-$min_gab+1;
      $fix_ga = $to_max_ga-$min_ga+1;
      $fix_gat = $to_max_gat-$min_gat+1 if ($to_max_gat && $min_gat);
      $fix_gab_gid = $to_max_gab_gid-$min_gab_gid+1;

      #print "to max_gab $to_max_gab min_gab $to_min_gab max_ga $to_max_ga min_ga $to_min_ga max_gab_gid $to_max_gab_gid min_gab_gid $to_min_gab_gid\n";
  }
  print "max_gab $max_gab min_gab $min_gab max_ga $max_ga min_ga $min_ga max_gab_gid $max_gab_gid min_gab_gid $min_gab_gid\n";

  my $lower_limit = $mlss_id * 10**10;
  my $upper_limit = ($mlss_id + 1) * 10**10;

  if (!defined $fix_gab) {
      if ($max_gab < 10**10) {
          $fix_gab = $lower_limit;
      } elsif ($min_gab >= $lower_limit and $max_gab < $upper_limit) {
          $fix_gab = 0;
      } else {
          die " ** ERROR **  Internal IDs are funny: genomic_align_block_ids between $min_gab and $max_gab\n";
      }
  }

  if (!defined $fix_ga) {
      if ($max_ga < 10**10) {
          $fix_ga = $lower_limit;
      } elsif ($min_ga >= $lower_limit and $max_ga < $upper_limit) {
          $fix_ga = 0;
      } else {
          die " ** ERROR **  Internal IDs are funny: genomic_align_ids between $min_ga and $max_ga\n";
      }
  }

  if (!defined $fix_gab_gid) {
      if (defined($max_gab_gid)) {
          if ($max_gab_gid < 10**10) {
              $fix_gab_gid = $lower_limit;
          } elsif ($min_gab_gid >= $lower_limit and $max_gab_gid < $upper_limit) {
              $fix_gab_gid = 0;
          } else {
              die " ** ERROR **  Internal IDs are funny: genomic_align_block.group_ids between $min_gab_gid and $max_gab_gid\n";
          }
      } else {
          $fix_gab_gid = 0;
      }
  }

  if (!defined $fix_gat) {
      if (defined($max_gat)) {
          if ($max_gat < 10**10) {
              $fix_gat = $lower_limit;
          } elsif ($min_gat >= $lower_limit and $max_gat < $upper_limit) {
              $fix_gat = 0;
          } else {
              die " ** ERROR **  Internal IDs are funny: genomic_align_tree.node_ids between $min_gat and $max_gat\n";
          }
      } else {
          $fix_gat = 0;
      }
  }
  
  ## Check availability of the internal IDs in the TO database
  $sth = $to_dbc->prepare("SELECT count(*)
      FROM genomic_align_block
      WHERE genomic_align_block_id >= $lower_limit
          AND genomic_align_block_id < $upper_limit");
  $sth->execute();
  my ($count) = $sth->fetchrow_array();
  if ($count && !$merge) {
    print " ** ERROR **  There are $count entries in the release database (TO) in the \n",
      " ** ERROR **  genomic_align_block table with IDs within the range defined by the\n",
      " ** ERROR **  convention!\n";
    exit(1);
  }

  $sth = $to_dbc->prepare("SELECT count(*)
      FROM genomic_align
      WHERE genomic_align_id >= $lower_limit
          AND genomic_align_id < $upper_limit");
  $sth->execute();
  ($count) = $sth->fetchrow_array();
  if ($count && !$merge) {
    print " ** ERROR **  There are $count entries in the release database (TO) in the \n",
      " ** ERROR **  genomic_align table with IDs within the range defined by the\n",
      " ** ERROR **  convention!\n";
    exit(1);
  }

  #print "SELECT count(*) FROM genomic_align_tree WHERE root_id >= $min_root_id AND root_id < $max_root_id\n\n";

  if(defined($max_gat)) {
    $sth = $to_dbc->prepare("SELECT count(*)
        FROM genomic_align_tree
        WHERE root_id >= $min_root_id
            AND root_id < $max_root_id");
    $sth->execute();
    my ($count) = $sth->fetchrow_array();
    if ($count) {
      print " ** ERROR **  There are $count entries in the release database (TO) in the \n",
        " ** ERROR **  genomic_align_tree table with IDs within the range defined by the\n",
        " ** ERROR **  convention!\n";
      exit(1);
   }
  }

  return if $dry_run;

  _disable_keys_if_allowed($to_dbc, 'genomic_align');
  _disable_keys_if_allowed($to_dbc, 'genomic_align_block');
  _disable_keys_if_allowed($to_dbc, 'genomic_align_tree');

  my @copy_data_args = (undef, 'skip_disable_keys');

  #copy genomic_align_block table
  if ($fix_gab or $fix_gab_gid) {
    copy_data($from_dbc, $to_dbc,
       "genomic_align_block",
       "SELECT genomic_align_block_id+$fix_gab, method_link_species_set_id, score, perc_id, length, group_id+$fix_gab_gid, level_id".
         " FROM genomic_align_block WHERE method_link_species_set_id = $mlss_id",
       @copy_data_args);
  } else {
    copy_table($from_dbc, $to_dbc, 'genomic_align_block', "method_link_species_set_id = $mlss_id", undef, "skip_disable_keys");
  }

  #copy genomic_align_tree table
  #Fixes node_id, parent_id, root_id, left_node_id, right_node_id 
  #Needs to correct parent_id, left_node_id, right_node_id if these were 0
  if(defined($max_gat)) {
    if ($fix_gat) {
      copy_data($from_dbc, $to_dbc,
        "genomic_align_tree",
        "SELECT node_id+$fix_gat, parent_id+$fix_gat, root_id+$fix_gat, left_index, right_index, left_node_id+$fix_gat, right_node_id+$fix_gat, distance_to_parent".
        " FROM genomic_align_tree ".
	"WHERE root_id >= $min_root_id AND root_id <= $max_root_id",
        @copy_data_args);

    #Reset the appropriate nodes to zero. Only needs to be done if fix_lower 
    #has been applied.

	#NEED TO CHECK THIS ONE!!
        foreach my $gt_field( qw/ parent_id node_id left_node_id right_node_id / ) {
            my $gt_sth = $to_dbc->prepare("UPDATE genomic_align_tree SET $gt_field = ($gt_field - ?)
                                        WHERE $gt_field = ?");
            $gt_sth->execute($fix_gat, $fix_gat);
        }
    } else {
      copy_table($from_dbc, $to_dbc, 'genomic_align_tree', "root_id >= $min_root_id AND root_id <= $max_root_id", undef, "skip_disable_keys");
    }
  }
  my $class = $mlss->method->class;
  if ($class eq "GenomicAlignTree.ancestral_alignment") {
      copy_ancestral_dnafrags($from_dbc, $to_dbc, $mlss_id, $lower_limit, $upper_limit);
  }

  #copy genomic_align table. Need to update dnafrag column
  if ($trust_to && $fix_dnafrag) {

      #create a temporary genomic_align table with TO dnafrag_ids
      my $temp_genomic_align = "temp_genomic_align";
      fix_genomic_align_table($from_dbc, $to_dbc, $mlss_id, $temp_genomic_align);
      
      #copy from the temporary genomic_align table
      copy_data($from_dbc, $to_dbc,
  	    "genomic_align",
  	    "SELECT genomic_align_id+$fix_ga, genomic_align_block_id+$fix_gab, method_link_species_set_id,".
  	    " dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand, cigar_line, visible, node_id+$fix_gat".
  	    " FROM $temp_genomic_align".
            " WHERE method_link_species_set_id = $mlss_id",
            @copy_data_args);

      #delete temporary genomic_align table
      $from_dbc->db_handle->do("DROP TABLE $temp_genomic_align");
  } elsif ($fix_ga or $fix_gab or $fix_gat) {
      copy_data($from_dbc, $to_dbc,
		"genomic_align",
		"SELECT genomic_align_id+$fix_ga, genomic_align_block_id+$fix_gab, method_link_species_set_id,".
		" dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand, cigar_line, visible, node_id+$fix_gat".
		" FROM genomic_align".
		" WHERE method_link_species_set_id = $mlss_id",
                @copy_data_args);
  } else {
      copy_table($from_dbc, $to_dbc, 'genomic_align', "method_link_species_set_id = $mlss_id", undef, "skip_disable_keys");
  }

}


=head2 copy_ancestral_dnafrags

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBConnection $from_dbc
  Arg[2]      : Bio::EnsEMBL::DBSQL::DBConnection $to_dbc
  Arg[3]      : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $this_mlss
  Arg[4]      : integer lower limit of dnafrag_id range ($mlss_id * 10**10)
  Arg[5]      : integer upper limit of dnafrag_id range (($mlss_id + 1) * 10**10)

  Description : copies ancestral dnafrags for this MethodLinkSpeciesSet.
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_ancestral_dnafrags {
  my ($from_dbc, $to_dbc, $mlss_id, $lower_limit, $upper_limit) = @_;

  #Check name is correct syntax
  my $dnafrag_name = "Ancestor_" . $mlss_id . "_";
  my $sth = $from_dbc->prepare("SELECT name FROM genomic_align
                                         LEFT JOIN dnafrag USING (dnafrag_id)
                                         WHERE genome_db_id = $ancestral_dbID
                                         AND method_link_species_set_id = ? LIMIT 1");
  $sth->execute($mlss_id);
  my @names = $sth->fetchrow_array();
  $sth->finish();
  #Just look at first name and assume all other names are of the same format
  my $name = $names[0];
  if ($name =~ /$dnafrag_name/) {
      print "valid name\n";
  } else {
      throw("name is not $dnafrag_name format\n");
  }
  #Check name does not already exist in TO database
  $sth = $to_dbc->prepare("SELECT count(*) FROM dnafrag WHERE genome_db_id = $ancestral_dbID AND name LIKE '" . $dnafrag_name . "%'");
  
  $sth->execute();
  my ($count) = $sth->fetchrow_array();
  $sth->finish();
  if ($count) {
      throw("ERROR: $count rows in the dnafrag table with name like $dnafrag_name already exists in the release (TO) database\n");
  }

  #Check min and max of internal IDs in the FROM database
  $sth = $from_dbc->prepare("SELECT MIN(dnafrag_id),
                                         MAX(dnafrag_id)
                                         FROM genomic_align
                                         LEFT JOIN dnafrag USING (dnafrag_id)
                                         WHERE genome_db_id = $ancestral_dbID
                                         AND method_link_species_set_id = ?");
  $sth->execute($mlss_id);
  my ($min_dnafrag_id, $max_dnafrag_id) = $sth->fetchrow_array();
  $sth->finish();
  my $fix_dnafrag_id;
  if ($max_dnafrag_id < 10**10) {
      $fix_dnafrag_id = $lower_limit;
  } elsif ($min_dnafrag_id >= $lower_limit and $max_dnafrag_id < $upper_limit) {
      $fix_dnafrag_id = 0;
  } else {
      die " ** ERROR **  Internal IDs are funny: dnafrag_ids between $min_dnafrag_id and $max_dnafrag_id\n";
  }
  
  ## Check availability of the internal IDs in the TO database
  $sth = $to_dbc->prepare("SELECT count(*)
      FROM dnafrag
      WHERE dnafrag_id >= $lower_limit
      AND dnafrag_id < $upper_limit");
  $sth->execute();
  ($count) = $sth->fetchrow_array();
  if ($count) {
      print " ** ERROR **  There are $count entries in the release database (TO) in the \n",
	" ** ERROR **  dnafrag table with IDs within the range defined by the\n",
	  " ** ERROR **  convention!\n";
      exit(1);
  }
  
  #copy dnafrag table
   copy_data($from_dbc, $to_dbc,
       "dnafrag",
       "SELECT dnafrag_id+$fix_dnafrag_id, length, name, genome_db_id, coord_system_name, is_reference".
         " FROM genomic_align LEFT JOIN dnafrag USING (dnafrag_id)" .
         " WHERE method_link_species_set_id = $mlss_id AND genome_db_id=$ancestral_dbID",
       undef, 'skip_disable_keys',
   );

}

=head2 copy_conservation_scores

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBConnection $from_dbc
  Arg[2]      : Bio::EnsEMBL::DBSQL::DBConnection $to_dbc
  Arg[3]      : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $this_mlss

  Description : copies ConservationScores for this MethodLinkSpeciesSet.
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_conservation_scores {
  my ($from_dbc, $to_dbc, $method_link_species_set) = @_;

  my $gab_mlss_id = $method_link_species_set->get_value_for_tag('msa_mlss_id');
  if (!$gab_mlss_id) {
    print " ** ERROR **  Needs a 'msa_mlss_id' entry in the method_link_species_set_tag table!\n";
    exit(1);
  }
  exit(1) if !check_table("method_link_species_set", $from_dbc, $to_dbc, undef,
      "method_link_species_set_id = $gab_mlss_id");

  ## Check min and max of the relevant internal IDs in the FROM database
  my $sth = $from_dbc->prepare("SELECT
        MIN(cs.genomic_align_block_id), MAX(cs.genomic_align_block_id)
      FROM genomic_align_block gab
        LEFT JOIN conservation_score cs using (genomic_align_block_id)
      WHERE
        gab.method_link_species_set_id = ?");

  $sth->execute($gab_mlss_id);
  my ($min_cs, $max_cs) = $sth->fetchrow_array();
  $sth->finish();

  my $lower_limit = $gab_mlss_id * 10**10;
  my $upper_limit = ($gab_mlss_id + 1) * 10**10;
  my $fix;
  if ($max_cs < 10**10) {
    ## Need to add $method_link_species_set_id * 10^10 to the internal_ids
    $fix = $lower_limit;
  } elsif ($max_cs and $min_cs >= $lower_limit) {
    ## Internal IDs are OK.
    $fix = 0;
  } else {
    die " ** ERROR **  Internal IDs are funny. Case not implemented yet!\n";
  }

  ## Check availability of the internal IDs in the TO database
  $sth = $to_dbc->prepare("SELECT count(*)
      FROM conservation_score
      WHERE genomic_align_block_id >= $lower_limit
          AND genomic_align_block_id < $upper_limit");
  $sth->execute();
  my ($count) = $sth->fetchrow_array();
  if ($count) {
    print " ** ERROR **  There are $count entries in the release database (TO) in the \n",
      " ** ERROR **  conservation_score table with IDs within the range defined by the\n",
      " ** ERROR **  convention!\n";
    exit(1);
  }

  return if $dry_run;

  _disable_keys_if_allowed($to_dbc, 'conservation_score');

  # Most of the times, you want to copy all the data. Check if this is the case as it will be much faster!
  $sth = $from_dbc->prepare("SELECT count(*)
      FROM conservation_score LEFT JOIN genomic_align_block
      USING (genomic_align_block_id)
      WHERE method_link_species_set_id != $gab_mlss_id limit 1");
  $sth->execute();
  ($count) = $sth->fetchrow_array();

  if ($count) {
    ## Other scores are in the from database.
    print " ** WARNING **\n";
    print " ** WARNING ** Copying only part of the data in the conservation_score table\n";
    print " ** WARNING ** This process might be very slow.\n";
    print " ** WARNING **\n";
    copy_data($from_dbc, $to_dbc,
        "conservation_score",
        "SELECT cs.genomic_align_block_id+$fix, window_size, position, expected_score, diff_score".
          " FROM genomic_align_block gab".
          " LEFT JOIN conservation_score cs using (genomic_align_block_id)".
          " WHERE cs.genomic_align_block_id IS NOT NULL AND gab.method_link_species_set_id = $gab_mlss_id",
        undef, 'skip_disable_keys',
      );
  } elsif ($fix) {
    ## These are the only scores but need to fix them.
    print " ** WARNING **\n";
    print " ** WARNING ** Copying in 'fix' mode\n";
    print " ** WARNING ** This process might be very slow.\n";
    print " ** WARNING **\n";
    copy_data($from_dbc, $to_dbc,
        "conservation_score",
        "SELECT cs.genomic_align_block_id+$fix, window_size, position, expected_score, diff_score".
          " FROM conservation_score cs" . 
	  " WHERE genomic_align_block_id >= $min_cs AND genomic_align_block_id <= $max_cs",
        undef, 'skip_disable_keys',
    );
  } else {
      ## These are the only scores and need no fixing. Copy all as they are
      copy_table($from_dbc, $to_dbc, "conservation_score");
  }
}

=head2 copy_constrained_elements

  Arg[1]      : Bio::EnsEMBL::DBSQL::DBConnection $from_dbc
  Arg[2]      : Bio::EnsEMBL::DBSQL::DBConnection $to_dbc
  Arg[3]      : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $this_mlss

  Description : copies ConstrainedElements for this MethodLinkSpeciesSet.
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_constrained_elements {
  my ($from_dbc, $to_dbc, $method_link_species_set) = @_;

  my $gab_mlss_id = $method_link_species_set->get_value_for_tag('msa_mlss_id');
  if (!$gab_mlss_id) {
    print " ** ERROR **  Needs a 'msa_mlss_id' entry in the method_link_species_set_tag table!\n";
    exit(1);
  }
  exit(1) if !check_table("method_link_species_set", $from_dbc, $to_dbc, undef,
      "method_link_species_set_id = $gab_mlss_id");

  my $mlss_id = $method_link_species_set->dbID;
  my $lower_limit = $mlss_id * 10**10;
  my $upper_limit = ($mlss_id + 1) * 10**10;

  ## Check min and max of the relevant internal IDs in the FROM database
  my $sql = "SELECT MIN(ce.constrained_element_id), MAX(ce.constrained_element_id) FROM constrained_element ce WHERE "
        . ($trust_ce
            ? " ce.constrained_element_id BETWEEN $lower_limit AND $upper_limit "
            : " ce.method_link_species_set_id = '$mlss_id'"
        );

  my $sth = $from_dbc->prepare( $sql );

  $sth->execute();
  my ($min_ce, $max_ce) = $sth->fetchrow_array();
  $sth->finish();

  my $fix;

  if ($max_ce < 10**10) {
    ## Need to add $method_link_species_set_id * 10^10 to the internal_ids
    $fix = $lower_limit;
  } elsif ($max_ce and $min_ce >= $lower_limit) {
    ## Internal IDs are OK.
    $fix = 0;
  } else {
    die " ** ERROR **  Internal IDs are funny. Case not implemented yet!\n";
  }

  ## Check availability of the internal IDs in the TO database
  $sth = $to_dbc->prepare("SELECT count(*)
      FROM constrained_element
      WHERE constrained_element_id >= $lower_limit
          AND constrained_element_id < $upper_limit");
  $sth->execute();
  my ($count) = $sth->fetchrow_array();
  if ($count) {
    print " ** ERROR **  There are $count entries in the release database (TO) in the \n",
      " ** ERROR **  constrained_element table with IDs within the range defined by the\n",
      " ** ERROR **  convention!\n";
    exit(1);
  }

  return if $dry_run;

  _disable_keys_if_allowed($to_dbc, 'constrained_element');

  if ($fix) {
    copy_data($from_dbc, $to_dbc,
        "constrained_element",
        "SELECT constrained_element_id+$fix, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand,
	method_link_species_set_id, p_value, score".
        " FROM constrained_element".
        " WHERE method_link_species_set_id = $mlss_id",
        undef, 'skip_disable_keys',
    );
  } else {
      ## Need no fixing. Copy as they are
      copy_table($from_dbc, $to_dbc, "constrained_element", "method_link_species_set_id = $mlss_id", undef, "skip_disable_keys");
  }
}

=head2 copy_synteny_regions

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $from_dba
  Arg[2]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $to_dba
  Arg[3]      : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $this_mlss

  Description : copies SyntenyRegions for this MethodLinkSpeciesSet.
  Returns     :
  Exceptions  : throw if argument test fails

=cut

sub copy_synteny_regions {
    my ($from_dba, $to_dba, $mlss) = @_;

    my $to_sra = $to_dba->get_SyntenyRegionAdaptor;
    my $existing_synteny_regions = $to_sra->fetch_all_by_MethodLinkSpeciesSet($mlss);
    if (my $count = scalar(@$existing_synteny_regions)) {
        print " ** ERROR **  There are $count entries in the release database (TO) in the \n",
            " ** ERROR **  synteny_region table with the MLSS_ID ".($mlss->dbID)."\n";
        exit(1);
    }
    # No concept of dry_run with synteny_regions
    return if $dry_run;

    # There is usually not much data, so using the API is fine
    my $all_synteny_regions = $from_dba->get_SyntenyRegionAdaptor->fetch_all_by_MethodLinkSpeciesSet($mlss);
    foreach my $synteny_region (@$all_synteny_regions) {
        # No dbID to fix, we just let the AUTO_INCREMENT do its magic
        $synteny_region->dbID(undef);
        $to_sra->store($synteny_region);
    }
}


#fix the genomic_align table
sub fix_genomic_align_table {
    my ($from_dbc, $to_dbc, $mlss_id, $temp_genomic_align) = @_;

    print "\n ** WARNING ** Fixing the dnafrag_ids in the genomic_align table requires write access.\n";
    print " ** WARNING ** Two temporary tables are created, temp_dnafrag and temp_genomic_align. The original tables are not altered.\n\n";

    #create new dnafrag table in FROM database
    $from_dbc->db_handle->do("CREATE TABLE temp_dnafrag LIKE dnafrag");

    #copy over only those dnafrags for the genome_db_ids in the mlss.
    my $query = "SELECT dnafrag.* FROM method_link_species_set LEFT JOIN species_set USING (species_set_id) LEFT JOIN dnafrag USING (genome_db_id) WHERE method_link_species_set_id=$mlss_id";
    copy_data($from_dbc, $to_dbc, "temp_dnafrag", $query);

    #check that don't have dnafrags in the FROM database that aren't in the
    #TO database - need to exit if there are and reassess the situation!
    my $sth = $from_dbc->prepare("SELECT dnafrag.* FROM method_link_species_set LEFT JOIN species_set USING (species_set_id) LEFT JOIN dnafrag USING (genome_db_id) LEFT JOIN temp_dnafrag USING (genome_db_id, name, length, coord_system_name) WHERE method_link_species_set_id=$mlss_id AND temp_dnafrag.genome_db_id IS NULL;");
    $sth->execute();
    my $rows = $sth->fetchall_arrayref();
    if (@$rows) {
	print "\n** ERROR ** The following dnafrags are present in the production (FROM) dnafrag table and are not present in the release (TO) dnafrag table\n"; 
	foreach my $row (@$rows) {
	    print "@$row\n";
	}
	$from_dbc->db_handle->do("DROP TABLE temp_dnafrag");
	exit(1);
    }
    
    #copy genomic_align table into a temporary table
    $from_dbc->db_handle->do("CREATE TABLE $temp_genomic_align LIKE genomic_align");
      
    #fill the table
    #doing this in 2 steps means we don't have to make assumptions as to the column names in the genomic_align table
    $sth = $from_dbc->prepare("INSERT INTO $temp_genomic_align SELECT * FROM genomic_align WHERE method_link_species_set_id=$mlss_id");
    $sth->execute();
    
    #update the table 
    $sth = $from_dbc->prepare("UPDATE $temp_genomic_align ga, dnafrag df, temp_dnafrag df_temp SET ga.dnafrag_id=df_temp.dnafrag_id WHERE ga.dnafrag_id=df.dnafrag_id AND df.genome_db_id=df_temp.genome_db_id AND df.name=df_temp.name AND df.coord_system_name=df_temp.coord_system_name AND ga.method_link_species_set_id=$mlss_id");
    $sth->execute();

    #delete the temporary dnafrag table
    $from_dbc->db_handle->do("DROP TABLE temp_dnafrag");
}


my %disabled_keys;

sub _disable_keys_if_allowed {
    my ($dbc, $table) = @_;
    return unless $disable_keys;
    return unless $disabled_keys{$table};
    $dbc->db_handle->do("ALTER TABLE $table DISABLE KEYS");
    $disabled_keys{$table} = 1;
}

sub _reenable_all_disabled_keys {
    my $dbc = shift;
    $dbc->db_handle->do("ALTER TABLE $_ ENABLE KEYS") for keys %disabled_keys;
    %disabled_keys = ();
}

