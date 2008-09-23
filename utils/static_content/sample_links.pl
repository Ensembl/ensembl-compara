#!/usr/local/bin/perl

#############################################################################
#
# SCRIPT TO CHECK AND UPDATE LINKS LIST IN INI FILES (as used to generate
# sitemaps and links on error pages)
# Default is to do all configured species, or pass an array of
# species names (typically in Genus_species format)
#
#############################################################################


use strict;
use FindBin qw($Bin);
use File::Basename qw( dirname );
use Data::Dumper;
use Getopt::Long qw(:config no_ignore_case);
use CGI;
use DBI;

######################### cmdline options #####################################
our $VERBOSITY;
my ($help, @species, $site_type, $log, $GUESS);
&GetOptions(
      'help'        => \$help,
      'verbose:s'   => \$VERBOSITY,
      'species:s'   => \@species,
      'guess'       => \$GUESS,  # select a random sample if example not found
      'site_type:s' => \$site_type,
      'log'         => \$log,
);

if(defined $help) {
    die qq(
    Usage: $0 [options]
    Options:
    --species
    --site_type
    -h       = help
    );
}
warn $site_type;
$VERBOSITY = defined($VERBOSITY) ? $VERBOSITY: 1;

if ($log) {
  my $logfile = 'links.log';
  open(LOG, '>>', $logfile) or die("Couldn't open log file $log: $!");
  my @now = localtime();
  my $timestamp = $now[5].'-'.$now[4].'-'.$now[3].' '.$now[2].':'.$now[1].':'.$now[0];
  print LOG "$timestamp\n\n";
}

