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
## PROGRAM copy_ancestral_core.pl
##
## AUTHORS
##    Kathryn Beal
##
## DESCRIPTION
##    This script copies ancestral data over core DBs. It has been
##    specifically developed to copy data from a production to a
##    release database.
##
###########################################################################

};

=head1 NAME

copy_ancestral_core.pl

=head1 AUTHORS

 Kathryn Beal

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

perl copy_ancestral_core.pl --help

perl copy_ancestral_core.pl
    [--reg-conf registry_configuration_file]
    --from production_database_name
    --to release_database_name
    --mlss method_link_species_set_id

perl copy_ancestral_core.pl
    --from_url production_database_url
    --to_url release_database_url
    --mlss method_link_species_set_id

example:

bsub  -q yesterday -ooutput_file -Jcopy_data -R "select[mem>5000] rusage[mem=5000]" -M5000000 \
  copy_ancestral_core.pl --from_url mysql://username@server_name/sf5_production \
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
use Bio::EnsEMBL::Compara::Utils::CopyData qw(:table_copy);
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

Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing") if ($from_name or $to_name);
my $from_dba = get_DBAdaptor($from_url, $from_name);
my $to_dba = get_DBAdaptor($to_url, $to_name);

#Check have coord_system set
check_coord_system_table($to_dba);

copy_ancestral_data($from_dba->dbc, $to_dba->dbc, $mlss_id);


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

sub copy_ancestral_data {
    my ($from_dbc, $to_dbc, $mlss_id) = @_;
    my $coord_system_name = "ancestralsegment";

    #
    #Check from_dbc has correct structure.
    #
    my $name = "Ancestor_" . $mlss_id;

    my $name_sql = "SELECT COUNT(*) FROM seq_region WHERE name LIKE '${name}_%'";
    my ($num_sr) = $from_dbc->db_handle->selectrow_array($name_sql);
    if ($num_sr == 0) {
	throw("Invalid seq_region name. Should be of the form: ${name}_%");
    }
    
    #
    #Check coord_system_id the same in from_db and to_db
    #
    my $cs_sql = "SELECT coord_system_id FROM coord_system WHERE name = '$coord_system_name'";
    my ($coord_system_id) = $to_dbc->db_handle->selectrow_array($cs_sql);
    #print "cs $coord_system_id\n";

    $cs_sql = "SELECT count(*) FROM seq_region WHERE coord_system_id = $coord_system_id";
    my ($num_cs) = $from_dbc->db_handle->selectrow_array($cs_sql);
    if ($num_cs == 0) {
	throw("coord_system_id $coord_system_id does not exist in the production database. This needs to be fixed.");
    }
    
    #Check no clashes in to_db
    my ($num_to_sr) = $to_dbc->db_handle->selectrow_array($name_sql);
    if ($num_to_sr != 0) {
	throw("Already have names of $name in the production database. This needs to be fixed");
    }

    #
    #Find min seq_region_id
    #
    my $range_sql = "SELECT MIN(seq_region_id), MAX(seq_region_id) FROM seq_region WHERE name LIKE '${name}_%'";
    my ($min_sr, $max_sr) = $from_dbc->db_handle->selectrow_array($range_sql);

    #
    #Copy the seq_region rows with new, auto-incremented, seq_region_ids
    #We expect copy_data to reserve *consecutive* rows, this is done with "mysqlimport --lock-tables"
    #The ORDER BY clause is important because otherwise the database engine could return the rows in any order
    #
    print "reserving seq_region_ids\n";
    my $query = "SELECT 0, name, coord_system_id, length FROM seq_region WHERE name like '${name}_%' ORDER BY seq_region_id";
    copy_data($from_dbc, $to_dbc, 'seq_region', $query);

    #
    #Find min of new seq_region_ids
    #
    my ($new_min_sr) = $to_dbc->db_handle->selectrow_array($range_sql);

    #
    #Copy over the dna with new seq_region_ids
    #Assuming all of the above, the seq_region_ids can be simply shifted
    #
    $query = "SELECT seq_region_id+$new_min_sr-$min_sr, sequence FROM dna WHERE seq_region_id BETWEEN $min_sr AND $max_sr";

    print "copying dna\n";
    copy_data($from_dbc, $to_dbc, 'dna', $query);
}

