#!/usr/bin/env perl

# File name: CreateComparaTestDatabase.pl
#
# Given a source and destination database this script will create 
# a ensembl compara database on the same mysql server as the source and populate it
#

use strict;
use warnings;

use Getopt::Long;
use DBI;

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
my $do_proteins = 0;

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

my $rc = 0xffff & system(
  "mysqldump -p$pass -u $user -h $host -P $port --no-data $srcDB | " .
  "mysql -p$pass -u $user -h $host -P $port $destDB");

if($rc != 0) {
  $rc >>= 8;
  die "mysqldump and insert failed with return code: $rc";
}

if ($destAncDB) {
    my $rc = 0xffff & system(
                             "mysqldump -p$pass -u $user -h $host -P $port --no-data $srcAncDB | " .
                             "mysql -p$pass -u $user -h $host -P $port $destAncDB");
    
    if($rc != 0) {
        $rc >>= 8;
        die "mysqldump and insert failed with return code: $rc";
    }
}


$dbh->do("use $destDB");

#Populate method_link
$dbh->do("insert into method_link select * from $srcDB.method_link");

#Populate method_link_species_set (take all so more data can be added at a later date)
$dbh->do("insert into method_link_species_set select * from $srcDB.method_link_species_set");

#Populate method_link_species_set_tag (take all so more data can be added at a later date)
$dbh->do("INSERT INTO method_link_species_set_tag SELECT * FROM $srcDB.method_link_species_set_tag");

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
        and assembly_default = 1");


#Take max of all the max_align values, used to select alignment blocks
$array_ref = $dbh->selectcol_arrayref("SELECT MAX(value) FROM method_link_species_set_tag WHERE tag='max_align'");
my $max_alignment_length = $array_ref->[0];

#my $method_link_id = $dbh->selectrow_array("
#    SELECT method_link_id FROM method_link
#    WHERE type = \"$method_link_type\"");

my $ref_genome_db_id = $dbh->selectrow_array("
    SELECT genome_db_id FROM genome_db
    WHERE name = \"$ref_genome_db_name\" and assembly_default = 1");

