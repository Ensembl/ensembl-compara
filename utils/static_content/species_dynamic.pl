#!/usr/local/bin/perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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


##############################################################################
#
# SCRIPT FOR ENTERING CONTENT IN THE META TABLES FOR ENSEMBL WHICH WILL BE USED 
# FOR GENERATION OF 'ASSEMBLY AND GENEBUILD' PAGE AND 'TOP InterPro HITS' PAGE
# Default is to do all configured species, or pass an array of
# species names (typically in Genus_species format)
#
##############################################################################


##---------------------------- CONFIGURATION ---------------------------------

use strict;
use warnings;
use Carp;
use Data::Dumper qw( Dumper );


use FindBin qw($Bin);
use File::Basename qw( dirname );

use Pod::Usage;
use Getopt::Long;

use vars qw( $SERVERROOT $PLUGIN_ROOT $SCRIPT_ROOT $DEBUG $FUDGE $NOINTERPRO $NOSUMMARY $help $info @user_spp $host $user $pass $port $update_meta $generate_pages);

BEGIN{
  &GetOptions( 
  "dbhost|host=s",     \$host,
  "dbuser|user=s",     \$user,
  "dbpass|pass=s",     \$pass,
  "dbport|port=i",     \$port,
  "update_meta=i",     \$update_meta,        #if set to 1 the script updates the current records in meta tables with new values for each of the existing keys
  "gen_pages=i",       \$generate_pages,     #if set to 1 the script  only generates the web pages without changing the content of meta table
               'help'      => \$help,
               'info'      => \$info,
               'species=s' => \@user_spp,
               'debug'     => \$DEBUG,
               'nointerpro'=> \$NOINTERPRO,
               'nosummary' => \$NOSUMMARY,
               'plugin_root=s' => \$PLUGIN_ROOT,
	     );

  pod2usage(-verbose => 2) if $info;
  pod2usage(1) if $help;

  $SCRIPT_ROOT = dirname( $Bin );
  ($SERVERROOT = $SCRIPT_ROOT) =~ s#/utils##;
  $PLUGIN_ROOT ||= $SERVERROOT.'/public-plugins/ensembl';
  
  unless( $PLUGIN_ROOT =~ /^\// ){ # Relative path
    $PLUGIN_ROOT = $SERVERROOT.'/'.$PLUGIN_ROOT;
  }
  unless( -d $PLUGIN_ROOT ){
    pod2usage("plugin_root $PLUGIN_ROOT is not a directory");
  }

  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

use constant STATS_PATH       => qq(%s/htdocs/ssi/species/);

use Bio::EnsEMBL::DBLoader;
use EnsEMBL::Web::DBSQL::DBConnection;

##---------------------------- SPECIES INFO ---------------------------------

use EnsEMBL::Web::SpeciesDefs;

my $SD = EnsEMBL::Web::SpeciesDefs->new();
my $pre = $PLUGIN_ROOT =~ m#sanger-plugins/pre# ? 1 : 0;
$NOINTERPRO = 1 if $pre;

# get a list of valid species for this release
my $release_id =  $SD->ENSEMBL_VERSION;
my @release_spp = $SD->valid_species;
my %species_check;
foreach my $sp (@release_spp) {
  $species_check{$sp}++;
}
                                                                                
# check validity of user-provided species
my @valid_spp;
if (@user_spp) {
    foreach my $sp (@user_spp) {
        if ($species_check{$sp}) {
            push (@valid_spp, $sp);
        }
        else {
            carp "Species $sp is not configured for release $release_id - omitting!\n";
        }
    }
}
else {
  @valid_spp = @release_spp;
}

@valid_spp || pod2usage("$0: Need a species" );

$host || die( "No HOST param" );
$port || die( "No PORT param" );
$user || die( "No USER param (DATABASE WRITE USER needed)" );
$pass || die( "No PASS param (DATABASE WRITE PASS needed)" );
$generate_pages ||= 0;

##---------------------------- CREATE STATS ---------------------------------

my $dbconn = EnsEMBL::Web::DBSQL::DBConnection->new(undef, $SD);
  
my $dsn = "DBI:mysql:host=$host;port=$port";
my $db2 = DBI->connect( $dsn, $user, $pass, { RaiseError => 1 } ) ||
      die( "Could not connect to host=$host, user=$user, pass=$pass" );



unless ($generate_pages)  {

foreach my $spp (@valid_spp) {

## CONNECT TO APPROPRIATE DATABASES
  my $db;
  my @meta_queries;
  my (@meta_keys, @meta_vals);
 
  eval {
    my $databases = $dbconn->get_databases_species($spp, "core");
    $db =  $databases->{'core'} || 
      die( "Could not retrieve core database for $spp" );
  };

  #print Dumper($db);
 
  if( $@ ) {
    print STDERR "FATAL: $@";
    exit(0);
  }

  my $var_db;
  eval {
    my $databases = $dbconn->get_databases_species($spp, "variation");
    $var_db =  $databases->{'variation'} || undef;
  };


  my $sp_id = $SD->get_config($spp, 'SPECIES_META_ID') || '';
  $sp_id || warn "[ERROR] $spp missing SpeciesDefs->SPECIES_META_ID!";
 

  if ($NOSUMMARY) {
    
    do_interpro($db, $spp, $db2, $update_meta, $sp_id, '1');
  }
  else {

    ### GET ASSEMBLY AND GENEBUILD INFO
    # Assembly ID ->should be in meta table
    my $db_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($spp, "core");
    my $meta_container = $db_adaptor->get_MetaContainer();

    my( $a_id ) = ( @{$meta_container->list_value_by_key('assembly.name')},
                    @{$meta_container->list_value_by_key('assembly.default')});
    warn "[ERROR] $spp "
        ."missing both meta->assembly.name and meta->assembly.default"
        unless( $a_id );

    my $a_date  = $SD->get_config($spp, 'ASSEMBLY_DATE') || '';
    $a_date || warn "[ERROR] $spp missing SpeciesDefs->ASSEMBLY_DATE!";
    my $b_start  = $SD->get_config($spp, 'GENEBUILD_START') || '';
    $b_start || warn "[ERROR] $spp missing SpeciesDefs->GENEBUILD_START!";
    my $b_release  = $SD->get_config($spp, 'GENEBUILD_RELEASE') || '';
    $b_release || warn "[ERROR] $spp missing SpeciesDefs->GENEBUILD_RELEASE!";
    my $b_latest  = $SD->get_config($spp, 'GENEBUILD_LATEST') || '';
    $b_latest || warn "[ERROR] $spp missing SpeciesDefs->GENEBUILD_LATEST!";
    my $b_id    = $SD->get_config($spp, 'GENEBUILD_BY') || '';
    $b_id   || warn "[ERROR] $spp missing SpeciesDefs->GENEBUILD_BY!" unless $pre;
    my $b_method  = ucfirst($SD->get_config($spp, 'GENEBUILD_METHOD')) || '';
    $b_method =~ s/_/ /g;
    $b_method   || warn "[ERROR] $spp missing SpeciesDefs->GENEBUILD_METHOD!" unless $pre;

    my $data_version = $SD->get_config($spp, 'SPECIES_RELEASE_VERSION');
    my $db_id = $release_id;
		$db_id .= '.'.$data_version unless $pre;
    #print "Version $data_version\n";

##----------------------- NASTY RAW SQL STUFF! ------------------------------

    ## logicnames for valid genes
    my $genetypes = "'ensembl', 'ensembl_havana_gene', 'havana', 'ensembl_projection',
      'ensembl_ncRNA', 'ncRNA', 'tRNA', 'pseudogene', 'retrotransposed', 'human_ensembl_proteins',
      'flybase', 'wormbase', 'vectorbase', 'sgd', 'HOX', 'CYT', 'GSTEN'";

    my $authority = $SD->get_config($spp, 'AUTHORITY');
    if( $authority ){
      $genetypes .= sprintf(", '%s'",$authority);
    }

    my ($known, $novel, $proj, $pseudo, $rna, $ig_segments, $exons, $transcripts, $snps);  

=pod
    ## HACK TO ALLOW US TO DO DIFFERENT TOTALS FOR HUMAN
    if ($spp eq 'Homo_sapiens' && $FUDGE) { ## get gene counts from attrib table
    
      ## GET ALL SEQUENCE REGION IDS FOR CHROMOSOMES
      my @chr_list = @{$SD->ENSEMBL_CHROMOSOMES};
      my @seqreg_ids;
      foreach my $chr (@chr_list) {
        my ($seqreg_id) = &query( $db,
          "SELECT seq_region_id
          FROM seq_region
          WHERE name = '$chr'");
        push @seqreg_ids, $seqreg_id;
      }
      print "Sequence region ids: @seqreg_ids\n" if $DEBUG;

      foreach my $id (@seqreg_ids) {
        my ($count) = &query( $db,
          "SELECT value
          FROM seq_region_attrib as s, attrib_type as a
          WHERE s.attrib_type_id = a.attrib_type_id
          AND seq_region_id = '$id' AND a.code = 'GeneNo_knwCod'");
        $known += $count;
      }
      print "Known Genes: $known\n" if $DEBUG;
                                                                                
      foreach my $id (@seqreg_ids) {
        my ($count) = &query( $db,
          "SELECT s.value
          FROM seq_region_attrib as s, attrib_type as a
          WHERE s.attrib_type_id = a.attrib_type_id
          AND seq_region_id = '$id' AND a.code = 'GeneNo_novCod'");
        $novel += $count;
      }

      foreach my $id (@seqreg_ids) {
        my ($count) = &query( $db,
          "SELECT s.value
          FROM seq_region_attrib as s, attrib_type as a
          WHERE s.attrib_type_id = a.attrib_type_id
          AND seq_region_id = '$id' AND a.code = 'GeneNo_pseudo'");
        $pseudo += $count;
      }
      print "Pseudogenes: $known" if $DEBUG;
                                                                                
      foreach my $id (@seqreg_ids) {
        my ($count) = &query( $db,
          "SELECT value
          FROM seq_region_attrib as s, attrib_type as a
          WHERE s.attrib_type_id = a.attrib_type_id
          AND seq_region_id = '$id' AND a.code REGEXP 'GeneNo_[a-z]*RNA'");
        $rna += $count;
      }

    }
=cut

    unless ($pre) { 
      ($known) = &query( $db,
        "select count(*)
        from gene
        where biotype = 'protein_coding' 
        and status = 'KNOWN'
        ");    
      print "Known Genes:$known\n" if $DEBUG;

      ($proj) = &query( $db,
        "select count(*)
        from gene
        where biotype = 'protein_coding'
        and status = 'KNOWN_BY_PROJECTION'
        ");
      print "Projected Genes:$proj\n" if $DEBUG;

      ( $novel ) = &query( $db,
        "select count(*)
        from gene
        where biotype = 'protein_coding' 
        and status = 'NOVEL'
        ");    
      print "Novel Genes:$novel\n" if $DEBUG;

      ( $pseudo ) = &query( $db,
        "select count(*)
        from gene
        where biotype like '%pseudogene' 
        or biotype = 'retrotransposed'
        ");    
      print "Pseudogenes:$pseudo\n" if $DEBUG;

      ( $rna ) = &query( $db,
        'select count(*)
        from gene
        where biotype regexp "[\w]*RNA$" 
        ');    
      print "RNA genes:$rna\n" if $DEBUG;

      ( $ig_segments )= &query( $db,
        "select count(distinct g.gene_id)
        from gene g, analysis a
        where g.analysis_id = a.analysis_id
        and a.logic_name = 'ensembl_IG_gene'
        ");
      print "Segments:$ig_segments\n" if $DEBUG;

    }

    ## DO OTHER RAW QUERIES
    my( $genpept ) = &query( $db,
    "select count( distinct p.prediction_transcript_id )
      from prediction_transcript p, analysis a
      where p.analysis_id = a.analysis_id and a.logic_name = 'Genscan'");
    print "Genscans:$genpept\n" if $DEBUG;

    my( $genfpept ) = &query( $db,
    "select count( distinct p.prediction_transcript_id )
      from prediction_transcript p, analysis a
      where p.analysis_id = a.analysis_id and a.logic_name = 'Genefinder'");
    print "Genefinder:$genfpept\n" if $DEBUG;

    my( $fgenpept ) = &query( $db,
    "select count( distinct p.prediction_transcript_id )
      from prediction_transcript p, analysis a
      where p.analysis_id = a.analysis_id and a.logic_name like '%fgenesh%'");
    print "Fgenesh:$fgenpept\n" if $DEBUG;

    unless ($pre) {
      ( $transcripts )= &query( $db,
      "select count(distinct t.transcript_id)
        from transcript t, gene g, analysis a
        where t.gene_id = g.gene_id
        and g.analysis_id = a.analysis_id
        and a.logic_name in ($genetypes)
        ");
      print "Transcripts:$transcripts\n" if $DEBUG;

      ( $exons )= &query( $db,
      "select count(distinct et.exon_id)
      from exon_transcript et, transcript t, gene g, analysis a
      where et.transcript_id = t.transcript_id
      and  t.gene_id = g.gene_id
      and g.analysis_id = a.analysis_id
      and a.logic_name in ($genetypes)
      ");
      print "Exons:$exons\n" if $DEBUG;

      $snps = 0;
      if ($var_db) {
        ($snps) = &query ( $var_db,
          "SELECT COUNT(DISTINCT variation_id) FROM variation_feature",
          );
        print "SNPs:$snps\n" if $DEBUG;
      }
    }

  ## Total number of base pairs

    my ( $bp ) = &query( $db, "SELECT SUM(LENGTH(sequence)) FROM dna");    

    print "Total base pairs: $bp.\n" if $DEBUG;

  ## Golden path length

    my ( $gpl ) = &query( $db,
      "SELECT sum(length)
        FROM seq_region
        WHERE seq_region_id IN (
          SELECT sr.seq_region_id FROM seq_region sr
            LEFT JOIN assembly_exception ae ON ae.seq_region_id = sr.seq_region_id
            LEFT JOIN seq_region_attrib sra ON sr.seq_region_id = sra.seq_region_id
            LEFT JOIN attrib_type at ON sra.attrib_type_id = at.attrib_type_id
            WHERE at.code = 'toplevel'
            AND (ae.exc_type != 'HAP' OR ae.exc_type IS NULL)
        )"
    );

    print "Golden path length: $gpl.\n" if $DEBUG;

  ##--------------------------- DO INTERPRO STATS -----------------------------

    my $ip_tables = do_interpro($db, $spp, $db2, $update_meta, $sp_id, '1') unless $NOINTERPRO;

  ##--------------------------- OUTPUT STATS TABLE -----------------------------
  $bp = thousandify($bp);
  $gpl = thousandify($gpl);

  my $assembly = ($a_date && ($a_date !~ /blank/)) ? "$a_id, $a_date" : $a_id;
  push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Summary.Assembly', '$assembly')";
  push @meta_keys, 'stat.Summary.Assembly';  
  push @meta_vals, $assembly;

  push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Summary.Database version', '$db_id')";
  push @meta_keys, 'stat.Summary.Database version';
  push @meta_vals, "$db_id";

  push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Summary.Base Pairs', '$bp')";     
  push @meta_keys, 'stat.Summary.Base Pairs';
  push @meta_vals, "$bp";

  push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Summary.Golden Path Length', '$gpl')";
  push @meta_keys, 'stat.Summary.Golden Path Length';
  push @meta_vals, "$gpl";    

  unless ($pre) {

      push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Summary.Genebuild by', '$b_id')";
      push @meta_keys, 'stat.Summary.Genebuild by';
      push @meta_vals, "$b_id";

      push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Summary.Genebuild method', '$b_method')";
      push @meta_keys, 'stat.Summary.Genebuild method';
      push @meta_vals, "$b_method";

      push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Summary.Genebuild started', '$b_start')";
      push @meta_keys, 'stat.Summary.Genebuild started';
      push @meta_vals, "$b_start";
      
      push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Summary.Genebuild released', '$b_release')";
      push @meta_keys, 'stat.Summary.Genebuild released';
      push @meta_vals, "$b_release";

      push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Summary.Genebuild last updated/patched', '$b_latest')";
      push @meta_keys, 'stat.Summary.Genebuild last updated/patched';  
      push @meta_vals, "$b_latest";

      if ($known) {
        $known = thousandify($known);
	push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Gene counts.Known protein-coding genes', '$known')";
        push @meta_keys, 'stat.Gene counts.Known protein-coding genes';
        push @meta_vals, "$known";
      }

      if ($proj) {
        $proj = thousandify($proj);
 	push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Gene counts.Projected protein-coding genes', '$proj')";
        push @meta_keys, 'stat.Gene counts.Projected protein-coding genes';
        push @meta_vals, "$proj";
      }


      if ($novel) {
        $novel = thousandify($novel);
	push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Gene counts.Novel protein-coding genes', '$novel')";
        push @meta_keys, 'stat.Gene counts.Novel protein-coding genes';
        push @meta_vals, "$novel";
      }

      if ($pseudo) {
        $pseudo = thousandify($pseudo);
       	push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Gene counts.Pseudogenes', '$pseudo')";
        push @meta_keys, 'stat.Gene counts.Pseudogenes';        
        push @meta_vals, "$pseudo";
      }

      if ($rna) {
        $rna = thousandify($rna);
	push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Gene counts.RNA genes', '$rna')"; 
        push @meta_keys, 'stat.Gene counts.RNA genes';        
        push @meta_vals, "$rna";
      }

      if ($ig_segments) {
        $ig_segments = thousandify($ig_segments);
	push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Gene counts.Immunoglobulin/T-cell receptor gene segments', '$ig_segments')";
        push @meta_keys, 'stat.Gene counts.Immunoglobulin/T-cell receptor gene segments';
        push @meta_vals, "$ig_segments";
      }

      $exons = thousandify($exons);
      push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Gene counts.Gene exons', '$exons')";      
      push @meta_keys, 'stat.Gene counts.Gene exons';
      push @meta_vals, "$exons";

      $transcripts = thousandify($transcripts);
      push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Gene counts.Gene transcripts', '$transcripts')";
      push @meta_keys, 'stat.Gene counts.Gene transcripts';
      push @meta_vals, "$transcripts";
    }

    if ($genpept){
      $genpept = thousandify($genpept);
      push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Other.Genscan gene predictions', '$genpept')";
      push @meta_keys, 'stat.Other.Genscan gene predictions';
      push @meta_vals, "$genpept";
    }

    if ($genfpept){
      $genfpept = thousandify($genfpept);
      push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Other.Genefinder gene predictions', '$genfpept')";
      push @meta_keys, 'stat.Other.Genefinder gene predictions';
      push @meta_vals, "$genfpept";
    }

    if ($fgenpept){
      $fgenpept = thousandify($fgenpept);
      push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Other.FGENESH gene predictions', '$fgenpept')";
      push @meta_keys, 'stat.Other.FGENESH gene predictions';
      push @meta_vals, "$fgenpept";
    }

    if ($snps) {
      $snps = thousandify($snps);
      push @meta_queries, "insert into meta (meta_key, meta_value) values ('stat.Other.SNPs', '$snps')";
      push @meta_keys, 'stat.Other.SNPs';
      push @meta_vals, "$snps";
    }
  }

  my $key_exist;
  my $useres = $db2->do("use ".$db->{'_dbc'}->{'_dbname'});
  

  my $table_exist = '';
  ($table_exist) = &query( $db,
			   "show tables like 'stats'");

  if($table_exist ne 'stats') { 

                $db2->do("CREATE TABLE stats(                                                                                                                                                              
                                           id INT NOT NULL AUTO_INCREMENT,                                                                                                                                
                                           meta_key VARCHAR(255) NOT NULL,                                                                                                                                       
                                           meta_value VARCHAR(255),                                                                                                                                              
                                           species_id int(10) unsigned default 1,                                                                                                                                
                                           PRIMARY KEY (id)                                                                                                                                                      
                                         )                                                                                                                                                                       
                      ");
  }


  for (my $j = 0; $j <= $#meta_queries; $j++){
      ($key_exist)= &query( $db,
       "select count(*) from stats where meta_key = '". $meta_keys[$j] ."' and species_id = '".$sp_id."'");

      if($key_exist == 0) {
	  my $insert_q = "insert into stats (species_id, meta_key, meta_value) values ('".$sp_id."', '".$meta_keys[$j]."', '".$meta_vals[$j]."')";
         $db2->do($insert_q);    
      } elsif ($update_meta) {
         my $update_q = "update stats set meta_value = '".$meta_vals[$j]."' where meta_key = '". $meta_keys[$j] ."'";
         $db2->do($update_q);  
      }
  }


} # end of species
} # if 

foreach my $spp (@valid_spp) {

    my $db;
    my @meta_queries;
    my (@meta_keys, @meta_vals);

    eval {
	my $databases = $dbconn->get_databases_species($spp, "core");
	$db =  $databases->{'core'} ||
	    die( "Could not retrieve core database for $spp" );
    };

    if( $@ ) {
	print STDERR "FATAL: $@";
	exit(0);
    }

    my $sp_id = $SD->get_config($spp, 'SPECIES_META_ID') || '';
    $sp_id || warn "[ERROR] $spp missing SpeciesDefs->SPECIES_META_ID!";

    if ($NOSUMMARY) {
       do_interpro($db, $spp, undef, undef, $sp_id, '0');
    }
    else {

       ##--------------------------- DO INTERPRO STATS -----------------------------                                                                                                                                   
       my $ip_tables = do_interpro($db, $spp, undef, undef, $sp_id, '0') unless $NOINTERPRO;

       ##--------------------------- OUTPUT STATS TABLE -----------------------------                       

       ## PREPARE TO WRITE TO OUTPUT FILE                                                                                                                                                                     
       my $fq_path_dir = sprintf( STATS_PATH, $PLUGIN_ROOT);
       &check_dir($fq_path_dir);
       my $fq_path_html = $fq_path_dir."stats_$spp.html";
       open (STATS, ">$fq_path_html") or die "Cannot write $fq_path_html: $!";
       my $useres = $db2->do("use ".$db->{'_dbc'}->{'_dbname'});
       my $SQL1 = "select meta_key, meta_value from stats where meta_key like 'stat.%' and species_id='".$sp_id."' order by id";

       my $sth1 = $db->dbc->prepare($SQL1);
       $sth1->execute();

       my $curr_title = '0';
       my $rowcount = 0;
       my $row;
       while (my ($key, $val) = $sth1->fetchrow_array) {
	   my ($st1, $title1, $col1) = split('\.', $key, 3);
     
           if ($curr_title ne $title1) {
               if($curr_title ne '0') {
		   print STATS qq(</table>);
                   $rowcount = 0;
               }           
               print STATS qq(<h3 class="boxed">$title1</h3>
			       <table class="ss tint species-stats">);
           }           
           $curr_title = $title1;
	   $rowcount++;
	   $row = stripe_row($rowcount);
           print STATS qq($row
                          <td class="data">$col1</td>
		            <td class="value">$val</td>
                          </tr>);
       }
       print STATS qq(</table>);
       close(STATS);

    } #else

} #foreach 

exit;



#############################################################################

sub query { my( $db, $SQL ) = @_;
   my $sth = $db->dbc->prepare($SQL);
   $sth->execute();
   my @Q = $sth->fetchrow_array();
   $sth->finish;
   return @Q;
}

sub query_insert { my( $db, $SQL ) = @_;
 	    my $sth = $db->dbc->prepare($SQL) or die "Cannot prepare: " . $db->dbc->errstr();
	    $sth->execute() or die "Cannot execute: " . $sth->errstr();
	    $sth->finish;
	    return 1;
	}


sub check_dir {
  my $dir = shift;
  if( ! -e $dir ){
    system("mkdir -p $dir") == 0 or
      ( print("Cannot create $dir: $!" ) && next );
  }
  return;
}

sub thousandify {
  my $value = shift;
  local $_ = reverse $value;
  s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
  return scalar reverse $_;
}

sub stripe_row {
  my $rowcount = shift;
  my $row = '<tr';
  if ($rowcount % 2 != 0) {
    $row .= ' class="bg2"';
  }
  $row .= '>';
  return $row;
}

sub do_interpro {
  my ($db, $species, $db2, $update_meta, $sp_id, $insert) = @_;

  ## Best to do this using API!
  
  ## First get all interpro accession IDs
  my $domain;
  if($insert == 1) {
     my $SQL = qq(SELECT  i.interpro_ac,
                               x.description,
                               count(*)
                       FROM  interpro i
                       LEFT JOIN xref x ON i.interpro_ac = x.dbprimary_acc
                       LEFT JOIN protein_feature pf ON i.id = pf.hit_name
                       GROUP BY pf.hit_name);


     my $sth = $db->dbc->prepare($SQL);
     $sth->execute();

     while (my ($acc, $descr, $count) = $sth->fetchrow_array) {
       $domain->{$acc}{descr} = $descr;
       $domain->{$acc}{count} = $count;
     }

  } else {

     my $SQL = "select meta_key, meta_value from stats where meta_key like 'hit.%' order by id";
     my $sth = $db->dbc->prepare($SQL);
     $sth->execute();

     while (my ($key, $val) = $sth->fetchrow_array) {
	  my ($st1, $st2, $acc, $descr, $count) = split('\.', $key);
	  $descr =~ s/\\'/'/g;
	  $descr =~ s/\\"/"/g;
	  $descr =~ s/\\\//\//g;

	  $domain->{$acc}{descr} = $descr;
	  $domain->{$acc}{count} = $count;
     }

  } #else

  return 0 if !(keys %$domain);

  use EnsEMBL::Web::DBSQL::DBConnection;
  my $dbc = EnsEMBL::Web::DBSQL::DBConnection->new();
  my $adaptor = $dbc->get_DBAdaptor('core', $species);
  my $ga = $adaptor->get_GeneAdaptor;

  foreach my $ac_id (keys %$domain) { 
    my @genes = @{$ga->fetch_all_by_domain($ac_id)};
    next if !@genes;
    $domain->{$ac_id}{genes} = @genes;
    #foreach my $g (@genes) {
    #  $domain->{$acc}{count} += @{ $g->get_all_Transcripts };
    #}
  }

  my @hits;

  my ($number, $file, $bigtable);
  $number = 40;
  $file = "IPtop40.html";
  $bigtable = 0;
  if($insert == 0) {
     hits2html($PLUGIN_ROOT, $domain, $number, $file, $bigtable, $species, $db, $db2, $update_meta, $sp_id, '0');
  }
 
  $number = 500;
  $file = "IPtop500.html";
  $bigtable = 1;
  hits2html($PLUGIN_ROOT, $domain, $number, $file, $bigtable, $species, $db, $db2, $update_meta, $sp_id, $insert);

  return 1;
}

sub hits2html {
  my ($ENS_ROOT, $domain, $number, $file, $isbig, $species, $db, $db2, $update_meta, $sp_id, $insert) = @_;

  if($insert == 1)  {
 
      $| = 1;

      my $numhits = scalar(keys %$domain);
      if ($numhits < $number){ $number = $numhits;}

      my $date    = `date`;
      chomp($date);

      my @domids = sort { ($domain->{$b}{genes} || 0) <=> ($domain->{$a}{genes} || 0)} keys %$domain;

      my @meta_queries;
      my (@meta_keys, @meta_vals);
      for (my $i = 0; $i< $number; $i++){
        my $tmpdom1 = $domain->{$domids[$i]};

        my $name1  = $domids[$i];
        my $gene1  = $tmpdom1->{genes};
        my $count1 = $tmpdom1->{count};
        my $descr1 = $tmpdom1->{descr} || '';
        $descr1 =~ s/'/\\'/g;
        $descr1 =~ s/"/\\"/g;
        $descr1 =~ s/\//\\\//g;

        push @meta_queries, "insert into stats (meta_key, meta_value) values ('hit.InterPro.${name1}.${descr1}.${count1}', '$gene1')";
        push @meta_keys,    "hit.InterPro.${name1}.${descr1}.${count1}";
        push @meta_vals,    "$gene1";
      }

      my $key_exist;     
      my $useres = $db2->do("use ".$db->{'_dbc'}->{'_dbname'});                                                                                     
  
      my $table_exist = '';
      ($table_exist) = &query( $db,
                           "show tables like 'stats'");

      if($table_exist ne 'stats') {

                   $db2->do("CREATE TABLE stats(                                                                                                                                                             
                                           id INT NOT NULL AUTO_INCREMENT,                                                                                                                                   
                                           meta_key VARCHAR(255) NOT NULL,                                                                                                                                       
                                           meta_value VARCHAR(255),                                                                                                                                              
                                           species_id int(10) unsigned default 1,                                                                                                                                
                                           PRIMARY KEY (id)                                                                                                                                                      
                                         )                                                                                                                                                                       
                      ");
      }

      for (my $j = 0; $j <= $#meta_queries; $j++){
         ($key_exist)= &query( $db,
			  "select count(*) from stats where meta_key = '". $meta_keys[$j] ."'");

         print " key_exist: $key_exist\n";
         if($key_exist == 0) {
           my $insert_q = "insert into stats (species_id, meta_key, meta_value) values ('".$sp_id."', '".$meta_keys[$j]."', '".$meta_vals[$j]."')";
           $db2->do($insert_q);                                                                     
         }  elsif ($update_meta) {
           my $update_q = "update stats set meta_value = '".$meta_vals[$j]."' where meta_key = '". $meta_keys[$j] ."'";
           $db2->do($update_q);                                                                                                     
         }
      }

  }  else {

    my $interpro_dir = sprintf(STATS_PATH, $ENS_ROOT);

    if( ! -e $interpro_dir ){

    system("mkdir -p $interpro_dir") == 0 or
	( warning( 1, "Cannot create $interpro_dir: $!" ) && next );
    }

    my $fq_path = $interpro_dir.'/stats_'.$species.'_'.$file;
    open (HTML, ">$fq_path") or warn "Cannot write HTML file for pfam hits: $!\n";
 
    #select (HTML);
    #$| = 1;

    my $numhits = scalar(keys %$domain);
    if ($numhits < $number) { $number = $numhits; }

    my $date    = `date`;
    chomp($date);

    my @domids = sort { ($domain->{$b}{genes} || 0) <=> ($domain->{$a}{genes} || 0)} keys %$domain;

    print HTML  qq(<table class="ss tint">\n);
    print HTML qq(<tr
            <th>No.</th>
            <th>InterPro name</th>
            <th>Number of genes</th>
            <th>Number of Ensembl hits</th>
            <th>No.</th>
            <th>InterPro name</th>
            <th>Number of genes</th>
            <th>Number of Ensembl hits</th>
         </tr>
	   );

    my @class = ('class="bg2"', 'class="bg1"');
    for (my $i = 0; $i< $number/2; $i++){
	my $tmpdom1 = $domain->{$domids[$i]};
	my $tmpdom2 = $domain->{$domids[$i + $number/2]};

	my $name1  = $domids[$i];
	my $gene1  = $tmpdom1->{genes};
	my $count1 = $tmpdom1->{count};
	my $descr1 = $tmpdom1->{descr};

	my $name2  = $domids[$i + $number/2];
	my $gene2  = $tmpdom2->{genes};
	my $count2 = $tmpdom2->{count};
	my $descr2 = $tmpdom2->{descr};

	my $order1 = $i+1 || 0;
	my $order2 = $i+($number/2)+1 || 0;
	my $class = shift @class;
	push @class, $class;
        print HTML qq(
         <tr $class>
          <td><b>$order1</b></td>
          <td><a href="http://www.ebi.ac.uk/interpro/entry/$name1">$name1</a><br />$descr1</td>
          <td><a href="/$species/Location/Genome?ftype=Domain;id=$name1">$gene1</a></td>
          <td>$count1</td>
          <td><b>$order2</b></td>
          <td><a href="http://www.ebi.ac.uk/interpro/entry/$name2">$name2</a><br />$descr2</td>
          <td><a href="/$species/Location/Genome?ftype=Domain;id=$name2">$gene2</a></td>
          <td>$count2</td>
         </tr>
        );
    }

    print HTML "</table>";

    my $interpro_path = "/$species/Info";
    if($isbig == 0){
    # the Top40 page                                                                                                                                                                                              
	print HTML qq(<p><a href="$interpro_path/IPtop500">View</a> top 500 InterPro hits (large table)</p>);
    }
    else{
    # >top40  page                                                                                                                                                                                                
	print HTML qq(<p><a href="$interpro_path/IPtop40">View</a> top 40 InterPro hits</p>);
    }

    close(HTML);
} #else 




  



}


__END__

=head1 NAME

species_stats.pl

=head1 SYNOPSIS

species_stats.pl [options]

Options:
  --help, --info, --species

B<-h,--help>
  Prints a brief help message and exits.

B<-i,--info>
  Prints man page and exits.

B<-s, --species>
  Species to dump. Defaults to all ensembl species.

B<--nointerpro>
  Don't run utils/make_InterProTop40.pl for each species

B<--debug>
  Print out stats as the program is running

B<--plugin_root>

  Directory containing the htdocs dir (normally an ensembl plugin) to
  edit.  Defaults to $Sitedefs::SERVERROOT/public-plugins/ensembl. If
  a relative path is given, this is assumed relative to
  $Sitedefs::SERVERROOT.

=head1 DESCRIPTION

B<This program:>

Calculates statistics about a genome using data stored in an Ensembl database. 

The database location is specified in Ensembl web config file:
  /public-plugins/ensembl/conf/ini-files/<SPECIES>.ini

The statistics are written as html to files:
  /public-plugins/ensembl/htdocs/ssi/species/stats_<SPECIES>.html

Written by Jim Stalker <jws@sanger.ac.uk>
Maintained by Anne Parker <ap5@sanger.ac.uk>, Fiona Cunningham <fc1@sanger.ac.uk>

=cut

1;
