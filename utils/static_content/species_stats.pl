#!/localsw/bin/perl

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

use vars qw( $SERVERROOT $PLUGIN_ROOT $SCRIPT_ROOT $DEBUG $FUDGE $NOINTERPRO $NOSUMMARY $help $info @user_spp $allgenetypes $coordsys);

BEGIN{
  &GetOptions( 
               'help'      => \$help,
               'info'      => \$info,
               'species=s' => \@user_spp,
	       'a' => \$allgenetypes,
               'debug'     => \$DEBUG,
               'nointerpro'=> \$NOINTERPRO,
               'nosummary' => \$NOSUMMARY,
               'plugin_root=s' => \$PLUGIN_ROOT,
               'coordsys' => \$coordsys,
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
use EnsEMBL::Web::Document::Table;

my $SD = EnsEMBL::Web::SpeciesDefs->new();
my $pre = $PLUGIN_ROOT =~ m#sanger-plugins/pre# ? 1 : 0;
$NOINTERPRO = 1 if $pre;

# get a list of valid species for this release
my $release_id = $SD->ENSEMBL_VERSION;
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


##---------------------------- CREATE STATS ---------------------------------

my $dbconn = EnsEMBL::Web::DBSQL::DBConnection->new(undef, $SD);

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
  }
  else {

    ## PREPARE TO WRITE TO OUTPUT FILE
    my $fq_path_dir = sprintf( STATS_PATH, $PLUGIN_ROOT);
    #print $fq_path_dir, "\n";
    &check_dir($fq_path_dir);
    my $fq_path_html = $fq_path_dir."stats_$spp.html";
    open (STATS, ">$fq_path_html") or die "Cannot write $fq_path_html: $!";

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
    #my $b_method  = ucfirst($SD->get_config($spp, 'GENEBUILD_METHOD')) || '';
    my @A = @{$meta_container->list_value_by_key('genebuild.method')};
    my $b_method  = ucfirst($A[0]) || '';
    $b_method =~ s/_/ /g;
    $b_method   || warn "[ERROR] $spp missing SpeciesDefs->GENEBUILD_METHOD!" unless $pre;

    my $data_version = $SD->get_config($spp, 'SPECIES_RELEASE_VERSION');
    my $db_id = $release_id;
		$db_id .= '.'.$data_version unless $pre;
    #print "Version $data_version\n";
    my $strucvar;
##----------------------- NASTY RAW SQL STUFF! ------------------------------

    ## logicnames for valid genes
    my $genetypes = "'ensembl', 'ensembl_havana_gene', 'havana', 'ensembl_projection',
      'ensembl_ncRNA', 'ncRNA', 'tRNA', 'pseudogene', 'retrotransposed', 'human_ensembl_proteins',
      'ncRNA_pseudogene', 'havana_ig_gene','ensembl_ig_gene', 'ensembl_lincrna', 'ensembl_havana_lincrna',
      'flybase', 'wormbase', 'vectorbase', 'sgd', 'HOX', 'CYT', 'GSTEN', 'MT_genbank_import'";

    my $authority = $SD->get_config($spp, 'AUTHORITY');
    if( $authority ){
      $genetypes .= sprintf(", '%s'",$authority);
    }

    my ($known, $novel, $proj, $annotated, $pseudo, $rna, $ig_segments, $exons, $transcripts, $snps);  

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

      ( $annotated ) = &query( $db,
        "select count(*)
         from gene
         where biotype = 'protein_coding'
         and status = 'ANNOTATED'
        ");
      print "Annotated Genes:$annotated\n" if $DEBUG;

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
        and a.logic_name in ('ensembl_ig_gene','havana_ig_gene')
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
	if ($allgenetypes) {
	    ( $transcripts )= &query( $db,
				      "select count(distinct t.transcript_id)
        from transcript t, gene g, analysis a
        where t.gene_id = g.gene_id
        and g.analysis_id = a.analysis_id
        ");
	} else {
	    ( $transcripts )= &query( $db,
				      "select count(distinct t.transcript_id)
        from transcript t, gene g, analysis a
        where t.gene_id = g.gene_id
        and g.analysis_id = a.analysis_id
        and a.logic_name in ($genetypes)
        ");
	}
      print "Transcripts:$transcripts\n" if $DEBUG;
	if ($allgenetypes) {
	    ( $exons )= &query( $db,
				"select count(distinct et.exon_id)
      from exon_transcript et, transcript t, gene g, analysis a
      where et.transcript_id = t.transcript_id
      and  t.gene_id = g.gene_id
      and g.analysis_id = a.analysis_id
      ");
	} else {
	    ( $exons )= &query( $db,
				"select count(distinct et.exon_id)
      from exon_transcript et, transcript t, gene g, analysis a
      where et.transcript_id = t.transcript_id
      and  t.gene_id = g.gene_id
      and g.analysis_id = a.analysis_id
      and a.logic_name in ($genetypes)
      ");
	}
	    print "Exons:$exons\n" if $DEBUG;

      $snps = 0;
      $strucvar = 0;
      if ($var_db) {
        ($snps) = &query ( $var_db,
          "SELECT COUNT(DISTINCT variation_id) FROM variation_feature",
          );
        print "SNPs, etc:$snps\n" if $DEBUG;
        ($strucvar) = &query ( $var_db,
          "SELECT COUNT(DISTINCT structural_variation_id) FROM structural_variation",
          );
        print "Structural variations:$strucvar\n" if $DEBUG;
      }
    }

  ## Total number of base pairs

    my ( $bp ) = &query( $db, "SELECT SUM(LENGTH(sequence)) FROM dna");    

    print "Total base pairs: $bp.\n" if $DEBUG;

  ## Golden path length

    my ( $gpl ) = &query( $db,
      "SELECT sum(length) 
        FROM seq_region sr, seq_region_attrib sra, attrib_type at, coord_system cs 
        WHERE 
          sr.seq_region_id = sra.seq_region_id
          AND sra.attrib_type_id = at.attrib_type_id 
          AND sr.coord_system_id = cs.coord_system_id 
          AND at.code = 'toplevel' 
          AND cs.name != 'lrg' 
          AND sr.seq_region_id NOT IN 
            (SELECT DISTINCT seq_region_id FROM assembly_exception ae WHERE ae.exc_type != 'par' )
        "
    );

    print "Golden path length: $gpl.\n" if $DEBUG;


  ##-----------------------List all coord systems region counts----------------
  my $b_coordsys="";
  if($coordsys){
    $b_coordsys=qq{<h3>Coordinate Systems</h3>\n<table class="ss tint species-stats">};
    my $sa = $db_adaptor->get_adaptor('slice');
    my $csa = $db_adaptor->get_adaptor('coordsystem');
    my $row_count=0;
    foreach my $cs (sort {$a->rank <=> $b->rank} @{$csa->fetch_all}){
      my @regions = @{$sa->fetch_all($cs->name)};
      my $count_regions = scalar @regions;
      my $regions_html;
      if(!$row_count){#$count_regions < 10000){
        $regions_html = regions_table($spp,$cs->name,\@regions);
      }
      else{
        $regions_html = sprintf("%d %s",$count_regions,($count_regions>1)?"sequences":"sequence");
      }
      $row_count++;
      $b_coordsys .= sprintf(qq{
        %s 
        <td class="data">%s</td>
        <td class="value">%s</td>
        </tr>},
        stripe_row($row_count),
        $cs->name,
        $regions_html);
    }
    $b_coordsys .= "</table>\n";
  }
    
  ##--------------------------- DO INTERPRO STATS -----------------------------

    my $ip_tables = do_interpro($db, $spp) unless $NOINTERPRO;

  ##--------------------------- OUTPUT STATS TABLE -----------------------------

    print STATS qq(<h3 class="boxed">Summary</h3>

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

    $bp = thousandify($bp);
    $row = stripe_row($rowcount);
    print STATS qq($row
          <td class="data">Base Pairs:</td>
          <td class="value">$bp</td>
      </tr>);

    $rowcount++;
    $gpl = thousandify($gpl);
    $row = stripe_row($rowcount);
    print STATS qq($row
          <td class="data">Golden Path Length:</td>
          <td class="value">$gpl</td>
      </tr>
    );

    unless ($pre) {

      print STATS qq(<tr class="bg2">
          <td class="data">Genebuild by:</td>
          <td class="value">$b_id</td>
      </tr>
      <tr>
          <td class="data">Genebuild method:</td>
          <td class="value">$b_method</td>
      </tr>
      <tr class="bg2">
          <td class="data">Genebuild started:</td>
          <td class="value">$b_start</td>
      </tr>
      <tr>
          <td class="data">Genebuild released:</td>
          <td class="value">$b_release</td>
      </tr>
      <tr class="bg2">
          <td class="data">Genebuild last updated/patched:</td>
          <td class="value">$b_latest</td>
      </tr>
  </table>
  );
 ######################
######################
 
      print STATS qq(
  <h3>Gene counts</h3>
  <table class="ss tint species-stats">
  );
      $rowcount = 0;

      if ($known) {
        $known = thousandify($known);
        $rowcount++;
        $row = stripe_row($rowcount);
        print STATS qq($row
          <td class="data">Known protein-coding genes:</td>
          <td class="value">$known</td>
      </tr>
      );
      }

      if ($proj) {
        $proj = thousandify($proj);
        $rowcount++;
        $row = stripe_row($rowcount);
        print STATS qq($row
          <td class="data">Projected protein-coding genes:</td>
          <td class="value">$proj</td>
      </tr>
      );
      }

      if ($novel) {
        $novel = thousandify($novel);
        $rowcount++;
        $row = stripe_row($rowcount);
        print STATS qq($row
          <td class="data">Novel protein-coding genes:</td>
          <td class="value">$novel</td>
      </tr>
      );
      }

      if ($annotated) {
	  $annotated = thousandify($annotated);
	  $rowcount++;
	  $row = stripe_row($rowcount);
        print STATS qq($row
          <td class="data">Annotated protein-coding genes:</td>
          <td class="value">$annotated</td>
      </tr>
        );
      }

      if ($pseudo) {
        $pseudo = thousandify($pseudo);
        $rowcount++;
        $row = stripe_row($rowcount);
        print STATS qq($row
          <td class="data">Pseudogenes:</td>
          <td class="value">$pseudo</td>
      </tr>
      );
      }

      if ($rna) {
        $rna = thousandify($rna);
        $rowcount++;
        $row = stripe_row($rowcount);
        print STATS qq($row
          <td class="data">RNA genes:</td>
          <td class="value">$rna</td>
      </tr>
      );
      }

      if ($ig_segments) {
        $ig_segments = thousandify($ig_segments);
        $rowcount++;
        $row = stripe_row($rowcount);
        print STATS qq($row
          <td class="data">Immunoglobulin/T-cell receptor gene segments:</td>
          <td class="value">$ig_segments</td>
      </tr>
      );
      }

      $rowcount++;
      $exons = thousandify($exons);
      $row = stripe_row($rowcount);
      print STATS qq($row
          <td class="data">Gene exons:</td>
          <td class="value">$exons</td>
      </tr>);

      $rowcount++;
      $transcripts = thousandify($transcripts);
      $row = stripe_row($rowcount);
      print STATS qq($row
          <td class="data">Gene transcripts:</td>
          <td class="value">$transcripts</td>
      </tr>
  </table>
      );
    }

    next unless ($genpept || $genfpept || $fgenpept || $snps || $strucvar || $coordsys );

    print STATS qq(
  <h3>Other</h3>
  <table class="ss tint species-stats">
  );
    $rowcount = 0;

    if ($genpept){
      $genpept = thousandify($genpept);
      $rowcount++;
      $row = stripe_row($rowcount);
      print STATS qq($row
    <td class="data">Genscan gene predictions:</td>
    <td class="value">$genpept</td>
  </tr>);
    }

    if ($genfpept){
      $genfpept = thousandify($genfpept);
      $rowcount++;
      $row = stripe_row($rowcount);
      print STATS qq($row
    <td class="data">Genefinder gene predictions:</td>
    <td class="value">$genfpept</td>
  </tr>);
    }

    if ($fgenpept){
      $fgenpept = thousandify($fgenpept);
      $rowcount++;
      $row = stripe_row($rowcount);
      print STATS qq($row
    <td class="data">FGENESH gene predictions:</td>
    <td class="value">$fgenpept</td>
  </tr>);
    }

    if ($snps) {
      $rowcount++;
      $snps = thousandify($snps);
      $row = stripe_row($rowcount);
      print STATS qq($row
          <td class="data">Short Variants (SNPs, indels, somatic mutations):</td>
          <td class="value">$snps</td>
          </tr>);
    }

    if ($strucvar) {
      $rowcount++;
      $strucvar = thousandify($strucvar);
      $row = stripe_row($rowcount);
      print STATS qq($row
          <td class="data">Structural variants:</td>
          <td class="value">$strucvar</td>
          </tr>);
    }

    print STATS '</table>';
    
    if($coordsys){
      print STATS $b_coordsys;
    }

    close(STATS);
  }
} # end of species


exit;



#############################################################################

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
  my ($db, $species) = @_;

  ## Best to do this using API!
  
  ## First get all interpro accession IDs
  my $SQL = qq(SELECT  i.interpro_ac,
                      x.description,
                      count(*)
                FROM  interpro i
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

  warn "HEY ! ($species)";

  if (! keys %$domain) {
      nohits2html($PLUGIN_ROOT, "IPtop40.html", $species);
      nohits2html($PLUGIN_ROOT, "IPtop500.html", $species);
      return 0;
  }


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
  hits2html($PLUGIN_ROOT, $domain, $number, $file, $bigtable, $species);

  $number = 500;
  $file = "IPtop500.html";
  $bigtable = 1;
  hits2html($PLUGIN_ROOT, $domain, $number, $file, $bigtable, $species);

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

  print qq(<table class="ss tint">\n);
  print qq(<tr>
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
    my $descr1 = $tmpdom1->{descr} || '&nbsp;';

    my $name2  = $domids[$i + $number/2];
    my $gene2  = $tmpdom2->{genes};
    my $count2 = $tmpdom2->{count};
    my $descr2 = $tmpdom2->{descr} || '&nbsp;';

    my $order1 = $i+1 || 0;
    my $order2 = $i+($number/2)+1 || 0;
    my $class = shift @class;
    push @class, $class;

  print qq(
<tr $class>
  <td><b>$order1</b></td>
  <td><a href="http://www.ebi.ac.uk/interpro/IEntry?ac=$name1">$name1</a><br />$descr1</td>
  <td><a href="/$species/Location/Genome?ftype=Domain;id=$name1">$gene1</a></td>
  <td>$count1</td>
  <td><b>$order2</b></td>
  <td><a href="http://www.ebi.ac.uk/interpro/IEntry?ac=$name2">$name2</a><br />$descr2</td>
  <td><a href="/$species/Location/Genome?ftype=Domain;id=$name2">$gene2</a></td>
  <td>$count2</td>
</tr>
);
  }

  print("</table>");

  my $interpro_path = "/$species/Info";
  if($isbig == 0){
    # the Top40 page
    print qq(<p class="center"><a href="$interpro_path/IPtop500">View</a> top 500 InterPro hits (large table)</p>);
  }
  else{
    # >top40  page
    print qq(<p class="center"><a href="$interpro_path/IPtop40">View</a> top 40 InterPro hits</p>);
  }

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
  my $hide = 1;
  my $table_rows = [];
  my %table_row_data;
  my $html = "";
  my $num_regions = scalar @$regions;
  foreach my $slice (@$regions){
    my $start = $slice->length/2 - 2000;
    my $end = $slice->length/2 + 2000;
    $start = 1 if $start < 1;
    $end = $slice->end if $end > $slice->end;
    my $seqname=$slice->seq_region_name;
    my $seq_order=0;
    if($seqname =~ /([0-9.]+)$/){$seq_order=$1;}
    my $seq_link=sprintf('<span class="hidden">%06d</span><a href="/%s/Location/View?r=%s:%d-%d">%s</a>',$seq_order,$species,$slice->seq_region_name,$start,$end,$seqname);
    my $row_data = {order=>$seq_order, sequence=>$seq_link, length=>$slice->length};
    $table_row_data{$seq_order}=[] unless $table_row_data{$seq_order};
    push(@{$table_row_data{$seq_order}},$row_data);
  # push(@{$table_rows},$row_data);
  }
  foreach my $seq_num ( sort {$a <=> $b} keys %table_row_data){
    push(@$table_rows, @{$table_row_data{$seq_num}});
  }
    
  my $data_table_config = {
  };
  if(10 < scalar @$table_rows){
    $data_table_config->{iDisplayLength}=10;
  }
  my $table_id=$csname . "_table";
  
  my $table = new EnsEMBL::Web::Document::Table([
    { key=>'sequence',  title=>'Sequence', align => 'left',  width=>'45%' },
    { key=>'length',    sort=>'numeric',    title=>'Length (bp)',   align => 'right', width=>'10%' }, 
    ],
    $table_rows,
    {
      code=>1,
      data_table => 1,
      width => '400px',
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
