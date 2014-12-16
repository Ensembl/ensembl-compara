#!/usr/bin/env perl

##############################################################################
#
# SCRIPT TO GENERATE HTML TABLES OF GENOMIC STATISTICS FOR ENSEMBL
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
#use JSON::Parse qw /json_to_perl valid_json/;
use List::MoreUtils qw /first_index/;
use HTML::Entities qw(encode_entities);

use vars qw( $SERVERROOT $PRE $PLUGIN_ROOT $SCRIPT_ROOT $DEBUG $FUDGE $NOINTERPRO $NOSUMMARY $help $info @user_spp $allgenetypes $coordsys $list $pan_comp_species $ena $nogenebuild
  $species_page);

BEGIN{
  &GetOptions( 
               'help'      => \$help,
               'info'      => \$info,
               'list'      => \$list,
               'species=s' => \@user_spp,
	       'a' => \$allgenetypes,
               'debug'     => \$DEBUG,
               'nointerpro'=> \$NOINTERPRO,
               'nosummary' => \$NOSUMMARY,
               'plugin_root=s' => \$PLUGIN_ROOT,
               'pre'       => \$PRE,
               'coordsys' => \$coordsys,
               'pan_c_sp' => \$pan_comp_species,
               'ena' => \$ena,
               'nogenebuild' => \$nogenebuild,
               'all_species_page' => \$species_page,
  );

  pod2usage(-verbose => 2) if $info;
  pod2usage(1) if $help;

  $SCRIPT_ROOT = dirname( $Bin );
  ($SERVERROOT = $SCRIPT_ROOT) =~ s#/utils##;
  my $plugin = $PRE ? '/../sanger-plugins/pre' : '/../public-plugins/ensembl';
  $PLUGIN_ROOT ||= $SERVERROOT.$plugin;

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

use constant STATS_PATH => qq(%s/htdocs/ssi/species/);

use Bio::EnsEMBL::DBLoader;
use EnsEMBL::Web::DBSQL::DBConnection;

##---------------------------- SPECIES INFO ---------------------------------

use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::Document::Table;

my $SD      = EnsEMBL::Web::SpeciesDefs->new();
my $pre     = $PLUGIN_ROOT =~ m#sanger-plugins/pre# ? 1 : 0;
$NOINTERPRO = 1 if $pre;

# get a list of valid species for this release
my $release_id  = $SD->ENSEMBL_VERSION;
my @release_spp = $SD->valid_species;

my %species_check;
foreach my $sp (@release_spp) {
  $species_check{$sp}++;
  print STDERR "$sp\n" if($list);
}
exit if ($list);

# check validity of user-provided species
my @valid_spp;
if (@user_spp) {
  foreach my $sp (@user_spp) {
    if ($species_check{$sp}) {
      push (@valid_spp, $sp);
    } else {
      carp "Species $sp is not configured for release $release_id - omitting!\n";
    }
  }
} else {
  @valid_spp = @release_spp;
}

@valid_spp || pod2usage("$0: Need a species" );

# all species resources page generation 

if ($species_page 
  && !$help && !$info && !$list && !@user_spp && !$allgenetypes && !$NOINTERPRO
  && !$NOSUMMARY && !$PRE && !$coordsys && !$pan_comp_species && !$ena && !$nogenebuild) {

  render_all_species_page(\@valid_spp);
  exit;
}
elsif ($species_page) {
  render_all_species_page(\@valid_spp);
}

##---------------------------- CREATE STATS ---------------------------------
my $dbconn = EnsEMBL::Web::DBSQL::DBConnection->new(undef, $SD);

if($pan_comp_species) {
  do_pan_compara_species();
}

my ($count_spp,$total_spp) = (0,scalar @valid_spp);
foreach my $spp (@valid_spp) {

  ## CONNECT TO APPROPRIATE DATABASES
  my $db;
  eval {
    my $databases = $dbconn->get_databases_species($spp, "core");
    $db =  $databases->{'core'} || 
      die( "Could not retrieve core database for $spp" );
  };

  if( $@ ) {
    print STDERR "FATAL: $@";
    exit(0);
  }

  my $var_db;
  eval {
    my $databases = $dbconn->get_databases_species($spp, "variation");
    $var_db =  $databases->{'variation'} || undef;
  };

  if ($NOSUMMARY) {
    do_interpro($db, $spp);
  } else {

    ## PREPARE TO WRITE TO OUTPUT FILE
    $count_spp++;
    print STDERR "\nGetting stats for $spp ($count_spp of $total_spp)...\n";
    my $fq_path_dir = sprintf( STATS_PATH, $PLUGIN_ROOT);
    #print $fq_path_dir, "\n";
    &check_dir($fq_path_dir);
    my $fq_path_html = $fq_path_dir."stats_$spp.html";
    print STDERR "Writing $fq_path_html\n";
    open (STATS, ">$fq_path_html") or die "Cannot write $fq_path_html: $!";

    ### GET ASSEMBLY AND GENEBUILD INFO
    # Assembly ID ->should be in meta table
    my $db_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($spp, "core");
    my $spp_id = $db_adaptor->species_id;
    my $meta_container = $db_adaptor->get_MetaContainer();

    my( $a_id ) = ( @{$meta_container->list_value_by_key('assembly.name')},
                    @{$meta_container->list_value_by_key('assembly.default')});
    warn "[ERROR] $spp "
        ."missing both meta->assembly.name and meta->assembly.default"
        unless( $a_id );

    if ($ena) {
      # look for long name and accession num
      if (my ($long) = @{$meta_container->list_value_by_key('assembly.long_name')}) {
        $a_id .= " ($long)"; 
      }
      if (my ($acc) = @{$meta_container->list_value_by_key('assembly.accession')}) {
        $acc = sprintf('INSDC Assembly <a href="http://www.ebi.ac.uk/ena/data/view/%s">%s</a>', $acc, $acc);
        $a_id .= ", $acc"; 
      }
    }

    my $a_date    = $SD->get_config($spp, 'ASSEMBLY_DATE')      || '' or warn "[ERROR] $spp missing SpeciesDefs->ASSEMBLY_DATE!";
    my $b_start   = $SD->get_config($spp, 'GENEBUILD_START')    || '' or warn "[ERROR] $spp missing SpeciesDefs->GENEBUILD_START!";
    my $b_release = $SD->get_config($spp, 'GENEBUILD_RELEASE')  || '' or warn "[ERROR] $spp missing SpeciesDefs->GENEBUILD_RELEASE!";
    my $b_latest  = $SD->get_config($spp, 'GENEBUILD_LATEST')   || '' or warn "[ERROR] $spp missing SpeciesDefs->GENEBUILD_LATEST!";
    my $b_id      = $SD->get_config($spp, 'GENEBUILD_BY')       || '' or $pre or warn "[ERROR] $spp missing SpeciesDefs->GENEBUILD_BY!";
    my $b_version = $SD->get_config($spp, 'GENEBUILD_VERSION') || '';
    #my $b_method  = ucfirst($SD->get_config($spp, 'GENEBUILD_METHOD')) || '';
    my @A         = @{$meta_container->list_value_by_key('genebuild.method')};
    my $b_method  = ucfirst($A[0]) || '';
    $b_method     =~ s/_/ /g;
    $b_method || warn "[ERROR] $spp missing SpeciesDefs->GENEBUILD_METHOD!" unless $pre;

    my $data_version  = $SD->get_config($spp, 'SPECIES_RELEASE_VERSION');
    my $db_id         = $release_id;
		$db_id           .= '.'.$data_version unless $pre;
    #print "Version $data_version\n";

##----------------------- NASTY RAW SQL STUFF! ------------------------------

    my (%gene_stats, %other_stats);

    my @gene_stats_keys   = qw(coding shortnoncoding longnoncoding pseudogene transcript);
    my @alt_gene_stats_keys = qw(alt_coding alt_shortnoncoding alt_longnoncoding alt_pseudogene alt_transcript);

    my @other_stats_keys  = qw(genpept genfpept fgenpept snps strucvar);

    my %glossary          = $SD->multiX('ENSEMBL_GLOSSARY');
 
    my %glossary_lookup   = (
      'coding'              => 'Protein coding',
      'alt_coding'          => 'Protein coding',
      'shortnoncoding'      => 'Short Non coding',
      'alt_shortnoncoding'  => 'Short Non coding',
      'longnoncoding'       => 'Long Non coding',
      'alt_longnoncoding'   => 'Long Non coding',
      'pseudogene'          => 'Pseudogene',
      'alt_pseudogene'      => 'Pseudogene',
      'transcript'          => 'Transcript',
      'alt_transcript'      => 'Transcript',
    );

    my %gene_title        = (
      'coding'              => 'Coding genes',
      'shortnoncoding'      => 'Short Non coding genes',
      'longnoncoding'       => 'Long Non coding genes',
      'pseudogene'          => 'Pseudogenes',
      'transcript'          => 'Gene transcripts'
    );

    my %alt_gene_title        = (
      'alt_coding'          => 'Coding genes',
      'alt_shortnoncoding'  => 'Short Non coding genes',
      'alt_longnoncoding'   => 'Long Non coding genes',
      'alt_pseudogene'      => 'Pseudogenes',
      'alt_transcript'      => 'Gene transcripts'
    );

    my %other_title       = (
      'genpept'             => 'Genscan gene predictions',
      'genfpept'            => 'Genefinder gene predictions',
      'fgenpept'            => 'FGENESH gene predictions',
      'snps'                => 'Short Variants (SNPs, indels, somatic mutations)',
      'strucvar'            => 'Structural variants'
    );

    unless ($pre) { 
###

      ($gene_stats{'coding'}) = &query( $db,
        "select sum(value)
        from seq_region_attrib sa, attrib_type at,
             seq_region s, coord_system cs
        where species_id=$spp_id
        and at.attrib_type_id = sa.attrib_type_id
        and s.seq_region_id = sa.seq_region_id
        and cs.coord_system_id = s.coord_system_id
        and code = 'coding_cnt'
        ");
      print STDERR "Coding:$gene_stats{'coding'}\n" if $DEBUG;

      ($gene_stats{'alt_coding'}) = &query( $db,
        "select sum(value)
        from seq_region_attrib sa, attrib_type at,
             seq_region s, coord_system cs
        where species_id=$spp_id
        and at.attrib_type_id = sa.attrib_type_id
        and s.seq_region_id = sa.seq_region_id
        and cs.coord_system_id = s.coord_system_id
        and code = 'coding_acnt'
        ");
      print STDERR "Alternate coding:$gene_stats{'alt_coding'}\n" if $DEBUG;



###

      ($gene_stats{'shortnoncoding'}) = &query( $db,
        "select sum(value)
        from seq_region_attrib sa, attrib_type at,
             seq_region s, coord_system cs
        where species_id=$spp_id
        and at.attrib_type_id = sa.attrib_type_id
        and s.seq_region_id = sa.seq_region_id
        and cs.coord_system_id = s.coord_system_id
        and code = 'snoncoding_cnt'
        ");
      print STDERR "Non coding:$gene_stats{'shortnoncoding'}\n" if $DEBUG;

      ($gene_stats{'longnoncoding'}) = &query( $db,
        "select sum(value)
        from seq_region_attrib sa, attrib_type at,
             seq_region s, coord_system cs
        where species_id=$spp_id
        and at.attrib_type_id = sa.attrib_type_id
        and s.seq_region_id = sa.seq_region_id
        and cs.coord_system_id = s.coord_system_id
        and code = 'lnoncoding_cnt'
        ");
      print STDERR "Non coding:$gene_stats{'longnoncoding'}\n" if $DEBUG;

      ($gene_stats{'alt_shortnoncoding'}) = &query( $db,
        "select sum(value)
        from seq_region_attrib sa, attrib_type at,
             seq_region s, coord_system cs
        where species_id=$spp_id
        and at.attrib_type_id = sa.attrib_type_id
        and s.seq_region_id = sa.seq_region_id
        and cs.coord_system_id = s.coord_system_id
        and code = 'snoncoding_acnt'
        ");
      print STDERR "Alternate non coding:$gene_stats{'alt_shortnoncoding'}\n" if $DEBUG;

      ($gene_stats{'alt_longnoncoding'}) = &query( $db,
        "select sum(value)
        from seq_region_attrib sa, attrib_type at,
             seq_region s, coord_system cs
        where species_id=$spp_id
        and at.attrib_type_id = sa.attrib_type_id
        and s.seq_region_id = sa.seq_region_id
        and cs.coord_system_id = s.coord_system_id
        and code = 'lnoncoding_acnt'
        ");
      print STDERR "Alternate non coding:$gene_stats{'alt_longnoncoding'}\n" if $DEBUG;

###

      ( $gene_stats{'pseudogene'} ) = &query( $db,
        "select sum(value)
        from seq_region_attrib sa, attrib_type at,
             seq_region s, coord_system cs
        where species_id=$spp_id
        and at.attrib_type_id = sa.attrib_type_id
        and s.seq_region_id = sa.seq_region_id
        and cs.coord_system_id = s.coord_system_id
        and code = 'pseudogene_cnt'
        ");    
      print STDERR "Pseudogenes:$gene_stats{'pseudogene'}\n" if $DEBUG;

      ( $gene_stats{'alt_pseudogene'} ) = &query( $db,
        "select sum(value)
        from seq_region_attrib sa, attrib_type at,
             seq_region s, coord_system cs
        where species_id=$spp_id
        and at.attrib_type_id = sa.attrib_type_id
        and s.seq_region_id = sa.seq_region_id
        and cs.coord_system_id = s.coord_system_id
        and code = 'pseudogene_acnt'
        ");
      print STDERR "Alternate pseudogenes:$gene_stats{'alt_pseudogene'}\n" if $DEBUG;

    } #unless pre

    ## DO OTHER RAW QUERIES
    ( $other_stats{'genpept'} ) = &query( $db,
    "select count( distinct p.prediction_transcript_id )
      from prediction_transcript p, analysis a, seq_region sr, coord_system cs
      where p.seq_region_id = sr.seq_region_id
      and sr.coord_system_id = cs.coord_system_id
      and cs.species_id=$spp_id
      and p.analysis_id = a.analysis_id
      and a.logic_name = 'Genscan'
    ");
    print STDERR "Genscans:$other_stats{'genpept'}\n" if $DEBUG;

    ( $other_stats{'genfpept'} ) = &query( $db,
    "select count( distinct p.prediction_transcript_id )
      from prediction_transcript p, analysis a, seq_region sr, coord_system cs
      where p.seq_region_id = sr.seq_region_id
      and sr.coord_system_id = cs.coord_system_id
      and cs.species_id=$spp_id
      and p.analysis_id = a.analysis_id
      and a.logic_name = 'Genefinder'
    ");
    print STDERR "Genefinder:$other_stats{'genfpept'}\n" if $DEBUG;

    ( $other_stats{'fgenpept'} ) = &query( $db,
    "select count( distinct p.prediction_transcript_id )
      from prediction_transcript p, analysis a, seq_region sr, coord_system cs
      where p.seq_region_id = sr.seq_region_id
      and sr.coord_system_id = cs.coord_system_id
      and cs.species_id=$spp_id
      and p.analysis_id = a.analysis_id
      and a.logic_name like '%fgenesh%'
    ");
    print STDERR "Fgenesh:$other_stats{'fgenpept'}\n" if $DEBUG;

    unless ($pre) {
        ( $gene_stats{'transcript'} )= &query( $db,
          "select count(distinct t.transcript_id)
           from transcript t
           join seq_region sr using (seq_region_id)
           join coord_system cs using (coord_system_id)
           where cs.species_id=$spp_id 
           and t.seq_region_id not in (
             select sa.seq_region_id
             from seq_region_attrib sa
             join attrib_type at using (attrib_type_id) 
             where at.code = 'non_ref'
           )"
        );
      print STDERR "Transcripts:$gene_stats{'transcript'}\n" if $DEBUG;

        ( $gene_stats{'alt_transcript'} )= &query( $db,
          "select count(distinct t.transcript_id)
          from transcript t, seq_region_attrib sa, attrib_type at, seq_region sr, coord_system cs
          where t.seq_region_id = sa.seq_region_id
          and sa.attrib_type_id = at.attrib_type_id
          and sr.coord_system_id = cs.coord_system_id
          and cs.species_id=$spp_id
          and sr.seq_region_id = sa.seq_region_id
          and t.biotype not in ('LRG_gene')
          and at.code = 'non_ref'"
        );
      print STDERR "Transcripts:$gene_stats{'alt_transcript'}\n" if $DEBUG;

      $other_stats{'snps'}      = 0;
      $other_stats{'strucvar'}  = 0;
      if ($var_db) {
        ($other_stats{'snps'}) = &query ( $var_db, "SELECT COUNT(DISTINCT variation_id) FROM variation_feature");
        print STDERR "SNPs, etc:$other_stats{'snps'}\n" if $DEBUG;
        ($other_stats{'strucvar'}) = &query ( $var_db, "SELECT COUNT(DISTINCT structural_variation_id) FROM structural_variation");
        print STDERR "Structural variations:$other_stats{'strucvar'}\n" if $DEBUG;
      }
    }

    ## Total number of base pairs

    my ( $bp ) = &query( $db,
      "select sum(length(sequence))
      from dna 
        join seq_region using (seq_region_id)
        join coord_system using (coord_system_id)
      where species_id=$spp_id"
    );

    print STDERR "Total base pairs: $bp.\n" if $DEBUG;

    ## Golden path length

    my ( $gpl ) = &query( $db,
      "SELECT sum(length) 
        FROM seq_region sr, seq_region_attrib sra, attrib_type at, coord_system cs 
        WHERE sr.seq_region_id = sra.seq_region_id
          AND sra.attrib_type_id = at.attrib_type_id 
          AND sr.coord_system_id = cs.coord_system_id 
          AND cs.species_id = $spp_id
          AND at.code = 'toplevel' 
          AND cs.name != 'lrg' 
          AND sr.seq_region_id NOT IN 
            (SELECT DISTINCT seq_region_id FROM assembly_exception ae WHERE ae.exc_type != 'par' )
        "
    );

    print STDERR "Golden path length: $gpl.\n" if $DEBUG;


    ##-----------------------List all coord systems region counts----------------
    my $b_coordsys="";
    if($coordsys){
      my @hidden = @{ $SD->get_config($spp,'HIDDEN_COORDSYS') || [] };
      my @coord_systems;
      my $sa = $db_adaptor->get_adaptor('slice');
      my $csa = $db_adaptor->get_adaptor('coordsystem');
      foreach my $cs (sort {$a->rank <=> $b->rank} @{$csa->fetch_all_by_attrib('default_version') || []}){
        next if (grep {$_ eq $cs->name} @hidden);
        push(@coord_systems,$cs);
      }
      #EG - hide some coord systems
      my $row_count=0;
      my $rows_html = "";
      foreach my $cs (@coord_systems){
        
      # my @regions = @{$sa->fetch_all($cs->name)};
      # my $count_regions = scalar @regions;
        my $csid = $cs->dbID;
        my ($count_regions) = &query( $db, "SELECT count(1) from seq_region where coord_system_id=$csid" ); 
      	print join(' : ', ($csid, $cs->name, $cs->version , $count_regions, "\n")) if ($DEBUG) ;
        my $regions_html;
        if($count_regions < 1000){
          my @regions = @{$sa->fetch_all($cs->name)};
          $regions_html = regions_table($spp,$cs->name,\@regions);
        }
        else{
          $regions_html = sprintf("%d %s",$count_regions,($count_regions>1)?"sequences":"sequence");
        }
        $row_count++;
        $rows_html .= sprintf(qq{
          %s 
          <td class="data">%s</td>
          <td class="value">%s</td>
          </tr>},
          stripe_row($row_count),
          $cs->name,
          $regions_html);
      	printf("%s done\n", $cs->name) if ($DEBUG);
      }
      #EG - only print when there is a table to print
      if($rows_html){
        $b_coordsys=qq{<h3>Coordinate Systems</h3>\n<table class="ss tint species-stats">$rows_html</table>\n};
      }
    }
    
    ##--------------------------- DO INTERPRO STATS -----------------------------

    my $ip_tables = do_interpro($db, $spp) unless $NOINTERPRO;

    ##--------------------------- OUTPUT STATS TABLE -----------------------------
    print STDERR "...writing stats file...\n";

    print STATS qq(
      <h3>Summary</h3>
    
      <table class="ss tint species-stats">
        <tr class="bg2">
          <td class="data">Assembly:</td>
          <td class="value">$a_id, $a_date</td>
        </tr>
        <tr>
          <td class="data">Database version:</td>
          <td class="value">$db_id</td>
        </tr>
      );

    my $row;
    my $rowcount = 1; ## use this to alternate white and coloured rows

    $bp   = thousandify($bp);
    $row  = stripe_row($rowcount);
    print STATS qq($row
          <td class="data">Base Pairs:</td>
          <td class="value">$bp</td>
      </tr>);

    $rowcount++;
    $gpl  = thousandify($gpl);
    $row  = stripe_row($rowcount);
    print STATS qq($row
          <td class="data">Golden Path Length:</td>
          <td class="value">$gpl</td>
      </tr>
    );

    unless ($pre) {
      my @summary_stats = (
        'Genebuild by' => $b_id,
        'Genebuild method'=> $b_method,
        'Genebuild started' => $b_start,
        'Genebuild released' => $b_release,
        'Genebuild last updated/patched' => $b_latest,
        'Genebuild version' => $b_version
      );
      
      if ($nogenebuild) {
        # no genebuild dates - but want method
        @summary_stats = ('Genebuild method'=> $b_method);
      }

      while (my($k, $v) = splice(@summary_stats, 0, 2)) {
        $rowcount++;
        $row = stripe_row($rowcount);
        printf STATS (qq(%s <td class="data">%s:</td> <td class="value">%s</td> </tr>),
          $row, $k, $v)
          if $v;
      }
      print STATS qq(</table>);

######################
######################
 
      my $primary = $gene_stats{'alt_coding'} ? ' (Primary assembly)' : '';
      my $any_genes = 0;
      for (@gene_stats_keys){
         if($gene_stats{$_}){$any_genes += $gene_stats{$_}};
      }
      if($any_genes){
        print STATS qq(
          <h3>Gene counts$primary</h3>
          <table class="ss tint species-stats">
        );
        $rowcount = 0;

        for (@gene_stats_keys) {
          if ($gene_stats{$_}) {
            $gene_stats{$_} = thousandify($gene_stats{$_});
            $rowcount++;
            $row = stripe_row($rowcount);
            my $term = $glossary_lookup{$_};
            my $header = $term ? qq(<span class="glossary_mouseover">$gene_title{$_}<span class="floating_popup">$glossary{$term}</span></span>) : $gene_title{$_};
            print STATS qq($row
              <td class="data">$header:</td>
              <td class="value">$gene_stats{$_}</td>
              </tr>
            );
          }
        }

        print STATS qq(
          </table>
        );

        if ($gene_stats{'alt_coding'}) {
        print STATS qq(
          <h3>Gene counts (Alternate sequences)</h3>
          <table class="ss tint species-stats">
        );
        $rowcount = 0;
        }

        for (@alt_gene_stats_keys) {
          if ($gene_stats{$_}) {
            $gene_stats{$_} = thousandify($gene_stats{$_});
            $rowcount++;
            $row = stripe_row($rowcount);
            my $term = $glossary_lookup{$_};
            my $header = $term ? qq(<span class="glossary_mouseover">$alt_gene_title{$_}<span class="floating_popup">$glossary{$term}</span></span>) : $alt_gene_title{$_};
            print STATS qq($row
              <td class="data">$header:</td>
              <td class="value">$gene_stats{$_}</td>
              </tr>
            );
          }
        }

        print STATS qq(
          </table>
        );

      }
    }

    if($coordsys){
      print STATS $b_coordsys;
    }

    $db->dbc->db_handle->disconnect; # prevent too many connections

    if(grep $other_stats{$_}, @other_stats_keys){

      print STATS qq(
        <h3>Other</h3>
        <table class="ss tint species-stats">
      );
      $rowcount = 0;

      for (@other_stats_keys) {
        if ($other_stats{$_}) {
          $other_stats{$_} = thousandify($other_stats{$_});
          $rowcount++;
          $row = stripe_row($rowcount);
          print STATS qq($row
            <td class="data">$other_title{$_}:</td>
            <td class="value">$other_stats{$_}</td>
            </tr>
          );
        }
      }

      print STATS '</table>';
    }

    close(STATS);
  }
  print STDERR "...$spp done.\n";

} # end of species


exit;



#############################################################################
sub query_status { my( $db, $SQL ) = @_;
   my $sth = $db->dbc->prepare($SQL);
   $sth->execute();
   my @Q;
   my ($status, $count);
   while ( ($status, $count) = $sth->fetchrow_array() ) 
   {
     my $stat = [ $status, $count ];
     push @Q, $stat;
   }

   $sth->finish;
   return \@Q;
}


sub query { my( $db, $SQL ) = @_;
   my $sth = $db->dbc->prepare($SQL);
   $sth->execute();
   my @Q = $sth->fetchrow_array();
   $sth->finish;
   return @Q;
}

sub check_dir {
  my $dir = shift;
  if( ! -e $dir ){
    system("mkdir -p $dir") == 0 or
      ( print STDERR ("Cannot create $dir: $!" ) && next );
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

sub do_pan_compara_species {   

    my $fq_path_dir = sprintf( STATS_PATH, $PLUGIN_ROOT);
    &check_dir($fq_path_dir);
    my $pan_comp_path_html = $fq_path_dir."pan_compara_species.html";
    open (STAT_P_C, ">$pan_comp_path_html") or die "Cannot write $pan_comp_path_html: $!";
    my $release_version = $SD->SITE_RELEASE_VERSION;
    my $db_id = $SD->ENSEMBL_VERSION;
    my $db_name = "ensembl_compara_pan_homology_".$release_version."_".$db_id;

    my $db = @{ Bio::EnsEMBL::Registry->get_all_DBAdaptors_by_dbname($db_name) }[0];

    my $SQL = qq(select 
                distinct g.name name, g.taxon_id taxon_id, n.name sci_name
                from ncbi_taxa_name n, genome_db g 
                join species_set using (genome_db_id) 
                join method_link_species_set using (species_set_id) 
                join method_link m using (method_link_id) 
                where g.taxon_id = n.taxon_id and n.name_class = "scientific name"
                order by n.name);
    my $sth = $db->dbc->prepare($SQL);
    $sth->execute();

    my ($spec_name, %spec_sci_name);
    while (my ($name, $taxon_id, $sci_name) = $sth->fetchrow_array) {
      $spec_sci_name{$name} = $sci_name;
    }

    my $link_style = 'font-size:1.1em;font-weight:bold;text-decoration:none;';

    my %division;

    foreach my $current_species ( keys %spec_sci_name) {
      my $site_hash       = $SD->ENSEMBL_SPECIES_SITE($current_species)  || $SD->ENSEMBL_SPECIES_SITE;

      if (exists $site_hash->{$current_species} && defined $site_hash->{$current_species}) {
        push @{ $division{ $site_hash->{$current_species} } }, $current_species;
      }
    }

    my $html;
    $html .= qq(<a href="/info/docs/compara/pan.nh" class="constant">Species Newick Tree</a><br><br>);
    $html .= qq{<table>};
    foreach my $key ( sort { $a cmp $b} keys %division){

      my $division_heading = ucfirst $key;
      $html .= qq{<tr><td colspan="3" border=1 style="width:50%;padding:0px;padding-top:2em;padding-bottom:0em;"><h3>$division_heading</h3></td>};
      my $total =  @{$division{$key}};
      my $break = int($total / 3);
      $break++ if $total % 3;

      ## Reset total to number of cells required for a complete table
      $total = $break * 3;

      for (my $i=0; $i < $total; $i++) {
        my $col = int($i % 3);
	      if ($col == 0 && $i < ($total - 1)) {
	        $html .= qq(</tr><tr>);
	      }
	      my $row = int($i/3);
	      my $j = $row + $break * $col;

        my $current_species =  defined $division{$key}->[$j] ? $division{$key}->[$j] : '' ;
        my $species = $spec_sci_name{$current_species} || $current_species;
        my $url_hash        = $SD->ENSEMBL_EXTERNAL_URLS($current_species) || $SD->ENSEMBL_EXTERNAL_URLS;

	      my $spsite          = uc $key;
	      my $url             = $url_hash->{$spsite} || '';        # Get the URL for the location
	      $url =~ s/\#\#\#SPECIES\#\#\#/$current_species/;         # Replace ###SPECIES### with the species name
	      $html .= qq(<td style="width:8%;text-align:left;padding-bottom:1em">);
        $html .= qq(<a href="$url/Info/Index/" rel="external" style="$link_style">$species</a>);
        $html .= qq(</td>);
      }

      $html .= qq(</tr>);
    }

    $html .=  qq(</table><br><br>);
    print STAT_P_C $html;
    close STAT_P_C;
}

sub do_interpro {
  my ($db, $species) = @_;
  print STDERR "Get top InterPro hits ($species)..." if $DEBUG;

  ## Best to do this using API!
  
  ## First get all interpro accession IDs
  my $SQL = qq(SELECT i.interpro_ac,
                      x.description,
                      count(*)
                FROM interpro i
                LEFT JOIN xref x ON i.interpro_ac = x.dbprimary_acc
                LEFT JOIN protein_feature pf ON i.id = pf.hit_name
	        WHERE pf.hit_name IS NOT NULL
                GROUP BY pf.hit_name);
  my $sth = $db->dbc->prepare($SQL);
  $sth->execute();

  my $domain;
  while (my ($acc, $descr, $count) = $sth->fetchrow_array) {
    $domain->{$acc}{descr} = $descr;
    $domain->{$acc}{count} += $count;
  }


  if (! keys %$domain) {
      nohits2html($PLUGIN_ROOT, "IPtop500.html", $species);
      print STDERR "no hits, done\n" if $DEBUG;
      return 0;
  }


  use EnsEMBL::Web::DBSQL::DBConnection;
  my $dbc = EnsEMBL::Web::DBSQL::DBConnection->new();
  my $adaptor = $dbc->get_DBAdaptor('core', $species);
  my $ga = $adaptor->get_GeneAdaptor;

  foreach my $ac_id (keys %$domain) { 
    my @genes;
    for my $gene (@{$ga->fetch_all_by_domain($ac_id)}){
      push(@genes,$gene) if($gene->species=~/^$species$/i);
    }
    next if (!@genes);
    $domain->{$ac_id}{genes} = @genes;
    #foreach my $g (@genes) {
    #  $domain->{$acc}{count} += @{ $g->get_all_Transcripts };
    #}
  }

  my @hits;

  my ($number, $file, $bigtable);
  $number = 500;
  $file = "IPtop500.html";
  $bigtable = 1;
  hits2html($PLUGIN_ROOT, $domain, $number, $file, $bigtable, $species);

  print STDERR "done\n" if $DEBUG;
  return 1;
}

sub hits2html {
  my ($ENS_ROOT, $domain, $number, $file, $isbig, $species ) = @_;
  my $interpro_dir = sprintf(STATS_PATH, $ENS_ROOT);

  if( ! -e $interpro_dir ){
    #utils::Tool::info(1, "Creating $interpro_dir" );
    system("mkdir -p $interpro_dir") == 0 or
      ( warning( 1, "Cannot create $interpro_dir: $!" ) && next );
  }

  my $fq_path = $interpro_dir.'/stats_'.$species.'_'.$file;
  open (HTML, ">$fq_path") or warn "Cannot write HTML file for pfam hits: $!\n";
  #utils::Tool::info(1, "Writing file \'$fq_path\'");

  select (HTML);
  $| = 1;

  my $numhits = scalar(keys %$domain);
  if ($numhits < $number){ $number = $numhits;}

  my $date    = `date`;
  chomp($date);

  my @domids = sort { ($domain->{$b}{genes} || 0) <=> ($domain->{$a}{genes} || 0)} keys %$domain;

  print qq(<table class="ss tint fixed data_table no_col_toggle">
  <colgroup>
    <col width="10%" />
    <col width="50%" />
    <col width="20%" />
    <col width="20%" />
  </colgroup>
  <thead>
    <tr>
      <th class="sorting sort_numeric">No.</th>
      <th class="sorting sort_html">InterPro name</th>
      <th class="sorting sort_position_html">Number of genes</th>
      <th class="sorting sort_numeric">Number of Ensembl hits</th>
    </tr>
  </thead>
  <tbody>);

  my @classes = qw(bg1 bg2);
  for (my $i = 0; $i < $number; $i++){
    my $tmpdom  = $domain->{$domids[$i]};
    my $name    = $domids[$i];
    my $gene    = $tmpdom->{genes} || "";
    my $count   = $tmpdom->{count};
    my $descr   = $tmpdom->{descr} || '&nbsp;';
    my $order   = $i+1 || 0;
    @classes    = reverse @classes;

    print qq(
    <tr class="$classes[0]">
      <td class="bold">$order</td>
      <td><a href="http://www.ebi.ac.uk/interpro/entry/$name">$name</a><br />$descr</td>
      <td><a href="/$species/Location/Genome?ftype=Domain;id=$name">$gene</a></td>
      <td>$count</td>
    </tr>
    );
  }

  print qq(
  </tbody>
</table>
<form class="data_table_config" action="#"><input type="hidden" name="iDisplayLength" value="25" /></form>\n);

  close(HTML);
}

sub nohits2html {
  my ($ENS_ROOT, $file, $species ) = @_;
  my $interpro_dir = sprintf(STATS_PATH, $ENS_ROOT);

  warn "ID : $interpro_dir * $species * $file";

  if( ! -e $interpro_dir ){
    #utils::Tool::info(1, "Creating $interpro_dir" );
    system("mkdir -p $interpro_dir") == 0 or
      ( warning( 1, "Cannot create $interpro_dir: $!" ) && next );
  }

  my $fq_path = $interpro_dir.'/stats_'.$species.'_'.$file;
  warn "create $fq_path";
  open (HTML, ">$fq_path") or warn "Cannot write HTML file for pfam hits: $!\n";

  print HTML qq(<table class="ss tint">\n);
  print HTML qq(
<tr class="bg2">
  <td><b>No InterPro data</b></td>
</tr>
</table>
);

  close(HTML);
}

sub regions_table {
  my ($species,$csname,$regions) = @_;
  my $hide = 0;
  my $table_rows = [];
  my %table_row_data;
  my $html = "";
  my $num_regions = scalar @$regions;
  foreach my $slice (@$regions){
    my ($rank) = @{$slice->get_all_Attributes('karyotype_rank')};
      my $start = $slice->length/2 - 2000;
    my $end = $slice->length/2 + 2000;
    $start = 1 if $start < 1;
    $end = $slice->end if $end > $slice->end;
    my $seqname=$slice->seq_region_name;
    my $seq_order = sprintf("%s_%s\n",( $rank ? $rank->value : 0),$seqname);
    $seq_order =~ s/([0-9]+)/sprintf('%06d',$1)/ge;
    my $seq_link=sprintf('<span class="hidden">%s</span><a href="/%s/Location/View?r=%s:%d-%d">%s</a>',$seq_order,$species,$slice->seq_region_name,$start,$end,$seqname);
    my $row_data = {order=>$seq_order, sequence=>$seq_link, length=>$slice->length};
    $table_row_data{$seq_order}=[] unless $table_row_data{$seq_order};
    push(@{$table_row_data{$seq_order}},$row_data);
  }
  foreach my $seq_num ( sort keys %table_row_data){
    push(@$table_rows, @{$table_row_data{$seq_num}});
  }
    
  my $data_table_config = {
  };
  if(10 < scalar @$table_rows){
    $data_table_config->{iDisplayLength}=10;
  }
  my $table_id=$csname . "_table";
  
  my $table = new EnsEMBL::Web::Document::Table([
    { key=>'sequence',  title=>'Sequence', align => 'left',  width=>'auto' },
    { key=>'length',    sort=>'numeric',    title=>'Length (bp)',   align => 'right', width=>'auto' }, 
    ],
    $table_rows,
    {
      code=>1,
      data_table => 1,
      sorting => [ 'sequence asc' ],
      exportable => 0,
      toggleable => 1,
      id => $table_id,
      class=>sprintf("toggle_table no_col_toggle%s", $hide?" hidden":""),
      data_table_config => $data_table_config,
      summary=>"coord system seq regions" 
    }
  );
  $table->{code}=1; # flag needed to process data_table_config
  my $_cs_label = sprintf("%d sequence%s",$num_regions,($num_regions>1)?"s":"");

  $html .= sprintf(qq{
      <dt><a rel="%s" class="toggle set_cookie %s" style="font-weight:normal;" href="#" title="Click to toggle the transcript table">%s</a></dt>
      <dd>%s</dd>
    </dl>
    %s}, 
    $table_id,
    $hide ? 'closed' : 'open',
    $_cs_label,
    ' ',
    $table->render
  );
    
  return qq{<div class="summary_panel">$html</div>};
}

sub render_all_species_page {
  my ($valid_species) = @_;

  my $sitename = $SD->SITE_NAME;
  my $species_resources = get_resources();

  # taxon order:
  my $species_info = {};

  foreach (@$valid_species) {
      $species_info->{$_} = {
        key        => $_,
        name       => $SD->get_config($_, 'SPECIES_BIO_NAME'),
        common     => $SD->get_config($_, 'SPECIES_COMMON_NAME'),
        scientific => $SD->get_config($_, 'SPECIES_SCIENTIFIC_NAME'),
        group      => $SD->get_config($_, 'SPECIES_GROUP'),
        assembly   => $SD->get_config($_, 'ASSEMBLY_NAME')
        };
  }

  my $labels       = $SD->TAXON_LABEL; ## sort out labels
  my (@group_order, %label_check);

  foreach my $taxon (@{$SD->TAXON_ORDER || []}) {
      my $label = $labels->{$taxon} || $taxon;
      push @group_order, $label unless $label_check{$label}++;
  }

  ## Sort species into desired groups
  my %phylo_tree;
  foreach (keys %$species_info) {
      my $group = $species_info->{$_}->{'group'} ? $labels->{$species_info->{$_}->{'group'}} || $species_info->{$_}->{'group'} : 'no_group';
      push @{$phylo_tree{$group}}, $_;
  }
  
  ## Output in taxonomic groups, ordered by common name
  my @taxon_species;
  my $taxon_gr;
  my @groups;
  
  foreach my $group_name (@group_order) {
    my $optgroup     = 0;
    my $species_list = $phylo_tree{$group_name};
    my @sorted_by_common;
    my $gr_name;

    if ($species_list && ref $species_list eq 'ARRAY' && scalar @$species_list) {
      @sorted_by_common = sort { $a cmp $b } @$species_list;
      if ($group_name eq 'no_group') {
        if (scalar @group_order) {
          $gr_name = "Other species";
        }
      } else {
        $gr_name = encode_entities($group_name);
      }
      push @groups, $gr_name if (!scalar(@groups)) || grep {$_ ne $gr_name } @groups ;
    }
    unshift @sorted_by_common, $gr_name if ($gr_name);
    push @taxon_species, @sorted_by_common;
  }
  # taxon order eof

  my %species;
  my $group = '';

  foreach my $species (@taxon_species) { # (keys %$species_info) {
    $group =  $species if exists $phylo_tree{$species};
    next if exists $phylo_tree{$species};

    my $common = $SD->get_config($species, "SPECIES_COMMON_NAME");
    my $info = {
      'dir'     => $species,
      'status'  => 'live',
      'provider' => $SD->get_config($species, "PROVIDER_NAME") || '',
      'provider_url' => $SD->get_config($species, "PROVIDER_URL") || '',
      'strain' => $SD->get_config($species, "SPECIES_STRAIN") || '',
      'group' => $group,
      'taxid' => $SD->get_config($species, "TAXONOMY_ID") || '',
    };
    $species{$common} = $info;
  }
  
  my $link_style = 'font-size:1.1em;font-weight:bold;text-decoration:none;';

  my $html = qq(
    <div class="column-wrapper"><div class="box-left" style="width:auto"><h2>$sitename Species</h2></div>
  );

  $html .= qq(<div class="box-left tinted-box round-box unbordered" style="width:70%"><fieldset><legend>Key</legend>);
  $html .= qq(<a style="font-size:1.1em;font-weight:bold;text-decoration:none;" href="#">Species</a> <span title="Has a variation database" style="color:red; cursor:default;">V</span>&nbsp;<span title="Is in pan-taxonomic compara" style="color:red; cursor:default;">P</span>&nbsp;<span title="Has whole genome DNA alignments" style="color:red; cursor:default;">G</span>&nbsp;<span title="Has other alignments" style="color:red; cursor:default;">A</span><p>Provider | <i>Scientific name</i> | Taxonomy ID</p>);
#  my @species = sort keys %species;
  $html .= qq(<p><font color="red">V</font> - has a variation database, <font color="red">P</font> - is in pan-taxonomic compara,
     <font color="red">G</font> - has whole genome DNA alignments, <font color="red">A</font> - has other alignments</p>);
  $html .= qq(</fieldset></div></div>);

  my %groups = map {$species{$_}->{group} => 1} keys %species;

  foreach my $gr (@groups) {  # (sort keys %groups) {
    my @species = sort grep { $species{$_}->{'group'} eq $gr } keys %species;

    my $total = scalar(@species);
    my $break = int($total / 3);
    $break++ if $total % 3;
    my $colspan = $break * 2;

    $html .= qq{<table style="width:100%">
      <tr>
        <td colspan="$colspan" style="width:50%;padding-top:1em">
          <h3>$gr</h3>
        </td>
    };

    ## Reset total to number of cells required for a complete table
    $total = $break * 3;
    my $cell_count = 0;

    for (my $i=0; $i < $total; $i++) {
      my $col = int($i % 3);

      if ($col == 0 && $i < ($total - 1)) {
        $html .= qq(</tr>\n<tr>);
      }
      my $row = int($i/3);
      my $j = $row + $break * $col;

      my $common = $species[$j];
      next unless $common;
      my $info = $species{$common};

      my $dir = $info->{'dir'};

      my $index = first_index { $_->{species} eq lc($dir) } @$species_resources;

      (my $name = $dir) =~ s/_/ /;
      my $link_text = $common =~ /\./ ? $name : $common;

      $html .= qq(<td style="width:8%;text-align:right;padding-bottom:1em">);
      if ($dir) {
        $html .= qq(<img class="species-img" style="width:40px;height:40px" src="/i/species/48/$dir.png" alt="$name">);
      }
      else {
        $html .= '&nbsp;';
      }
      $html .= qq(</td><td style="width:25%;padding:2px;padding-bottom:1em">);

      if ($dir) {
        if ($info->{'status'} eq 'pre') {
          $html .= qq(<a href="http://pre.ensembl.org/$dir/" style="$link_style" rel="external">$link_text</a> (preview - assembly only));
        }
        else {
          $html .= qq(<a href="/$dir/Info/Index/"  style="$link_style">$link_text</a>);
          $html .= qq(&nbsp;<span style="color:red; cursor:default;" title="Has a variation database">V</span>)
              if keys %{$$species_resources[$index]->{variation}};

          $html .= qq(&nbsp;<span style="color:red; cursor:default;" title="Is in pan-taxonomic compara">P</span>)
              if $$species_resources[$index]->{pan_species};

          $html .= qq(&nbsp;<span style="color:red; cursor:default;" title="Has whole genome DNA alignments">G</span>)
            if (exists $$species_resources[$index]->{compara}->{LASTZ} || exists $$species_resources[$index]->{compara}->{LASTZ_NET}
              || exists $$species_resources[$index]->{compara}->{BLASTZ} || exists $$species_resources[$index]->{compara}->{BLASTZ_NET}
              || exists $$species_resources[$index]->{compara}->{TRANSLATED_BLAT} || exists $$species_resources[$index]->{compara}->{TRANSLATED_BLAT_NET});

          $html .= qq(&nbsp;<span style="color:red; cursor:default;" title="Has other alignments">A</span>)
            if (keys %{$$species_resources[$index]->{bam}} || keys %{$$species_resources[$index]->{features}{proteinAlignFeatures}}
              || keys %{$$species_resources[$index]->{features}{dnaAlignFeatures}});
        }
        
        unless ($common =~ /\./) {
          my $provider = $info->{'provider'};
          my $url  = $info->{'provider_url'};

          my $strain = $info->{'strain'} ? " $info->{'strain'}" : '';
          $name .= $strain;

          if ($provider) {
            if (ref $provider eq 'ARRAY') {
              my @urls = ref $url eq 'ARRAY' ? @$url : ($url);
              my $phtml;

              foreach my $pr (@$provider) {
                my $u = shift @urls;
                if ($u) {
                  $u = "http://$u" unless ($u =~ /http/);
                  $phtml .= qq{<a href="$u" title="Provider: $pr">$pr</a> &nbsp;};
                } else {
                  $phtml .= qq{$pr &nbsp;};
                }
              }

              $html .= qq{<br />$phtml | <i>$name</i>};
            } else {
              if ($url) {
                $url = "http://$url" unless ($url =~ /http/);
                $html .= qq{<br /><a href="$url" title="Provider: $provider">$provider</a> | <i>$name</i>};
              } else {
                $html .= qq{<br />$provider | <i>$name</i>};
              }
            }
          } else {
              $html .= qq{<br /><i>$name</i>};
          }
        }
        if($info->{'taxid'}){
          (my $uniprot_url = $SD->ENSEMBL_EXTERNAL_URLS->{'UNIPROT_TAXONOMY'}) =~ s/###ID###/$info->{taxid}/;
          $html .= sprintf(' | <a href="%s" title="Taxonomy ID: %s">%s</a>',$uniprot_url, $info->{'taxid'}, $info->{'taxid'});
        }
      }
      else {
        $html .= '&nbsp;';
      }
      $html .= '</td>';
      $cell_count++;
    }

    # add empty cells to the row if needed: 
    if($cell_count < 3) {
      for (my $i = $cell_count; $i < 3; $i++) {
        $html .= qq(<td>&nbsp;</td><td>&nbsp;</td>);
      }
    }

    $html .= qq(
      </tr>
      </table>
    );
  }

  # write into html file
  my $dir = $SERVERROOT.'/eg-plugins/'.$SD->GENOMIC_UNIT.'/htdocs/info/data/';

  &check_dir($dir);
  my $resources = $dir."resources.html";

  open RESOURCES, ">$resources" or die "ERROR: Can't open file to write resources $!";;
  print RESOURCES $html;
  close RESOURCES;
  print "All the species resources file generated $resources\n";
}

sub get_resources {
  open FILE, "<".$SiteDefs::ENSEMBL_SERVERROOT."/eg-plugins/common/htdocs/species_metadata.json";
  my $file_contents = do { local $/; <FILE> };
  close FILE;

  if (valid_json ($file_contents)) {
    my $data = json_to_perl ($file_contents);
    return $data->{genome};
  }
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

B<--coordsys>
  Print a table of Coordinate Systems (chromosomes, contigs, ...)

B<--all_species_page>
  Generates all the species resources file and puts it in
  eg-plugin/group/htdocs/info/data/resources.html

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
