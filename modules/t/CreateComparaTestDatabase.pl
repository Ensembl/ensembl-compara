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


# File name: CreateComparaTestDatabase.pl
#
# Given a source and destination database this script will create 
# a ensembl compara database on the same mysql server as the source and populate it
#

use strict;
use warnings;

use Getopt::Long;
use DBI;

use Bio::EnsEMBL::Compara::Utils::RunCommand;

my ($help, $srcDB, $destDB, $host, $user, $pass, $port, $seq_region_file);
my ($srcAncDB, $destAncDB);

my $ref_genome_db_name = "homo_sapiens";

#Genomes I want to extract
my @other_genome_db_names = ("pan_troglodytes", "gorilla_gorilla", "tarsius_syrichta", "mus_musculus", "rattus_norvegicus", "oryctolagus_cuniculus", "canis_familiaris", "felis_catus", "equus_caballus", "sus_scrofa", "loxodonta_africana", "bos_taurus", "macaca_mulatta", "pongo_abelii", "callithrix_jacchus");

#Need all low-coverage genome for pairwise
my @pairwise_genome_db_names = ("pan_troglodytes", "mus_musculus", "tarsius_syrichta", "oryctolagus_cuniculus", "felis_catus", "loxodonta_africana");

my $pairwise_method_link_type = '"BLASTZ_NET", "LASTZ_NET"';
my $epo_alignment_method_link_type = "EPO";
my $epo_low_coverage_alignment_method_link_type = "EPO_LOW_COVERAGE";
my $pecan_alignment_method_link_type = "PECAN";
my $constrained_element_method_link_type = "GERP_CONSTRAINED_ELEMENT";
my $conservation_score_method_link_type = "GERP_CONSERVATION_SCORE";

my $pecan_species_set_name = "amniotes";
my $epo_species_set_name = "mammals";
my $ancestral_coord_system_name = "ancestralsegment";

my $do_pairwise = 1;
my $do_pecan = 1;
my $do_epo = 1;
my $do_epo_low_coverage = 1;

GetOptions('help' => \$help,
           's=s' => \$srcDB,
           'sa=s' => \$srcAncDB,
	   'd=s' => \$destDB,
	   'da=s' => \$destAncDB,
	   'h=s' => \$host,
	   'u=s' => \$user,
	   'p=s' => \$pass,
	   'port=i' => \$port,
           'seq_region_file=s' => \$seq_region_file);

my $usage = "Usage:
CreateComparaTestDatabase.pl -s srcDB -d destDB -h host -u user -p pass -seq_region_file file [--port port]\n";

if ($help) {
  print $usage;
  exit 0;
}

unless($port) {
  $port = 3306;
}

# If needed command line args are missing print the usage string and quit
$srcDB and $destDB and $host and $user and $pass and $seq_region_file or die $usage;



my @seq_regions = @{do $seq_region_file};

my $dsn = "DBI:mysql:host=$host;port=$port";

# Connect to the mySQL host
my $dbh = DBI->connect( $dsn, $user, $pass, {RaiseError => 1})
  or die "Could not connect to database host : " . DBI->errstr;

print "\nWARNING: If the $destDB database already exists the existing copy \n"
  . "will be destroyed. Proceed (y/n)? ";

my $key = lc(getc());

unless( $key =~ /y/ ) {
  $dbh->disconnect();
  print "Test Genome Creation Aborted\n";
  exit;
}

print "Proceeding with test genome database $destDB creation\n";  

# dropping any destDB database if there
my $array_ref = $dbh->selectall_arrayref("SHOW DATABASES LIKE '$destDB'");

if (scalar @{$array_ref}) {
  $dbh->do("DROP DATABASE $destDB");
}
# creating destination database
$dbh->do( "CREATE DATABASE " . $destDB )
  or die "Could not create database $destDB: " . $dbh->errstr;


#Create ancestral db if required
if ($destAncDB) {
    # dropping any destDB database if there
    my $array_ref = $dbh->selectall_arrayref("SHOW DATABASES LIKE '$destAncDB'");
    
    if (scalar @{$array_ref}) {
        $dbh->do("DROP DATABASE $destAncDB");
    }
    # creating destination database
    $dbh->do( "CREATE DATABASE " . $destAncDB )
      or die "Could not create database $destAncDB: " . $dbh->errstr;
}