########################### Set up big variables ##############################
use vars qw( $SERVERROOT );
BEGIN{
  $SERVERROOT = dirname( $Bin );
  $SERVERROOT =~ s#/utils##;
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

## Load webcode
use EnsEMBL::Web::Proxy::Factory;
use EnsEMBL::Web::RegObj;

$ENSEMBL_WEB_REGISTRY = EnsEMBL::Web::Registry->new();
our $SPECIES_DEFS = $ENSEMBL_WEB_REGISTRY->species_defs;

$SPECIES_DEFS || pod2usage("$0: SpeciesDefs config not found");
my @species_inconf = @{$SiteDefs::ENSEMBL_SPECIES};
my $path = "$SERVERROOT/perl";

## Species to create examples for:
if (!@species) {  @species = @species_inconf; }


######################## SET UP VIEW PARAMETERS ##############################

our %views = (
  alignview           => {}, ## no entry
  alignsliceview      => {}, ## no entry
  contigview          => {'object'=>'Location', 'random' => 'rand_location'},
  cytoview            => {'object'=>'Location', 'random' => 'rand_location'},
  dasconfview         => {}, ## no entry
  domainview          => {'object'=>'Domain', 'random' => 'rand_domain'},
  dotterview          => {}, ## no entry
  exonview            => {'object'=>'Transcript', , 'random' => 'rand_trans'},
  exportview          => {}, ## no entry
  fastaview           => {}, ## no entry
  familyview          => {'keep'=>'no', 'random' => 'rand_family'},
  featureview         => {'object'=>'Feature'},
  geneview            => {'object'=>'Gene', 'random' => 'rand_gene'},
  geneseqview         => {'object'=>'Gene', 'random' => 'rand_gene'},
  geneseqalignview    => {'object'=>'Gene', 'random' => 'rand_gene'},
  genetreeview        => {'object'=>'Gene', 'random' => 'rand_tree'},
  genespliceview      => {'object'=>'Gene', 'random' => 'rand_splice'},
  generegulationview  => {'keep'=>'yes'}, ## Gene reg now in separate database
  genesnpview         => {'object'=>'Gene', 'random' => 'rand_genesnp'},
  glossaryview        => {}, ## no entry
  goview              => {},
  haploview           => {}, ## no entry
  helpview            => {}, ## no entry
  historyview         => {'keep'=>'yes'},
  idhistoryview       => {'object'=>'Gene', 'random' => 'rand_gene'},
  karyoview           => {'keep'=>'yes'},
  ldview              => {'keep'=>'yes'}, ## keep existing links!
  ldtableview         => {'keep'=>'yes'}, ## keep existing links!
  mapview             => {'object'=>'Chromosome', 'random' => 'rand_chr'},
  markerview          => {'object'=>'Marker', 'random' => 'rand_marker'},
  miscsetview         => {}, ## no entry (used to be cytodump)
  multicontigview     => {'keep'=>'yes'},  ## keep existing links!
  newsview            => {}, ## no entry
  primerview          => {}, ## no entry
  protview            => {'object'=>'Translation', 'random' => 'rand_trans'},
  searchview          => {}, ## no entry
  sequencealignview   => {'object'=>'Location', 'random' => 'rand_location'}, 
  snpview             => {'object'=>'SNP', 'random' => 'rand_snp'},
  syntenyview         => {'object'=>'Chromosome', 'random' => 'rand_synteny'},
  tagloview           => {}, ## no entry
  textview            => {}, ## no entry
  transview           => {'object'=>'Transcript', 'random' => 'rand_trans'},
  transcriptsnpview   => {'keep'=>'yes'},
);


########### Get names of view scripts from /perl/default dir #################-
my @configured_views;
my $configured_views_dir = $path."/default";
opendir(DIR, $configured_views_dir) or die "can't open dir $configured_views_dir:$!";
while (defined(my $file = readdir(DIR))) {
  next unless $file =~ /view$/;
  push (@configured_views, $file);
}
close DIR;

# ------------ Check %views list above, is up to date ----------------------
my %cp_views = %views;
foreach (@configured_views) {
  warning(1, "Need to edit script to configure '$_'.  Is it new?") unless $views{$_};
  delete ($cp_views{$_});
}

foreach (keys %cp_views) {
  warning (1, "Are these views still in use: $_");
}

################# Multi-species database info ###############################

our %synteny;
if ($site_type ne 'pre') {
  %synteny  = %{$SPECIES_DEFS->get_config("Multi", "SYNTENY")};
}

################# Loop through all spp and get examples ######################
foreach my $sp (@species) {
  info (1, "---------------Processing $sp ----------------------");

  ## work on a copy of the view hash
  my %sp_views = %views;

  ## get species-specific db info
  my %db        = %{$SPECIES_DEFS->get_config($sp,  "databases")};
  die "No database!" unless $db{'DATABASE_CORE'};

  #------------- tidy up view list for this species -------------------------

  ## remove some views for pre (no compara, interpro, etc)
  if ($site_type eq 'pre') {
    delete($sp_views{domainview});
    delete($sp_views{familyview});
    delete($sp_views{genetreeview});
    delete($sp_views{genespliceview});
    delete($sp_views{geneseqview});
    delete($sp_views{geneseqalignview});
    delete ($sp_views{historyview});
    delete ($sp_views{idhistoryview});
    delete ($sp_views{ldview});
    delete ($sp_views{ldtableview});
  }

  ## Synteny
  delete ($sp_views{syntenyview}) unless $synteny{$sp};
  ## double-check config for running synteny data
  if (keys %synteny && $synteny{$sp}) {
    my $running_total = 0;
    my %species_hash = %{$synteny{$sp}};
    foreach my $key (keys %species_hash) {
      my $running = $species_hash{$key};
      $running_total += $running;
    }
    delete ($sp_views{syntenyview}) unless $running_total > 0;
  }

  ## Chromosomes?
  my $has_chr = @{$SPECIES_DEFS->get_config($sp,"ENSEMBL_CHROMOSOMES") || []};
  if (!$has_chr) {
    delete ($sp_views{karyoview});
    delete ($sp_views{mapview});
  }

  ## ID History?
  my $builder = $SPECIES_DEFS->get_config($sp,"GENEBUILD_BY");
  if ($builder !~ /ensembl/i) {
    delete ($sp_views{historyview});
    delete ($sp_views{idhistoryview});
  }

  ## Variation
  if (!$db{'DATABASE_VARIATION'}) {
    delete ($sp_views{snpview});
    delete ($sp_views{genesnpview});
    delete ($sp_views{transcriptsnpview});
  }
  if ($db{'DATABASE_VARIATION'} && !$SPECIES_DEFS->get_config($sp,"VARIATION_STRAIN")) {
    delete ($sp_views{sequencealignview});
  }

  #------------ Read in current .ini file -------------------------------------
  my $ini_file;
  if ($site_type eq 'pre') {
    $ini_file = $SERVERROOT."/sanger-plugins/pre/conf/ini-files/$sp".".ini";
  }
  else {
    $ini_file = $SERVERROOT."/public-plugins/ensembl/conf/ini-files/$sp".".ini";
  }
  print "INI: $ini_file\n";
  open (INI, "<",$ini_file) or die "Couldn't open ini file $ini_file: $!";
  my $out_ini = $ini_file . ".out";
  open (my $fh, ">",$out_ini) or die "Couldn't open ini file $out_ini: $!";

  ## write out old ini contents, putting search links into a hash
  my $links = 0;
  my %current_eg;
  while (<INI>) {
    my $line = $_;
    if ($line =~ /END SEARCH_LINKS/) {
      $links = 0;
      next;
    }
    if ($line =~ /\[SEARCH_LINKS\]/) {
      $links = 1;
      next;
    }
    if ($links) {
      next unless $line =~ m/[a-zA-Z]+/;
      my ($key, $value) = split(' = ', $line);
      $key =~ s/ //g;
      chomp($value) if $value;
      $current_eg{$key} = $value;
    }
    else {
      print $fh $line;
    }
  }
  close INI;

  # ---------- Get current examples and defaults ----------------------------
  ## Values of VIEW keys are URLs in format "viewname(?a=x(;b=y(;c=z)))"
  if (keys %current_eg) {

    foreach (keys %current_eg){
      ## Capture the configured DEFAULT examples
      if ($_ =~ /DEFAULT.*URL/) {
        (my $view_type = $current_eg{$_}) =~ s/(.+view)\?.*/$1/;
        $views{$view_type}{default} = $current_eg{$_} if $views{$view_type};
      }
    }
  }

  ## Start assembling link text
  my $output = "[SEARCH_LINKS]\n";
  my $ok_params;
  my %oked_defaults;

  # ---------- Check current examples against database  --------------------
  foreach my $view (sort keys %views) {
    info (1, "$view ...");
    next if !$sp_views{$view};
    if (!keys %{$sp_views{$view}}) { ## no link required
      info (1, "Skipping $view - no options configured\n");
      next;
    }

    ## Try to create object using existing parameters
    my @eg = ( $current_eg{uc($view)."1_URL"},
              $current_eg{uc($view)."2_URL"} );
    my $count;

    my ($text, $url);
    if ($eg[0]) {
      foreach my $eg (@eg) {
        $count++;
        next unless $eg;
        $text = ''; 
        $url = '';

        if ($views{$view}{'keep'} eq 'yes') {
          info (1, "Keeping example $count for $view\n");
          $text = $current_eg{uc($view).$count.'_TEXT'};
          $url  = $current_eg{uc($view).$count.'_URL'};
        }
        else {
          ## parse parameters
          my $input = new CGI;
          (my $string = $eg) =~ s/[a-z]+\?//;
          my @pairs = split(';', $string);
          foreach my $param (@pairs) {
            my ($key, $value) = split('=', $param);
            $input->param($key, $value);
          }
          my $factory = EnsEMBL::Web::Proxy::Factory->new($sp_views{$view}{'object'}, 
                                                    {'_input'=>$input, '_species'=>$sp});
          
          ## get new data where needed
          my $random = 0;
          if ($views{$view}{'keep'} eq 'no') {
            info (1, "Fresh example required for $view\n");
            $random = 1;
          }
          elsif ($factory->has_a_problem) {
            info (1, "Example $count for $view not found\n");
            $random = 1;
          }
          else {
            info (1, "Example $count for $view - OK!\n");
          }
          if ($random && $views{$view}{'random'}) {
            no strict "refs";
            info (1, "Attempting to find random sample data for $view\n");
            my $method = $views{$view}{'random'};
            my $new = &$method(\%db, $sp, $view, {site_type => $site_type, eg => $eg, count => $count});
            $text = $new->{text};
            $url  = $new->{url};
            if ($url) {
              info (1, "New example found for $view\n");
            }
          }
          else {
            $text = $current_eg{uc($view).$count.'_TEXT'};
            $url  = $current_eg{uc($view).$count.'_URL'};
          }
        }
        $output .= format_entry($view, $count, $text, $url);
      }
      $output .= "\n";
    }
    else { ## new view!
      for (my $i = 1; $i < 3; $i++) {
        $text = ''; 
        $url = '';
        if ($views{$view}{'random'}) {
          no strict "refs";
          info (1, "Attempting to find random sample data for new $view\n");
          my $method = $views{$view}{'random'};
          my $new = &$method(\%db, $sp, $view, {site_type => $site_type, count => $i});
          $text = $new->{text};
          $url  = $new->{url};
          if ($url) {
            info (1, "New example found for $view\n");
          }
        }
        $output .= format_entry($view, $i, $text, $url);
      }
      $output .= "\n";
    }
  } ## end of view loop
  print $fh $output if $output;

  ## finish ini file ---------------------------------------------------------

  print $fh "\n\n## END SEARCH_LINKS - N.B. DO NOT DELETE THIS LINE!!!\n\n";

  close $fh;

  system ("mv $ini_file $ini_file.bck");
  system ("mv $out_ini $ini_file");

} ## end of species loop

if ($log) {
  print LOG "\n************************************************\n";
  close LOG;
}

exit;

################### RANDOM FEATURES ########################################

sub rand_chr {
  my ($db, $sp, $view, $options) = @_;
  my $dbs = get_dbs($db, ['DATABASE_CORE']);
  my $dbh = get_handle($dbs, 'DATABASE_CORE');
  my $params = {'name' => 'chr'};
  my $sql = qq(SELECT sr.name 
                FROM seq_region sr LEFT JOIN coord_system c ON sr.coord_system_id = c.coord_system_id 
                LEFT JOIN assembly_exception ae ON ae.seq_region_id = sr.seq_region_id 
                LEFT JOIN seq_region_attrib sra ON sr.seq_region_id = sra.seq_region_id 
                LEFT JOIN attrib_type at ON sra.attrib_type_id = at.attrib_type_id 
                WHERE at.code = 'toplevel' 
                AND (ae.exc_type != 'HAP' OR ae.exc_type IS NULL) 
                AND c.name = 'chromosome' ORDER BY rand() LIMIT 1);
  my $eg = do_query($dbh, $sql, $view, $params);
  return $eg;
}

sub rand_synteny {
  my ($db, $sp, $view, $options) = @_;
  my $eg = rand_chr($db, $sp, $view, $options);
  my @spp = keys %{$synteny{$sp}};
  srand;
  my $other_species = $spp[rand(@spp)];
  $eg->{'url'} .= ';otherspecies='.$other_species;
  $eg->{'text'} = 'Chr '.$eg->{'text'}.': synteny with '.$other_species;
  return $eg;
}

sub rand_domain {
  my ($db, $sp, $view, $options) = @_;
  $sp =~ s/_/ /g;
  my $dbs = get_dbs($db, ['DATABASE_CORE']);
  my $dbh = get_handle($dbs, 'DATABASE_CORE');
  my $params = {'interpro_ac' => 'domainentry'};
  my $sql = qq(SELECT i.interpro_ac, count( distinct tr.gene_id ) as c
                             FROM interpro as i, protein_feature as pf,
                                  transcript as tr, translation as tl
                             WHERE i.id = pf.hit_id and
                                   pf.translation_id = tl.translation_id and
                                   tr.transcript_id = tl.transcript_id
                             GROUP BY i.interpro_ac
                             HAVING c between 20 and 50
                             ORDER BY rand());
  my $eg = do_query($dbh, $sql, $view, $params);
  return $eg; 
}

sub rand_family {
  my ($db, $sp, $view, $options) = @_;
  return if $options->{site_type} eq 'pre'; ## No compara in pre
  $sp =~ s/_/ /g;
  my $dbs = get_dbs($db, ['DATABASE_COMPARA']);
  my $dbh = get_handle($dbs, 'DATABASE_COMPARA');
  my $params = {'stable_id' => 'family'};
  my $sql = qq(SELECT f.stable_id
                    FROM  family as f, genome_db,  family_member as fm,
                          member as m
                    WHERE m.member_id = fm.member_id and
                          f.family_id = fm.family_id and
                          genome_db.genome_db_id = m.genome_db_id and
                          genome_db.name = '$sp' and
                          m.source_name='ENSEMBLGENE' and
                          f.description != 'UNKNOWN' and
                          f.description != 'AMBIGUOUS'
                   GROUP BY f.stable_id
                   HAVING count(*) between 20 and 50
                   ORDER BY rand() LIMIT 1);
  my $eg = do_query($dbh, $sql, $view, $params);

  if (!$eg) { ## try again!
    $sql = qq(SELECT f.stable_id
                    FROM  family as f, genome_db,
                          family_member as fm, member as m
                    WHERE m.member_id = fm.member_id and
                          f.family_id = fm.family_id and
                          genome_db.genome_db_id = m.genome_db_id and
                          genome_db.name = '$sp' and
                          m.source_name='ENSEMBLGENE' and
                          f.description != 'AMBIGUOUS'
                   GROUP BY f.stable_id
                   HAVING count(*) between 0 and 50
                   ORDER BY rand() LIMIT 1);
    $eg = do_query($dbh, $sql, $view, $params);
  }
  return $eg; 
}

sub rand_feature {
  my ($db, $sp, $view, $options) = @_;
  my $dbs = get_dbs($db, ['DATABASE_CORE']);
  my $dbh = get_handle($dbs, 'DATABASE_CORE');
  my $eg = $options->{eg};

  ## What type of feature?
  my @types = qw(OligoProbe ProteinAlignFeature DnaAlignFeature);
  my ($type, $params, $sql);
  if ($eg) {
    if ($eg =~ /probe/i) {
      $type = $types[0];;
    }
    elsif ($eg =~ /protein/i) {
      $type = $types[1];
    }
    else {
      $type = $types[2];
    }
  }
  else {
    srand;
    $type = $types[rand(2)];
  }

  if ($type eq 'OligoProbe') {
    $params = {'probeset'=>'id','OligoProbe'=>'OligoProbe'};
    $sql = qq(SELECT   probeset, 'AffyProbe'
           FROM   oligo_probe, oligo_feature
           WHERE  oligo_probe.oligo_probe_id = oligo_feature.oligo_probe_id
            ORDER BY rand() LIMIT 1);
  }
  elsif ($type eq 'ProteinAlignFeature') {
    $params = {'hit_name'=>'id', 'ProteinAlignFeature'=>'ProteinAlignFeature'};
    $sql = qq(SELECT hit_name, 'ProteinAlignFeature'
           FROM protein_align_feature ORDER BY rand() LIMIT 1);
  }
  else {
    $params = {'hit_name'=>'id', 'DnaAlignFeature'=>'DnaAlignFeature'};
    $sql = qq(SELECT  hit_name, 'DnaAlignFeature'
           FROM dna_align_feature ORDER BY rand() LIMIT 1);
  }

  my $eg = do_query($dbh, $sql, $view, $params);
  return $eg;
}

sub rand_gene {
  my ($db, $sp, $view, $options) = @_;
  my $dbs = get_dbs($db, ['DATABASE_CORE']);
  my $dbh = get_handle($dbs, 'DATABASE_CORE');
  my ($params, $sql);
  if ($options->{site_type} eq 'pre') {
    $params = {'display_label' => 'gene'};
    $sql =  qq(SELECT xref.display_label
            FROM   gene, xref
            WHERE gene.display_xref_id=xref.xref_id
            ORDER BY rand() LIMIT 1
            );
  }
  else {
    $params = {'stable_id' => 'gene', 'display_label' => 'gene'};
    $sql = qq(SELECT stable_id
            FROM gene_stable_id
            ORDER BY rand() LIMIT 1
            );
  }
  my $eg = do_query($dbh, $sql, $view, $params);
  return $eg;
}

sub rand_genesnp {
  my ($db, $sp, $view, $options) = @_;
  my $dbs = get_dbs($db,  ['DATABASE_CORE', 'DATABASE_VARIATION']);
  my $dbh = get_handle($dbs, 'DATABASE_CORE');
  my $db2 = $dbs->{'DATABASE_VARIATION'}{'name'} || 1;
  my $params = {'stable_id' => 'gene'};
  my $sql = qq(SELECT gs.stable_id
           FROM $db2.gene_stable_id as gs,
                $db2.transcript as t,
                transcript_variation as tv
           WHERE gs.gene_id = t.gene_id and
                 t.transcript_id = tv.transcript_id
            ORDER BY rand() LIMIT 1);
  my $eg = do_query($dbh, $sql, $view, $params);
  return $eg;
}

sub rand_location {
  my ($db, $sp, $view, $options) = @_;
  my $dbs = get_dbs($db, ['DATABASE_CORE']);
  my $dbh = get_handle($dbs, 'DATABASE_CORE');
  ## get a random gene, so we don't have empty sequence!
  my $sql = qq(SELECT seq_region_id, seq_region_start, seq_region_end
                FROM gene
                ORDER BY rand() LIMIT 1;
              );
  my $result = $dbh->selectall_hashref($sql, 1);
  my $eg = undef;
  if (keys %$result) {
    my ($region, $start, $end);
    while (my ($index, $record) = each (%$result)) {
      $region = $record->{'seq_region_id'};
      $start  = $record->{'seq_region_start'};
      $end    = $record->{'seq_region_end'};
      my $length = $end > $start ? $end - $start : $start - $end;
      if ($length < 1000000) {
        my $midpoint = ($length / 2) + $start;
        $start = $midpoint - 500000;
        $end = $midpoint + 500000;
      }
      last;
    }
    $eg =  {'text' => $region, 'url' => $view.'?c='.$region.';start='.$start.';end='.$end}; 
  }
  return $eg;
}

sub rand_marker {
  my ($db, $sp, $view, $options) = @_;
  my $dbs = get_dbs($db, ['DATABASE_CORE']);
  my $dbh = get_handle($dbs, 'DATABASE_CORE');
  my $params = {'name' => 'marker'};
  my $sql = get_simple_sql('name', 'marker_synonym');
  my $eg = do_query($dbh, $sql, $view, $params);
  return $eg;
}

sub rand_snp {
  my ($db, $sp, $view, $options) = @_;
  my $dbs = get_dbs($db,  ['DATABASE_VARIATION']);
  my $dbh = get_handle($dbs, 'DATABASE_VARIATION');
  my $params = {'name' => 'snp'};
  my $sql = get_simple_sql('name', 'variation');
  my $eg = do_query($dbh, $sql, $view, $params);
  return $eg;
}

sub rand_splice {
  my ($db, $sp, $view, $options) = @_;
  my $dbs = get_dbs($db, ['DATABASE_CORE']);
  my $dbh = get_handle($dbs, 'DATABASE_CORE');
  my $params = {'stable_id' => 'gene'};
  my $sql = qq(SELECT g.stable_id, count(*) as x
          FROM transcript as t, gene_stable_id as g
          WHERE t.gene_id = g.gene_id
          GROUP BY t.gene_id
          HAVING x BETWEEN 2 AND 5
          ORDER BY rand() LIMIT 1);
  my $eg = do_query($dbh, $sql, $view, $params);
  return $eg;
}

sub rand_trans {
  my ($db, $sp, $view, $options) = @_;
  my $dbs = get_dbs($db, ['DATABASE_CORE']);
  my $dbh = get_handle($dbs, 'DATABASE_CORE');
  my ($params, $sql);
  if ($options->{site_type} eq 'pre') {
    $params = {'display_label' => 'transcript'};
    $sql = get_simple_sql('display_label', 'prediction_transcript');
  }
  elsif ($view eq 'exonview') {
    $params = {'stable_id' => 'exon'};
    $sql = get_simple_sql('stable_id', 'exon_stable_id');
  }
  elsif ($view eq 'protview') {
    $params = {'stable_id' => 'peptide'};
    $sql = get_simple_sql('stable_id', 'peptide_stable_id');
  }
  else {
    $params = {'stable_id' => 'transcript'};
    $sql = get_simple_sql('stable_id', 'transcript_stable_id');
  }
  my $eg = do_query($dbh, $sql, $view, $params);
  return $eg;
}

sub rand_tree {
  my ($db, $sp, $view, $options) = @_;
  my $dbs = get_dbs($db, ['DATABASE_COMPARA']);
  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

  my $user = $dbs->{'DATABASE_COMPARA'}{user} || $db->{'DATABASE_CORE'}{'USER'};

  my $dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host => $dbs->{'DATABASE_COMPARA'}{host},
                                                       -port => $dbs->{'DATABASE_COMPARA'}{port},
                                                       -user => $user,
                                                       -dbname => $dbs->{'DATABASE_COMPARA'}{name});

  my $gdba = $dba->get_GenomeDBAdaptor;
  my $ma = $dba->get_MemberAdaptor;
  my $pta = $dba->get_ProteinTreeAdaptor;

  my @records;
  foreach my $gdb (@{$gdba->fetch_all}) {
    next unless $gdb->taxon_id;
    my $count = 1;
    foreach my $gene_member (@{$ma->fetch_all_by_source_taxon
('ENSEMBLGENE',$gdb->taxon_id)}) {
      my $longest_peptide_member = $ma->fetch_longest_peptide_member_for_gene_member_id($gene_member->dbID);
      my $node = $pta->fetch_AlignedMember_by_member_id_root_id
($longest_peptide_member->dbID);
      next unless (defined $node);
      my $subroot = $node->subroot;
      if (_good_tree_example($subroot, $pta)) {
        my $species = $gdb->name;
        $species =~ s/ /_/;
        my $id = $gene_member->stable_id;
        push @records, {'gene_stable_id' => $id};
        $count++;
      }
      last if ($count == 3);
    }
  }
  my $record;
  if ($options && $options->{count} == 2) {
    $record = $records[1];
  }
  else {
    $record = $records[0];
  }
  my $text = $record->{'gene_stable_id'};
  my $url = "genetreeview?gene=$text"; 
  return {text => $text, url => $url};
}