if ($do_pairwise) {
    my $pairwise_genome_db_ids = $dbh->selectcol_arrayref("
    SELECT genome_db_id FROM genome_db
    WHERE name IN (\"".join("\", \"", @pairwise_genome_db_names)."\")
        and assembly_default = 1");

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

if ($do_proteins) {
    #These need setting
    my $protein_genome_db_ids;
    my $method_link_id;

    foreach my $genome_db_id (@$protein_genome_db_ids) {
	foreach my $seq_region (@seq_regions) {
	    my ($seq_region_name, $seq_region_start, $seq_region_end) = @{$seq_region};
	    my $lower_bound = $seq_region_start - $max_alignment_length;
	    my ($method_link_species_set_id, $species_set_id) = $dbh->selectrow_array(qq{
          SELECT
            mls.method_link_species_set_id, mls.species_set_id
          FROM
            $srcDB.method_link_species_set mls, $srcDB.species_set ss1, $srcDB.species_set ss2
          WHERE
            ss1.genome_db_id=$ref_genome_db_id AND
            ss2.genome_db_id=$genome_db_id AND
            ss1.species_set_id=ss2.species_set_id AND
            mls.species_set_id=ss1.species_set_id AND
            mls.method_link_id=$method_link_id
        });

	    # populate peptide_align_feature table
	    print " - populating peptide_align_feature table\n";
	    $dbh->do("insert into peptide_align_feature select paf.* from $srcDB.peptide_align_feature paf, $srcDB.member m where paf.qmember_id = m.member_id and hgenome_db_id=$genome_db_id and m.genome_db_id=$ref_genome_db_id and m.chr_name=$seq_region_name and m.chr_start<$seq_region_end and m.chr_end>$seq_region_start");
	    $dbh->do("insert into peptide_align_feature select paf.* from $srcDB.peptide_align_feature paf, $srcDB.member m where paf.hmember_id = m.member_id and qgenome_db_id=$genome_db_id and m.genome_db_id=$ref_genome_db_id and m.chr_name=$seq_region_name and m.chr_start<$seq_region_end and m.chr_end>$seq_region_start");
    
    # populate homology table for pairwise homologues
    print " - populating homology table\n";
    ($method_link_species_set_id) = $dbh->selectrow_array(qq{
          SELECT
            mls.method_link_species_set_id
          FROM
            $srcDB.method_link_species_set mls, $srcDB.method_link ml
          WHERE
            mls.species_set_id=$species_set_id AND
            mls.method_link_id=ml.method_link_id AND
            ml.type="ENSEMBL_ORTHOLOGUES"
        });

	  $dbh->do("insert into homology select h.* from $srcDB.homology h,$srcDB.homology_member hm1, $srcDB.member m1, $srcDB.homology_member hm2, $srcDB.member m2 where h.homology_id=hm1.homology_id and h.homology_id=hm2.homology_id and hm1.member_id=m1.member_id and hm2.member_id=m2.member_id and m1.genome_db_id=$ref_genome_db_id and m2.genome_db_id=$genome_db_id and m1.chr_name=$seq_region_name and m1.chr_start<$seq_region_end and m1.chr_end>$seq_region_start and h.method_link_species_set_id=$method_link_species_set_id");
	    
	    # populate family table
	    print " - populating family table\n";
	    $dbh->do("insert ignore into family select f.* from $srcDB.family f, $srcDB.family_member fm, $srcDB.member m where f.family_id=fm.family_id and fm.member_id=m.member_id and m.genome_db_id=$ref_genome_db_id and m.chr_name=$seq_region_name and m.chr_start<$seq_region_end and m.chr_end>$seq_region_start");
	    
	    print " - done\n";
	}
    }

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

if ($do_proteins) {
    foreach my $seq_region (@seq_regions) {
	my ($seq_region_name, $seq_region_start, $seq_region_end) = @{$seq_region};
	print "Dumping data for dnafrag (genome=$ref_genome_db_id; seq=$seq_region_name)\n";
	print " - populating protein trees\n";
	## Get the fisrt all the leaves which correspond to members in this region
	my $num = $dbh->do("insert ignore into protein_tree_node select ptn.* from $srcDB.protein_tree_node ptn, $srcDB.protein_tree_member ptm, $srcDB.member m WHERE ptn.node_id=ptm.node_id and ptm.member_id=m.member_id and m.genome_db_id=$ref_genome_db_id and m.chr_name=$seq_region_name and m.chr_start<$seq_region_end and m.chr_end>$seq_region_start");
	while ($num > 0) {
	    ## Add parent nodes until we hit the root
	    $num = $dbh->do("insert ignore into protein_tree_node select ptn1.* from $srcDB.protein_tree_node ptn1, protein_tree_node ptn2 WHERE ptn1.node_id=ptn2.parent_id and ptn2.parent_id > 1");
	}
	## Add all the nodes underlying the roots
	$dbh->do("insert ignore into protein_tree_node select ptn1.* from $srcDB.protein_tree_node ptn1, protein_tree_node ptn2 WHERE ptn2.parent_id = 1 and ptn1.left_index BETWEEN ptn2.left_index and ptn2.right_index");
	## Add all relevant entries in the protein_tree_member table
	$dbh->do("insert ignore into protein_tree_member select ptm.* from $srcDB.protein_tree_member ptm, protein_tree_node ptn2 WHERE ptn2.node_id = ptm.node_id");
	## Add all relevant entries in the protein_tree_tag table
	$dbh->do("insert ignore into protein_tree_tag select ptt.* from $srcDB.protein_tree_tag ptt, protein_tree_node ptn2 WHERE ptn2.node_id = ptt.node_id");
	
	print " - populating homology table with self-data\n";
	my ($species_set_id) = $dbh->selectrow_array(qq{
        SELECT
          ss1.species_set_id
        FROM
          $srcDB.species_set ss1, $srcDB.species_set ss2
        WHERE
          ss1.species_set_id=ss2.species_set_id AND
          ss1.genome_db_id=$ref_genome_db_id
        GROUP BY ss1.species_set_id HAVING count(*) = 1
      });
	my ($method_link_species_set_id) = $dbh->selectrow_array(qq{
        SELECT
          mlss.method_link_species_set_id
        FROM
          $srcDB.method_link_species_set mlss, $srcDB.method_link ml
        WHERE
          mlss.species_set_id=$species_set_id AND
          mlss.method_link_id=ml.method_link_id AND
          ml.type="ENSEMBL_PARALOGUES"
      });

	$dbh->do("insert into homology select distinct h.* from $srcDB.homology h,$srcDB.homology_member hm1, $srcDB.member m1, $srcDB.homology_member hm2, $srcDB.member m2 where h.homology_id=hm1.homology_id and h.homology_id=hm2.homology_id and hm1.member_id=m1.member_id and hm2.member_id=m2.member_id and m1.genome_db_id=$ref_genome_db_id and m2.genome_db_id=$ref_genome_db_id and m1.chr_name=$seq_region_name and m1.chr_start<$seq_region_end and m1.chr_end>$seq_region_start and m1.member_id <> m2.member_id and h.method_link_species_set_id=$method_link_species_set_id");

	print " - done\n";
    }
    
    # populate homology_member table
    $dbh->do("insert into homology_member select hm.* from homology h, $srcDB.homology_member hm where h.homology_id=hm.homology_id");
    
    # populate family_member table
    $dbh->do("insert into family_member select fm.* from family f, $srcDB.family_member fm where f.family_id=fm.family_id");
    
    # populate member table
    $dbh->do("insert ignore into member select m.* from family_member fm, $srcDB.member m where fm.member_id=m.member_id");
    $dbh->do("insert ignore into member select m.* from homology_member hm, $srcDB.member m where hm.member_id=m.member_id");
    $dbh->do("insert ignore into member select m.* from homology_member hm, $srcDB.member m where hm.peptide_member_id=m.member_id");

    # populate sequence table
    $dbh->do("insert ignore into sequence select s.* from member m, $srcDB.sequence s where m.sequence_id=s.sequence_id");
    
    # populate taxon table
    # $dbh->do("insert ignore into taxon select t.* from member m, $srcDB.taxon t where m.taxon_id=t.taxon_id");
# $dbh->do("insert ignore into taxon select t.* from genome_db g, $srcDB.taxon t where g.taxon_id=t.taxon_id");
    
    # populate the method_link_species.....not it is needed with the current schema
    # it will when moving to the multiple alignment enabled schema.
    
    # need to do something a bit more clever here to just add what we really
    # method_link_species_set entries from genomic_align_block
    #$dbh->do("insert into method_link_species_set select mlss.* from $srcDB.method_link_species_set mlss, genomic_align_block gab where gab.method_link_species_set_id=mlss.method_link_species_set_id group by mlss.method_link_species_set_id");
    
    # method_link_species_set entries from homology
    #$dbh->do("insert into method_link_species_set select mlss.* from $srcDB.method_link_species_set mlss, homology h where h.method_link_species_set_id=mlss.method_link_species_set_id group by mlss.method_link_species_set_id");
    
    # method_link_species_set entries from family
    #$dbh->do("insert into method_link_species_set select mlss.* from $srcDB.method_link_species_set mlss, family f where f.method_link_species_set_id=mlss.method_link_species_set_id group by mlss.method_link_species_set_id");

    # method_link_species_set entries from synteny_region/dnafrag_region
    #$dbh->do("insert into method_link_species_set select mlss.* from $srcDB.method_link_species_set mlss, synteny_region sr where sr.method_link_species_set_id=mlss.method_link_species_set_id group by mlss.method_link_species_set_id");
    
    # species_set entries
    #$dbh->do("insert into species_set select ss.* from method_link_species_set mlss left join $srcDB.species_set ss using (species_set_id) group by ss.species_set_id, ss.genome_db_id");

    #conservation_score entry
    #$dbh->do("insert into method_link_species_set select mlss.* from $srcDB.method_link_species_set mlss, $srcDB.method_link ml where ml.method_link_id=mlss.method_link_id and ml.type = \"$conservation_score_method_link_type\"");
    
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
#/usr/local/ensembl/mysql/bin/mysqldump -hia64f -uensadmin -p${ENSADMIN_PSW} -P3306 --socket=/mysql/data_3306/mysql.sock -T ./ abel_core_test

sub _run_query_from_method_link_type_species_set_name {
    my ($method_link_type, $species_set_name) = @_;
    my $method_link_species_set_id;
    
    $method_link_species_set_id = $dbh->selectrow_array(qq{
            SELECT
              method_link_species_set_id
            FROM
              $srcDB.method_link_species_set mlss
            JOIN
              $srcDB.species_set_tag USING (species_set_id)
            JOIN
              $srcDB.method_link USING (method_link_id) 
            WHERE
              species_set_tag.tag = "name" AND
              species_set_tag.value = \"$species_set_name\"
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