# Dump the source database table structure (w/o data) and use it to create
# the new database schema

# May have to eliminate the -p pass part... not sure

my $cmd = (
  "mysqldump -u ensro -h $host -P $port --no-data $srcDB | " .
  "mysql -p$pass -u $user -h $host -P $port $destDB");
Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec($cmd, { die_on_failure => 1, use_bash_pipefail => 1 } );

if ($destAncDB) {
                         $cmd = (
                             "mysqldump -u ensro -h $host -P $port --no-data $srcAncDB | " .
                             "mysql -p$pass -u $user -h $host -P $port $destAncDB");
                         Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec($cmd, { die_on_failure => 1, use_bash_pipefail => 1 } );
}


$dbh->do("use $destDB");

#Populate method_link
$dbh->do("insert into method_link select * from $srcDB.method_link");

#Populate method_link_species_set (take all so more data can be added at a later date)
$dbh->do("insert into method_link_species_set select * from $srcDB.method_link_species_set");

#Populate method_link_species_set_tag (take all so more data can be added at a later date)
$dbh->do("INSERT INTO method_link_species_set_tag SELECT * FROM $srcDB.method_link_species_set_tag");

#Populate method_link_species_set_attr (take all so more data can be added at a later date)
$dbh->do("INSERT INTO method_link_species_set_attr SELECT * FROM $srcDB.method_link_species_set_attr");

#Populate species_set_header (take all so more data can be added at a later date)
$dbh->do("INSERT INTO species_set_header SELECT * FROM $srcDB.species_set_header");

#Populate species_set (take all so more data can be added at a later date)
$dbh->do("INSERT INTO species_set SELECT * FROM $srcDB.species_set");

#Populate species_set_tag (take all so more data can be added at a later date)
$dbh->do("INSERT INTO species_set_tag SELECT * FROM $srcDB.species_set_tag");

#Populate genome_db
$dbh->do("insert into genome_db select * from $srcDB.genome_db");
$dbh->do("update genome_db set locator=NULL");

#Populate meta
$dbh->do("insert into meta select * from $srcDB.meta");

#Populate ncbi_taxa_node
$dbh->do("insert into ncbi_taxa_node select * from $srcDB.ncbi_taxa_node");

#Populate ncbi_taxa_name
$dbh->do("insert into ncbi_taxa_name select * from $srcDB.ncbi_taxa_name");