sub _good_tree_example {
   my ($node, $pta) = @_;

   if ($node->get_tagvalue('gene_count') > 50 || $node->get_tagvalue
('gene_count') < 15) {
     $node->release_tree;
     return 0;
   }

   my $tree = $pta->fetch_node_by_node_id($node->node_id);
   my %gdbs;
   foreach my $leaf (@{$tree->get_all_leaves}) {
     $gdbs{$leaf->genome_db_id} = 1;
   }
   $tree->release_tree;
   if (scalar keys %gdbs < 10) {
     return 0;
   }
   return 1;
}

sub get_dbs {
  my ($db, $db_ref) = @_;
  my %db_multi = %{$SPECIES_DEFS->get_config("Multi","databases")};
  my $dbs;
  foreach my $db_string ( @$db_ref ){
    if ($db_string eq 'DATABASE_COMPARA' or $db_string eq 'DATABASE_GO') {
      $dbs->{$db_string} = {
            "name" => $db_multi{$db_string}{'NAME'},
            "host" => $db_multi{$db_string}{'HOST'},
            "port" => $db_multi{$db_string}{'PORT'}
          };
    }
    else {
      next unless $db->{$db_string};
      $dbs->{$db_string} = {
            "name" => $db->{$db_string}{'NAME'},
            "host" => $db->{$db_string}{'HOST'},
            "port" => $db->{$db_string}{'PORT'},
          };
    }
  }
  return $dbs;
}