my $other_genome_db_ids = $dbh->selectcol_arrayref("
    SELECT genome_db_id FROM genome_db
    WHERE name IN (\"".join("\", \"", @other_genome_db_names)."\")
        AND first_release IS NOT NULL AND last_release IS NULL");


#Take max of all the max_align values, used to select alignment blocks
$array_ref = $dbh->selectcol_arrayref("SELECT MAX(value) FROM method_link_species_set_tag WHERE tag='max_align'");
my $max_alignment_length = $array_ref->[0];

#my $method_link_id = $dbh->selectrow_array("
#    SELECT method_link_id FROM method_link
#    WHERE type = \"$method_link_type\"");

my $ref_genome_db_id = $dbh->selectrow_array("
    SELECT genome_db_id FROM genome_db
    WHERE name = \"$ref_genome_db_name\" AND first_release IS NOT NULL AND last_release IS NULL");

if ($do_pairwise) {
    my $pairwise_genome_db_ids = $dbh->selectcol_arrayref("
    SELECT genome_db_id FROM genome_db
    WHERE name IN (\"".join("\", \"", @pairwise_genome_db_names)."\")
        AND first_release IS NOT NULL AND last_release IS NULL");

    foreach my $genome_db_id (@$pairwise_genome_db_ids) {
	foreach my $seq_region (@seq_regions) {
	    my ($seq_region_name, $seq_region_start, $seq_region_end) = @{$seq_region};
	    my $lower_bound = $seq_region_start - $max_alignment_length;
	    my ($method_link_species_set_id, $species_set_id) = $dbh->selectrow_array(qq{
          SELECT
            mls.method_link_species_set_id, mls.species_set_id
          FROM
            $srcDB.method_link_species_set mls, $srcDB.species_set ss1, $srcDB.species_set ss2, method_link ml
          WHERE
            ss1.genome_db_id=$ref_genome_db_id AND
            ss2.genome_db_id=$genome_db_id AND
            ss1.species_set_id=ss2.species_set_id AND
            mls.species_set_id=ss1.species_set_id AND
            ml.method_link_id=mls.method_link_id AND
            ml.type in ($pairwise_method_link_type)
        });
	    if (!defined $method_link_species_set_id) {
		print "No valid mlss found between $ref_genome_db_id and $genome_db_id\n";
		next;
	    }
	    # Get dnafrag_id for the reference region
	    my ($dnafrag_id) = $dbh->selectrow_array(qq{
          SELECT
            dnafrag_id
          FROM
            $srcDB.dnafrag
          WHERE
            genome_db_id=$ref_genome_db_id AND
            name=$seq_region_name
        });
	    print "Dumping data for dnafrag $dnafrag_id (genome=$ref_genome_db_id; seq=$seq_region_name) vs. genome=$genome_db_id\n";
            
	    # Get the list of genomic_align_block_ids corresponding the the reference region
	    # Populate the genomic_align_block_id table
	    print " - dumping genomic_align entries $method_link_species_set_id\n";
	    
	    $dbh->do(qq{
          INSERT IGNORE INTO
            genomic_align
          SELECT
            *
          FROM
            $srcDB.genomic_align
          WHERE
            method_link_species_set_id=$method_link_species_set_id AND
            dnafrag_id = $dnafrag_id AND
            dnafrag_start<=$seq_region_end AND
            dnafrag_end>=$seq_region_start AND
            dnafrag_start>=$lower_bound
        });
       
	    # populate genomic_align_block table
	    print " - dumping genomic_align_block entries\n";
	    $dbh->do(qq{
          INSERT IGNORE INTO
            genomic_align_block
          SELECT
            gab.*
          FROM
            $srcDB.genomic_align_block gab, genomic_align ga
          WHERE
            gab.genomic_align_block_id=ga.genomic_align_block_id
        });
        
	    # populate genomic_align table
	    print " - dumping new genomic_align entries\n";
	    $dbh->do(qq{
          INSERT IGNORE INTO
            genomic_align
          SELECT
            ga.*
          FROM
            genomic_align_block gab, $srcDB.genomic_align ga
          WHERE
            gab.genomic_align_block_id=ga.genomic_align_block_id
        });
	}
    }

    # populate dnafrag table
    $dbh->do("insert ignore into dnafrag select d.* from genomic_align ga, $srcDB.dnafrag d where ga.dnafrag_id=d.dnafrag_id");
    
    foreach my $genome_db_id (@$other_genome_db_ids) {
	# populate synteny_region table
	print "Dumping synteny data (genome=$ref_genome_db_id vs. genome=$genome_db_id)\n";
	$dbh->do("insert into synteny_region select s.* from $srcDB.synteny_region s, $srcDB.dnafrag_region dr1, dnafrag d1, $srcDB.dnafrag_region dr2, dnafrag d2 where s.synteny_region_id=dr1.synteny_region_id and s.synteny_region_id=dr2.synteny_region_id and dr1.dnafrag_id=d1.dnafrag_id and dr2.dnafrag_id=d2.dnafrag_id and d1.genome_db_id=$ref_genome_db_id and d2.genome_db_id=$genome_db_id");
    }

    # populate dnafrag_region tables
    $dbh->do("insert into dnafrag_region select dr.* from synteny_region s, $srcDB.dnafrag_region dr where s.synteny_region_id=dr.synteny_region_id");
}


if ($do_pecan) {
    print "do pecan multiple alignment\n";

    my $multi_alignment_mlss_id = _run_query_from_method_link_type_species_set_name($pecan_alignment_method_link_type, $pecan_species_set_name);
    
    my $constrained_element_mlss_id = _run_query_from_method_link_type_species_set_name($constrained_element_method_link_type, $pecan_species_set_name);
    
    foreach my $seq_region (@seq_regions) {
	my ($seq_region_name, $seq_region_start, $seq_region_end) = @{$seq_region};
	my $lower_bound = $seq_region_start - $max_alignment_length;
	
	# Get dnafrag_id for the reference region
	my ($dnafrag_id) = $dbh->selectrow_array(qq{
           SELECT
             dnafrag_id
           FROM
             $srcDB.dnafrag
           WHERE
             genome_db_id=$ref_genome_db_id AND
             name=$seq_region_name
         });
	print "Dumping data for dnafrag $dnafrag_id (genome=$ref_genome_db_id; seq=$seq_region_name)\n";
	
	# Get the list of genomic_align_block_ids corresponding the the reference region
	# Populate the genomic_align_block_id table
	print " - dumping genomic_align entries\n";

	$dbh->do(qq{
           INSERT IGNORE INTO
             genomic_align
           SELECT
             *
           FROM
             $srcDB.genomic_align
           WHERE
             method_link_species_set_id=$multi_alignment_mlss_id AND
             dnafrag_id = $dnafrag_id AND
             dnafrag_start<=$seq_region_end AND
             dnafrag_end>=$seq_region_start AND
             dnafrag_start>=$lower_bound
         });

	# populate constrained element genomic_align_block table
	print " - dumping constrained element entries\n";
	$dbh->do(qq{
            INSERT IGNORE INTO
              constrained_element
            SELECT
              *
            FROM
              $srcDB.constrained_element
            WHERE
              method_link_species_set_id=$constrained_element_mlss_id AND
              dnafrag_id = $dnafrag_id AND
              dnafrag_start<=$seq_region_end AND
              dnafrag_end>=$seq_region_start AND
              dnafrag_start>=$lower_bound
          });

    }

    # populate genomic_align_block table
    print " - dumping genomic_align_block entries\n";
    $dbh->do(qq{
           INSERT IGNORE INTO
             genomic_align_block
           SELECT
             gab.*
           FROM
             $srcDB.genomic_align_block gab, genomic_align ga
           WHERE
             gab.genomic_align_block_id=ga.genomic_align_block_id
         });

    # populate genomic_align table
    print " - dumping new genomic_align entries\n";
    $dbh->do(qq{
           INSERT IGNORE INTO
             genomic_align
           SELECT
             ga.*
           FROM
             genomic_align_block gab, $srcDB.genomic_align ga
           WHERE
             gab.genomic_align_block_id=ga.genomic_align_block_id
         });

    #populate conservation_score table
print " - dumping conservation_score entries\n";
    $dbh->do(qq{
           INSERT IGNORE INTO
             conservation_score
           SELECT
             cs.*
           FROM
             $srcDB.conservation_score cs, genomic_align_block gab
           WHERE
             gab.genomic_align_block_id=cs.genomic_align_block_id
           AND
             gab.method_link_species_set_id=$multi_alignment_mlss_id
         });

    
}

if ($do_epo) {
    print "do EPO multiple alignment\n";
    
    my $multi_alignment_mlss_id = _run_query_from_method_link_type_species_set_name($epo_alignment_method_link_type, $epo_species_set_name);


    foreach my $seq_region (@seq_regions) {
	my ($seq_region_name, $seq_region_start, $seq_region_end) = @{$seq_region};
	my $lower_bound = $seq_region_start - $max_alignment_length;
	
	# Get dnafrag_id for the reference region
	my ($dnafrag_id) = $dbh->selectrow_array(qq{
           SELECT
             dnafrag_id
           FROM
             $srcDB.dnafrag
           WHERE
             genome_db_id=$ref_genome_db_id AND
             name=$seq_region_name
         });
	print "Dumping data for dnafrag $dnafrag_id (genome=$ref_genome_db_id; seq=$seq_region_name)\n";
	
	# Populate the genomic_align table
	print " - dumping genomic_align entries\n";

	$dbh->do(qq{
           INSERT IGNORE INTO
             genomic_align
           SELECT
             *
           FROM
             $srcDB.genomic_align
           WHERE
             method_link_species_set_id=$multi_alignment_mlss_id AND
             dnafrag_id = $dnafrag_id AND
             dnafrag_start<=$seq_region_end AND
             dnafrag_end>=$seq_region_start AND
             dnafrag_start>=$lower_bound
         });
       
	# populate genomic_align_block table with extant species
	print " - dumping genomic_align_block entries\n";
	$dbh->do(qq{
           INSERT IGNORE INTO
             genomic_align_block
           SELECT
             gab.*
           FROM
             $srcDB.genomic_align_block gab, genomic_align ga
           WHERE
             gab.genomic_align_block_id=ga.genomic_align_block_id
         });

	# populate genomic_align table with extant species
	print " - dumping new genomic_align entries\n";
	$dbh->do(qq{
           INSERT IGNORE INTO
             genomic_align
           SELECT
             ga.*
           FROM
             genomic_align_block gab, $srcDB.genomic_align ga
           WHERE
             gab.genomic_align_block_id=ga.genomic_align_block_id
         });
        	
	# populate genomic_align_tree table with extant and ancestral nodes
	print " - dumping genomic_align_tree entries\n";
	$dbh->do(qq{
           INSERT IGNORE INTO
             genomic_align_tree
           SELECT
             gat2.*
           FROM
             genomic_align ga
           JOIN  
             $srcDB.genomic_align_tree gat1
           USING
             (node_id)
           JOIN 
              $srcDB.genomic_align_tree gat2
           USING
              (root_id)
           GROUP BY
              gat2.node_id
         });

	# populate genomic_align table with ancestral species
	print " - dumping new genomic_align ancestral entries\n";
	$dbh->do(qq{
           INSERT IGNORE INTO
             genomic_align
           SELECT
             ga.*
           FROM
             genomic_align_tree 
           JOIN 
             $srcDB.genomic_align ga
           USING
             (node_id)
         });

	# populate genomic_align_block table with ancestral species
	print " - dumping genomic_align_block ancestral entries\n";
	$dbh->do(qq{
           INSERT IGNORE INTO
             genomic_align_block
           SELECT
             gab.*
           FROM
             genomic_align
           JOIN 
             $srcDB.genomic_align_block gab
           USING
             (genomic_align_block_id)
           WHERE
             gab.method_link_species_set_id=$multi_alignment_mlss_id
           GROUP BY
             genomic_align_block_id
         });

        #populate the dnafrag table
	print " - dumping new dnafrag ancestral entries\n";
        $dbh->do(qq{
           INSERT IGNORE INTO
             dnafrag
           SELECT
             dnafrag.*
           FROM
             $srcDB.dnafrag
           JOIN
             genomic_align USING (dnafrag_id)
	});
    }

    if ($destAncDB) {
        #Populate ancestral core database
        $dbh->do("use $destAncDB");
        
        print " - populate the coord_system table\n";
        $dbh->do(qq{
            INSERT INTO coord_system
             SELECT 
              coord_system.*
             FROM 
               $srcAncDB.coord_system
           });


        print " - dumping seq_region entries\n";
        $dbh->do(qq{
            INSERT INTO seq_region
             SELECT 
              seq_region.*
             FROM 
               $srcAncDB.seq_region
             JOIN
               $destDB.dnafrag USING (name)
             WHERE
               coord_system_name = \"$ancestral_coord_system_name\";
           });
        
        print " - dumping dna entries\n";
        $dbh->do(qq{
            INSERT INTO dna
            SELECT
              dna.*
            FROM
              $srcAncDB.dna
            JOIN
              seq_region USING (seq_region_id)
         });
        
        #Back to compara db
        $dbh->do("use $destDB");
    }
}

if ($do_epo_low_coverage) {
    print "do EPO multiple alignment\n";
        
    my $multi_alignment_mlss_id = _run_query_from_method_link_type_species_set_name($epo_low_coverage_alignment_method_link_type, $epo_species_set_name);

    my $constrained_element_mlss_id = _run_query_from_method_link_type_species_set_name($constrained_element_method_link_type, $epo_species_set_name);

    foreach my $seq_region (@seq_regions) {
	my ($seq_region_name, $seq_region_start, $seq_region_end) = @{$seq_region};
	my $lower_bound = $seq_region_start - $max_alignment_length;
	
	# Get dnafrag_id for the reference region
	my ($dnafrag_id) = $dbh->selectrow_array(qq{
           SELECT
             dnafrag_id
           FROM
             $srcDB.dnafrag
           WHERE
             genome_db_id=$ref_genome_db_id AND
             name=$seq_region_name
         });
	print "Dumping data for dnafrag $dnafrag_id (genome=$ref_genome_db_id; seq=$seq_region_name)\n";
	
	# Populate the genomic_align table
	print " - dumping genomic_align entries\n";

	$dbh->do(qq{
           INSERT IGNORE INTO
             genomic_align
           SELECT
             *
           FROM
             $srcDB.genomic_align
           WHERE
             method_link_species_set_id=$multi_alignment_mlss_id AND
             dnafrag_id = $dnafrag_id AND
             dnafrag_start<=$seq_region_end AND
             dnafrag_end>=$seq_region_start AND
             dnafrag_start>=$lower_bound
         });

        # populate constrained element genomic_align_block table
        print " - dumping constrained element entries\n";
        $dbh->do(qq{
            INSERT IGNORE INTO
              constrained_element
            SELECT
              *
            FROM
              $srcDB.constrained_element
            WHERE
              method_link_species_set_id=$constrained_element_mlss_id AND
              dnafrag_id = $dnafrag_id AND
              dnafrag_start<=$seq_region_end AND
              dnafrag_end>=$seq_region_start AND
              dnafrag_start>=$lower_bound
          });
        
    }       
    # populate genomic_align_block table with extant species
    print " - dumping genomic_align_block entries\n";
    $dbh->do(qq{
           INSERT IGNORE INTO
             genomic_align_block
           SELECT
             gab.*
           FROM
             $srcDB.genomic_align_block gab, genomic_align ga
           WHERE
             gab.genomic_align_block_id=ga.genomic_align_block_id
         });

    #Do not limit to just these species, or the ConservationScoreAdaptor tests will not work
        #my $gdb_str = join ",", $ref_genome_db_id, @$other_genome_db_ids;
    
    # populate genomic_align table with extant species
    print " - dumping new genomic_align entries\n";
    $dbh->do(qq{
           INSERT IGNORE INTO
             genomic_align
           SELECT
             ga.*
           FROM
             genomic_align_block gab, $srcDB.genomic_align ga
           WHERE
             gab.genomic_align_block_id=ga.genomic_align_block_id
         });
    
    # populate genomic_align_tree table with extant and ancestral nodes
    print " - dumping genomic_align_tree entries\n";
    $dbh->do(qq{
           INSERT IGNORE INTO
             genomic_align_tree
           SELECT
             gat2.*
           FROM
             genomic_align ga
           JOIN  
             $srcDB.genomic_align_tree gat1
           USING
             (node_id)
           JOIN 
              $srcDB.genomic_align_tree gat2
           USING
              (root_id)
           GROUP BY
              gat2.node_id
         });

    #populate conservation_score table
    print " - dumping conservation_score entries\n";
    $dbh->do(qq{
           INSERT IGNORE INTO
             conservation_score
           SELECT
             cs.*
           FROM
             $srcDB.conservation_score cs, genomic_align_block gab
           WHERE
             gab.genomic_align_block_id=cs.genomic_align_block_id
           AND
             gab.method_link_species_set_id=$multi_alignment_mlss_id
         });
}


# populate dnafrag table from entries in the genomic_align table
$dbh->do("insert ignore into dnafrag select d.* from genomic_align ga, $srcDB.dnafrag d where ga.dnafrag_id=d.dnafrag_id");


# Now output the seq_region files needed to create the corresponding core databases. Also do the ref_species seq_region_id in case there are duplicated regions
foreach my $genome_db_id ($ref_genome_db_id, @$other_genome_db_ids) {
    my $array_ref = $dbh->selectcol_arrayref("select name from genome_db where genome_db_id=$genome_db_id");
    my $species_name = lc($array_ref->[0]);
    $species_name =~ s/\s+/_/g;
    my $file = $species_name . ".seq_region_file";
    
    open F, ">$file" or
      die "can not open $file\n";
    print F "[\n";
    
    $array_ref = $dbh->selectall_arrayref("select d.name,g.dnafrag_start,g.dnafrag_end from dnafrag d, genomic_align g where d.dnafrag_id=g.dnafrag_id and d.genome_db_id=$genome_db_id order by d.name, g.dnafrag_start,g.dnafrag_end");
    
    my ($last_name, $last_start,$last_end);
    foreach my $row (@{$array_ref}) {
        my ($name,$start,$end) = @{$row};
        unless (defined $last_name && defined $last_start && defined $last_end) {
            ($last_name, $last_start,$last_end) = ($name,$start,$end);
            next;
        }
        if ($name eq $last_name && $start - $last_end < 100000) {
            $last_end = $end;
        } elsif (($name eq $last_name && $start - $last_end >= 100000) ||
                 $name ne $last_name) {
            print F "[\"$last_name\", $last_start,$last_end],\n";
            ($last_name, $last_start,$last_end) = ($name,$start,$end);
        }
    }
    print F "[\"$last_name\", $last_start,$last_end]\n]\n";
    
    close F;
}
$dbh->disconnect();

print "Test genome database $destDB created\n";

#cmd to dump .sql and .txt files
#mysqldump -hia64f -uensadmin -p${ENSADMIN_PSW} -P3306 --socket=/mysql/data_3306/mysql.sock -T ./ abel_core_test

sub _run_query_from_method_link_type_species_set_name {
    my ($method_link_type, $species_set_name) = @_;
    my $method_link_species_set_id;
    
    $method_link_species_set_id = $dbh->selectrow_array(qq{
            SELECT
              method_link_species_set_id
            FROM
              $srcDB.method_link_species_set mlss
            JOIN
              $srcDB.species_set_header USING (species_set_id)
            JOIN
              $srcDB.method_link USING (method_link_id) 
            WHERE
              species_set_header.name = \"$species_set_name\"
              AND method_link.type = \"$method_link_type\"
            });     
    
    return $method_link_species_set_id;
}

#Based on routine from MethodLinkSpeciesSetAdaptor.pm
sub _run_query_from_method_link_id_genome_db_ids {
    my ($method_link_id, $genome_db_ids) = @_;
    my $method_link_species_set_id;
    
    my $species_set_id = _get_species_set_id_from_genome_db_ids($genome_db_ids);
    
    if ($species_set_id) {
	$method_link_species_set_id = $dbh->selectrow_array(qq{
            SELECT
              method_link_species_set_id
            FROM
              $srcDB.method_link_species_set mlss
            WHERE
              species_set_id = \"$species_set_id\"
              AND method_link_id = \"$method_link_id\"
            });     
    }
    
    return $method_link_species_set_id;
}

#Based on routine from MethodLinkSpeciesSetAdaptor.pm
sub _get_species_set_id_from_genome_db_ids {
    my ($genome_db_ids) = @_;
    my $species_set_id;

    ## Fetch all the species_set which contain all these species_set_ids
    
    my $all_rows = $dbh->selectall_arrayref(qq{
          SELECT
            species_set_id,
            COUNT(*) as count
          FROM
            $srcDB.species_set
          WHERE
            genome_db_id in (}.join(",", @$genome_db_ids).qq{)
          GROUP BY species_set_id
          HAVING count = }.(scalar(@$genome_db_ids)));
    
    if (!@$all_rows) {
	return undef;
    }
    my $species_set_ids = [map {$_->[0]} @$all_rows];
    
    
    ## Keep only the species_set which does not contain any other genome_db_id
    $all_rows = $dbh->selectall_arrayref(qq{
          SELECT
            species_set_id,
            COUNT(*) as count
          FROM
            $srcDB.species_set
          WHERE
            species_set_id in (}.join(",", @$species_set_ids).qq{)
          GROUP BY species_set_id
          HAVING count = }.(scalar(@$genome_db_ids)));

    if (!@$all_rows) {
	return undef;
    } elsif (@$all_rows > 1) {
	warning("Several species_set_ids have been found for genome_db_ids (".
		join(",", @$genome_db_ids)."): ".join(",", map {$_->[0]} @$all_rows));
    }
    $species_set_id = $all_rows->[0]->[0];
    
    return $species_set_id;
}


exit 0;