sub get_handle {
  my ($dbs, $db_string) = @_;
  my $dsn = "DBI:mysql:database=".$dbs->{$db_string}{name}
    .":host=".$dbs->{$db_string}{host}.";port=".$dbs->{$db_string}{port};
  my $dbh = DBI->connect($dsn, 'ensro')
    or die "\n[*DIE] Can't connect to database '$dsn'";
  return $dbh;
}

sub get_simple_sql {
  my ($key, $table) = @_;
  return "SELECT $key from $table ORDER BY rand() LIMIT 1";
}

sub do_query {
  my ($dbh, $sql, $view, $params) = @_;

  ## query database
  my $result = $dbh->selectall_hashref($sql, 1);

  ## Convert result into URL
  my $url = undef;
  my $text = undef;
  if (keys %$result) {
    $url = $view.'?';
    my $count = 0;
    while (my ($index, $record) = each (%$result)) {
      while (my ($k, $v) = each (%$record)) {
        $text = $v if $count == 0;
        $url .= $params->{$k}."=$v;";
        $count++;
      }
    }
    $url =~ s/;$//;
  }

  $dbh->disconnect;
  if ($url) {
    return {text => $text, url => $url};
  }
  else {
    return undef;
  }
}

################### UTILITIES ########################################

sub format_entry {
  my ($view, $count, $text, $url) = @_;
  my $output = uc($view).$count."_TEXT = $text\n";
  $output .= uc($view).$count."_URL = $url\n";
  return $output;
}

sub info{
  my $v   = shift;
  my $msg = shift;
  if( ! defined($msg) ){ $msg = $v; $v = 0 }
  $msg || ( carp("Need a warning message" ) && return );

  if ($log) {
    print LOG "[INFO] $msg\n";
  }

  if( $v > $VERBOSITY ){ return 1 }
  warn( "[INFO] ".$msg."\n" );
  return 1;
}

sub warning{
  my $v   = shift;
  my $msg = shift;
  if( ! defined($msg) ){ $msg = $v; $v = 0 }
  $msg || ( carp("Need a warning message" ) && return );

  if ($log) {
    print LOG "[WARN] $msg\n";
  }

  if( $v > $VERBOSITY ){ return 1 }
  warn( "[WARN] ".$msg."\n" );
  return 1;
}

