#!/usr/local/bin/perl -w

###################### DOCUMENTATION #########################################

=head1 NAME

do_view_examples.pl

=head1 SYNOPSIS

do_view_examples.pl  [options]

With no options, the script creates example links for each view.  For most views if the original example parameters are still valid, they will be kept.

Saves the original *.ini as *.ini.bck

Options:
   --help --species <species_name> --site_type pre

=head1 OPTIONS

B<--species>
   Optional: if no species is specified, all species will be done

B<-v,--verbose>
  Optional: Set verbosity level for debug output to stdout or logfile. Default 1

B<-h,--help>
  Prints a brief help message and exits.

B<-i,--info>
  Prints man page and exits.

B<--site_type>
  pre, archive, main.  This information is needed in order to find the ini files


=head1 DESCRIPTION

B<This program:>
Creates the site map for EnsEMBL
Maintained by Fiona Cunningham  <webmaster@ensembl.org>


Output may include the following:

B<  [DIE*]:> Program critical error, dumps have halted.

B<  [WARN]:> Program has encountered an error but is still running, 
          dumps may have been affected.

B<  [INFO]>: Non-critical message, dumping should continue as normal.


=cut


########################## Use ################################################
use strict;
use FindBin qw($Bin);
use File::Basename qw( dirname );
use Data::Dumper;
use Getopt::Long qw(:config no_ignore_case);
use CGI qw(:standard *table);
use DBI;

########################### Set up big variables ##############################
use vars qw( $SERVERROOT );
BEGIN{
  $SERVERROOT = dirname( $Bin );
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

require EnsEMBL::Web::SpeciesDefs;
require EnsEMBL::Web::DBSQL::DBConnection;

use utils::Tool;
my $SPECIES_DEFS =  EnsEMBL::Web::SpeciesDefs->new();
$SPECIES_DEFS || pod2usage("$0: SpeciesDefs config not found");
my @species_inconf = @{$SiteDefs::ENSEMBL_SPECIES};
my $path = "$SERVERROOT/perl";


######################### cmdline options #####################################
our $VERBOSITY;
my ($help, @species, $site_type);
&GetOptions(
            "help"        => \$help,
            "site_type:s" => \$site_type,
	    'verbose:s'   => \$VERBOSITY,
	    "species:s"   => \@species,
            );

if(defined $help) {
    die qq(
    Usage: $0 [options]
    Options:
    --species
    -h       = help
	  )
  }

# Species to create examples for:
if (!@species) {  @species = @species_inconf; }
$VERBOSITY = defined($VERBOSITY) ? $VERBOSITY: 1;

####### List of all view pages and their parameters ##########################
# Define 'table', 'select' to use the generic sql "Select $select from $table'.
#  Otherwise need to define specific sql statement in select query array
# Add the key/value pair "nolink => 1" if you don't want it on the sitemap
our %views = (
 	     alignview      => {nolink => 1,
				note   => "Not supposed to have a link"},
	     anchorview     => {db     => ["ENSEMBL_DB"], 
 				noparam=> 1 },
 	     contigview     => {db     => ["ENSEMBL_DB"],
 				param  => ["region","start","end"]},#100k max
 	     cytoview       => {db     => ["ENSEMBL_DB"],
 				param  => ["region", "start", "end"]},
 	     dasconfview    => {nolink => 1,
 				note   => "for das conf"},
 	     diseaseview    => {nolink => 1,
				db     => ["ENSEMBL_DISEASE"], 
 				table  => "disease", 
 				select => "disease", 
 				param  => ["disease"]}, #cancer
 	     domainview     => {db     => ["ENSEMBL_DB"], 
 				param  => ["domainentry"]}, #IPR000980
             dotterview     => {nolink => 1,
				note   => "not yet sorted out",
				db     => ["ENSEMBL_DB"]}, 
				#"ref "chr", "start", "hom", "chr", "start"
				#ref=Pan_troglodytes:5:5150903&hom=
	                        #Homo_sapiens:6:5057037
 	     exonview       => {db     => ["ENSEMBL_DB"], 
 				param  => ["transcript"], 
 				table  => "transcript_stable_id", 
 				select => "stable_id"},
 	     exportview     => {nolink => 1},
 	     fastaview      => {nolink => 1,
 				note   => "not external view"},
 	     familyview     => {db     => ["ENSEMBL_COMPARA"],
				param  => ["family"]}, #ENSF00000000117
  	     featureview    => {db     => ["ENSEMBL_DB"],
 			        param  => ["id", "type"],
				size   => 1},
 	     genesnpview    => {#nolink => 1,
				db     => ["ENSEMBL_VARIATION", "ENSEMBL_DB"],
 				param  => ["gene"], },
 	     geneview       => {db     => ["ENSEMBL_DB"], 
				param  => ["gene"], 
				table  => "gene_stable_id", 
 				select => "stable_id"}, #ENSG00000139618 BRCA2
	      generegulationview   => {db     => ["ENSEMBL_DB"], 
				param  => ["gene"], 
				table  => "gene_stable_id", 
 				select => "stable_id"},
	      geneseqview   => {db     => ["ENSEMBL_DB"], 
				param  => ["gene"], 
				table  => "gene_stable_id", 
 				select => "stable_id"},
	      genespliceview => {db     => ["ENSEMBL_DB"], 
				param  => ["gene"], 
				table  => "gene_stable_id", 
 				select => "stable_id"},
	      goview         => {db     => ["ENSEMBL_GO"], 
				param  => ["query"], 
				table  => "term", 
				select => "name"},#binding
	      haploview      => {nolink => 1,
                               db     => ["ENSEMBL_HAPLOTYPE"], 
				param  => ["haplotype"], 
				table  => "haplotype",
 				select => "sample_id"}, #CHR22_A_11, CHR22_A_10
 	     karyoview      => {noparam=> 1,
				db     => ["ENSEMBL_DB"],},
	      ldtableview   => {nolink => 1,
				db     => ""},
 	     ldview         => {db     => ["ENSEMBL_VARIATION"],
				select => "meta_value",
				table  => "meta",
				param  => ["snp", "pop"], }, # rs20410,
 	     mapview        => {db     => ["ENSEMBL_DB"], 
				param  => ["chr"]}, # X 12
 	     markerview     => {db     => ["ENSEMBL_DB"], 
				param  => ["marker"], # stimes no values
				table  => "marker_synonym", 
 				select => "name"}, #D1S2806, RH9632
	      miscsetview    => {nolink => 1,
				db     => ""},
	     multicontigview=> {nolink => 1,
				db     => ""}, 
	     #multicontigview?c=17:41.63m&w=200000&s1=
	     #Mus_musculus&s2=Rattus_norvegicus
 	     primerview     => {nolink => 1,
 				note   => "doesn't work"},
 	     protview       => {db     => ["ENSEMBL_DB"], 
				param  => ["peptide"], #ENSP00000267071
				table  => "translation_stable_id", 
				select => "stable_id"},
 	     snpview        => {db     => ["ENSEMBL_VARIATION"], 
				param  => ["snp"], 
				table  => "variation",
				select => "name",  # 20410
				size   => 1, },
 	     syntenyview    => {db     => ["ENSEMBL_DB"], 
				param  => ["chr"]},
 	     tagloview      => {nolink => 1,
 				note   => "no external link"}, #CHR22_A_11,
 	     transview      => {db     => ["ENSEMBL_DB"], 
 				param  => ["transcript"], #ENST00000157775
 				table  => "transcript_stable_id", 
				select => "stable_id"},
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


################# Loop through all spp and get examples ######################
$site_type = "main" unless $site_type;
warning (1, "******Site type is $site_type");

foreach my $spp (@species) {
  info (1, "---------------Processing $spp ----------------------");

  #--------- Check for species specific views not defined in %views --------
  my @extra_views;
  my $extra_dir = $path."/$spp";
  if( -e $extra_dir ){
    opendir(EXTRADIR, $extra_dir) or die "can't open dir $extra_dir:$!";
    while (defined(my $file = readdir(EXTRADIR))) {
      next unless $file =~ /view$/;
      info(1, "Extra view '$file' for $spp" ) unless $views{$file};
      push (@extra_views, $file) unless $views{$file};
    }
    close EXTRADIR;
  }
  else {
    info (1, "No species specific views for $spp");
  }

  #------------ Read in current .ini file -------------------------------------
  my $path = $site_type eq 'pre' ? "/sanger-plugins/pre/" : "/public-plugins/ensembl/";
  my $ini_file = $SERVERROOT.$path."conf/ini-files/$spp".".ini";
  open (INI, "<",$ini_file) or die "Couldn't open ini file $ini_file: $!";
  my $out_ini = $ini_file . ".out";
  open (my $fh, ">",$out_ini) or die "Couldn't open ini file $out_ini: $!";

  my $ini_contents = [<INI>];
  close INI;
  $ini_contents = utils::Tool::print_next($ini_contents, "\\[SEARCH_LINKS\\]", $fh);
  print $fh shift @$ini_contents;
  
  # ---------- Get current examples and defaults ----------------------------
  my %current_eg;
  if ($SPECIES_DEFS->get_config($spp, 'SEARCH_LINKS')) {
    %current_eg = %{$SPECIES_DEFS->get_config($spp, 'SEARCH_LINKS')};

    foreach (keys %current_eg){
      # Always get a new example for familyview (IDs are unstable)
      delete $current_eg{$_} if $_ =~/FAMILYVIEW/;

      # Capture the configured DEFAULT examples
      if ($_ =~ /DEFAULT.*URL/) {
	(my $view_type = $current_eg{$_}) =~ s/(.+view)\?.*/$1/;

	# Make the key a view type
	$views{$view_type}{default} = $current_eg{$_} if $views{$view_type};
      }
    }
  }
  else {
    print "No example search links!\n";
  }

  ########## OUTPUT SECTION ##################################################
  my $output;
  my $return;
  my %oked_defaults;
  my %db          = %{$SPECIES_DEFS->get_config($spp,  "databases")};
  my %db_multi = %{$SPECIES_DEFS->get_config("Multi","databases")};

  foreach my $view (sort keys %views) {
    info (1, "$view ...");
    if ($view eq 'generegulationview'and ($spp ne 'Homo_sapiens' or $spp ne 'Drosophila_melanogater')) {
      info (1, "Configured to skip generegulation view in $spp");
      next;
    }
    next if $views{$view}{nolink};
    if ($site_type eq 'pre') {
      my @check_db = @{$views{$view}{db}};
      next if $check_db[1];
      next unless $check_db[0] eq "ENSEMBL_DB";
    }
    die "no database" unless $db{'ENSEMBL_DB'};

    # Do we have synteny data? 
    if ($view eq 'syntenyview' and $site_type ne 'pre') {
        my %synteny = %{$SPECIES_DEFS->get_config("Multi", "SYNTENY")};

        # no syntenyview if no synteny with this species!
        next unless $synteny{$spp}; 

        # double-check config for running synteny data
        my $running_total = 0;
        my %species_hash = %{$synteny{$spp}};
        foreach my $key (keys %species_hash) {
            my $running = $species_hash{$key};
            $running_total += $running;
        }
        next unless $running_total > 0;
    }

    # No params ---------------------------------------------------------------
    if ($views{$view}{noparam} && $view ne 'karyoview') {
      info (2, "Creating link with no params for $view");
      $return = [];
    }

    # Chr link ---------------------------------------------------------------
    elsif ($view eq 'karyoview' || 
            ($views{$view}{param}[0] eq 'chr' and !$views{$view}{param}[1])) {
      $return = find_chr($spp);
      if (!$return) {info (1, "No links for $view") && next};
   }

    # Others -----------------------------------------------------------------
    else {
      unless ($views{$view}{db}) {
	warning (1, "Do database configured for $view");
	 next;
      }
      #my %db          = %{$SPECIES_DEFS->get_config($spp,  "databases") };
     # my %db_multi = %{$SPECIES_DEFS->get_config("Multi","databases") };
      die "no database" unless $db{'ENSEMBL_DB'};

      my @use_db;
      foreach my $db_string ( @{ $views{$view}{db} } ){
	if ($db_string eq 'ENSEMBL_COMPARA' or $db_string eq 'ENSEMBL_GO') {
	  push (@use_db, {
			  "name" => $db_multi{$db_string}{'NAME'},
			  "host" => $db_multi{$db_string}{'HOST'},
			  "port" => $db_multi{$db_string}{'PORT'}
			 });	
	}
	else {
	  next unless $db{$db_string};
	  push (@use_db, {
			  "name" => $db{$db_string}{'NAME'},	
			  "host" => $db{$db_string}{'HOST'},
			  "port" => $db{$db_string}{'PORT'},
			 });
	}
      }
      next unless (scalar @use_db == scalar @{ $views{$view}{db} } );
      my $like = $view eq 'diseaseview' ? "like" : "=";
      $like = "like" if $view eq 'goview';

      # Check defaults ------------------------------------------------------
      if (my $default_eg = $views{$view}{default} ){
	info (2, "Checking default example $default_eg ...");
	$oked_defaults{$view} = get_examples($view,\@use_db, $spp,
					 $like,[$default_eg]);
	
      }

      # Current examples -----------------------------------------------------
      my @eg = ( $current_eg{uc($view)."1_URL"}, 
		 $current_eg{uc($view)."2_URL"} );

      $return = get_examples($view, \@use_db, $spp, $like,\@eg);

      # Make sure you always have defaults ...
      if ($view eq 'geneview' or $view eq 'contigview') {
	$oked_defaults{$view} = $return unless $oked_defaults{$view};

      }
    }
    $output .= format_output( $view, $return ) if $return;
  }

  print $fh $output if $output;

  # Sort out DEFAULT examples ------------------------------------------------
  my $count_defaults = 0;
  foreach my $tmp_view (keys %oked_defaults) {
    my $defaults_out =  format_output( $tmp_view, [$oked_defaults{$tmp_view}->[0]]);
    $count_defaults++;
    my $uc_view = uc($tmp_view);
    $defaults_out =~ s/$uc_view\d/DEFAULT$count_defaults/g;
    #print "DEFAUTLS: $defaults_out\n";
    print $fh $defaults_out;
  }


  #--------------------- Print out remainder of ini file ----------------------
  my $flag_comments = 1;
  foreach (@$ini_contents) {
    next if $_ =~ /VIEW/;
    next if $_ =~ /DEFAULT\d_URL|DEFAULT\d_TEXT/;
    $flag_comments = 0 if $_ =~ /\#+/;
    if ($flag_comments) {next if $_ =~ /^\s+$/;}
    print $fh $_;
  }
  warning(1, "$count_defaults DEFAULT EXAMPLES EXISTS FOR THIS SPECIES: use contig and geneview examples and configure manually") unless $count_defaults >1;


  close $fh;

  system ("mv $ini_file $ini_file.bck");
  system ("mv $out_ini $ini_file");
}

exit;

###############################################################################
sub get_examples {
  my ($view, $db_ref, $spp, $like, $examples) = @_;

  my @values;
  if ($view eq 'ldview') {
    my @mysql = select_query( $view, $db_ref, $spp, $views{$view} );
    my $pop   = execute_query( @mysql, 1 );
    return unless $pop->[0];
    @mysql = select_query( 'snpview', $db_ref, $spp, $views{snpview} );
    my $snps   = execute_query( @mysql, 2 );
    foreach my $each_snp ( @$snps ) {
      push (@$each_snp, @{ $pop->[0] } ) ;
    }
    push (@values, $snps->[0], $snps->[1]);
    return \@values;
  }

  foreach my $eg (@$examples) {
    next unless $eg;
    ( my $where = $eg )=~ s/.*=(.*)/$1/;
    $views{$view}->{where} = $like eq 'like'? qq( like "\%$where%") : " = '$where'";
    my @mysql = select_query($view, $db_ref, $spp, $views{$view});
    my $hit   = execute_query( @mysql, 1 );
    if ($like eq 'like') {
      push (@values, [$where]) if $hit;
    }
    else { push (@values, $hit->[0]) if $hit; }
  }
  info(2, "Using ".scalar @values." example(s) for $view\n") if $values[0];
  if (!$values[1]) {
    info(2, "Getting a new example..\n");
    $views{$view}->{where} = 0;
    my @mysql = select_query($view, $db_ref, $spp, $views{$view});
    my $max_hits = $values[0] ? 1 : 2;
    my $new_hit   = execute_query( @mysql, $max_hits );
    push (@values, $new_hit->[0], $new_hit->[1]);
  }
  return \@values;
}

#-------------------------------------------------------------------------
sub execute_query {
  my ($dsn,  $statement, $size, $max_rows) = @_;
  my $dbh = DBI->connect($dsn, 'ensro') or 
   warning(1, "Can't connect to database '$dsn'") and return[];
  my @answer;

  my $count = 0;                          # Keep looping until find answer
  foreach my $query( @{ $statement } )  {
    if ($size) {
      my $size_query = shift @{ $statement };
      my ($table_size) = $dbh->selectrow_array( $size_query );
      my $query = (shift @{ $statement } );
      next unless $table_size;
      for (0..1) {
	my $full_query = "$query LIMIT @{[int rand $table_size]}, 1";
	push (@answer, [ $dbh->selectrow_array( $full_query  ) ]);
      }
      last if scalar @answer == $max_rows;
    } 
    else {
      my $return = $dbh->selectall_arrayref( $query ,  {MaxRows => $max_rows});
      foreach ( @{ $return } ) {
	push (@answer, $_);
	$count++;
      }
      last if $count == $max_rows;
    }
  }

  $dbh->disconnect;
  return \@answer;
}

#--------------------------------------------------------------------
sub format_output {
  my ($view, $values) = @_;
  my $counter = 0;
  my $output_text;
  my $argument = $views{$view};

  # e.g.KARYOVIEW1_TEXT \n KARYOVIEW1_URL    = karyoview
  if ($argument->{noparam}) {
    $output_text .= uc($view)."1_TEXT\n";
    $output_text .= uc($view)."1_URL    = $view\n\n";
    $counter++;
    return $output_text;
  }

  foreach my $value (@$values) {
    next unless $value;

    my $param;
    if ($view eq 'diseaseview') {
      $value->[0] =~ s/cancer.*/cancer/; 
      $value->[0] =~ s/\(\d*\)|\{//;
     }

    for (my $i=0; $i < @{$argument->{param}}; $i++) {
      last unless $value->[$i];
      $param .= "$argument->{param}[$i]=$value->[$i]&";
    }

    return unless $param;
    chop($param); #rm last &
    $counter++;
    $output_text .= uc($view).$counter."_TEXT   = $value->[0] \n";
    $output_text .= uc($view).$counter."_URL    = $view?$param\n";
  }

  $output_text .= "\n";
  warning (1, "########[CHECK] no values for $view #########") unless $counter;

  return $output_text;
}

#------------------------------------------------------------------------------
sub find_chr {
  my $spp = shift;
  my @chr = @{$SPECIES_DEFS->get_config($spp,"ENSEMBL_CHROMOSOMES")};
  return 0 unless @chr;

  my ($a, $b) = (rand(@chr), rand(@chr));       # Choose a random chr
  $a -= 2 if $chr[$a] eq $chr[$b];
  return  [ [ $chr[$a] ], [ $chr[$b] ] ];
}
#------------------------------------------------------------------------------

sub select_query {
  my ($view, $use_db, $spp, $param) = @_;
  my $dsn = "DBI:mysql:database=". $use_db->[0]{name} .":host=".
    $use_db->[0]{host} .";port=" . $use_db->[0]{port};
  $spp =~ s/_/ /;

  my %statement;
  #select * from variation where variation_id>=rand()*10079771 limit 1;
  my $size = $param->{size} || "";
  my $order_by = $size ? "" : "ORDER BY rand()";
  if ($param->{where} && $param->{select}) {
    $size = "";
    push (@{$statement{generic}}, "SELECT $param->{select}
                                  FROM   $param->{table}
                                  WHERE  $param->{select} $param->{where}
 ");

    unshift (@{ $statement{generic} }, 
	     "SELECT xref.display_label
              FROM   gene, xref
              WHERE gene.display_xref_id=xref.xref_id
              and xref.display_label $param->{where}") if $view eq 'geneview';

    $statement{contigview} =
      ["SELECT seq_region.name
        FROM   seq_region, coord_system
        WHERE  coord_system.coord_system_id = seq_region.coord_system_id
                 and seq_region.name $param->{where}"];
  }  # end elsif where

  elsif ($param->{select}) {
    push( @{ $statement{generic} }, "SELECT   $param->{select}
                                         FROM     $param->{table}
                                         $order_by");
  }



  # If no query bits ---------------------------------
  else {
    push ( @{ $statement{contigview}} ,
	   "SELECT sr.name, a.cmp_start, a.cmp_end
                    FROM seq_region as sr, assembly as a, attrib_type as at,
                      seq_region_attrib as sra, coord_system as cs
                    WHERE sr.seq_region_id = a.cmp_seq_region_id and
                       a.asm_seq_region_id = sra.seq_region_id and
                       sra.attrib_type_id = at.attrib_type_id and
                       at.code ='toplevel' and cs.name !='chunk' and
                       cs.coord_system_id = sr.coord_system_id
                    ORDER BY sr.coord_system_id desc, rand()",

		    "SELECT sr.name, sr.length
                     FROM seq_region as sr, attrib_type as at,
                          seq_region_attrib as sra, coord_system as cs
                     WHERE sr.seq_region_id = sra.seq_region_id and
                           sra.attrib_type_id = at.attrib_type_id and
                           at.code ='toplevel' and cs.name !='chunk' and
                           cs.coord_system_id = sr.coord_system_id
                     ORDER BY sr.coord_system_id desc, rand()");


    push  @{ $statement{cytoview} }, @{ $statement{contigview}} ; 
#	   "SELECT s.name, band
#                    FROM karyotype as k, seq_region as s, coord_system as c
#                    WHERE k.seq_region_id = s.seq_region_id and 
#                          c.name = 'chromosome' and
#                          c.coord_system_id = s.coord_system_id
#                    ORDER BY rand() LIMIT 2");


    push ( @{ $statement{domainview} },   
	 "SELECT i.*, count( distinct tr.gene_id ) as c
                             FROM interpro as i, protein_feature as pf,
                                  transcript as tr, translation as tl
                             WHERE i.id = pf.hit_id and 
                                   pf.translation_id = tl.translation_id and
                                   tr.transcript_id = tl.transcript_id
                             GROUP BY i.interpro_ac
                             HAVING c between 20 and 50
                             ORDER BY rand()
                             LIMIT 2;");


    push ( @{ $statement{familyview} },
	   "SELECT f.stable_id
                    FROM  family as f, genome_db,  family_member as fm, 
                          member as m 
                    WHERE m.member_id = fm.member_id and  
                          f.family_id = fm.family_id and
                          genome_db.genome_db_id = m.genome_db_id and
                          genome_db.name = '$spp' and 
                          m.source_name='ENSEMBLGENE' and 
                          f.description != 'UNKNOWN' and 
                          f.description !='AMBIGUIOUS'
                   GROUP BY f.stable_id 
                   HAVING count(*) between 20 and 50
                   ORDER BY rand()",

		   "SELECT f.stable_id  
                    FROM  family as f, genome_db,  
                          family_member as fm, member as m 
                    WHERE m.member_id = fm.member_id and
                          f.family_id = fm.family_id and
                          genome_db.genome_db_id = m.genome_db_id and 
                          genome_db.name = '$spp' and 
                          m.source_name='ENSEMBLGENE' and 
                          f.description !='AMBIGUIOUS'
                   GROUP BY f.stable_id 
                   HAVING count(*) between 0 and 50
                   ORDER BY rand()");

    push( @{ $statement{featureview} }, 
         "SELECT   count(*)
          FROM     affy_probe",

	  "SELECT   probeset, 'AffyProbe'
           FROM     affy_probe, affy_feature 
           WHERE    affy_probe.affy_probe_id = affy_feature.affy_probe_id",

         "SELECT   count(*)
          FROM     protein_align_feature",

	  "SELECT   hit_name, 'ProteinAlignFeature'
           FROM     protein_align_feature",

         "SELECT   count(*)
          FROM     dna_align_feature",

	  "SELECT   hit_Name, 'DnaAlignFeature'
           FROM     dna_align_feature",
	);

    push ( @{ $statement{ ldview} }, 
          "SELECT meta_value
           FROM  meta");

    my $db2 = $use_db->[1]{'name'} || 1;
    push ( @{ $statement{ genesnpview} }, 
	 "SELECT gs.stable_id
           FROM $db2.gene_stable_id as gs,
                $db2.transcript as t,
                transcript_variation as tv
           WHERE gs.gene_id = t.gene_id and
                 t.transcript_id = tv.transcript_id");
  }

  if ( $size && $statement{generic} ) {
    unshift (@{ $statement{generic} }, 
                    "SELECT   count(*)
                     FROM     $param->{table}");
  }

  my $query = $statement{$view} || $statement{generic};
  return ($dsn, $query, $size);
}
#--------------------------------------------------------------------------
sub info{
  my $v   = shift;
  my $msg = shift;
  if( ! defined($msg) ){ $msg = $v; $v = 0 }
  $msg || ( carp("Need a warning message" ) && return );

  if( $v > $VERBOSITY ){ return 1 }
  warn( "[INFO] ".$msg."\n" );
  return 1;
}

#----------------------------------------------------------------------
sub warning{
  my $v   = shift;
  my $msg = shift;
  if( ! defined($msg) ){ $msg = $v; $v = 0 }
  $msg || ( carp("Need a warning message" ) && return );

  if( $v > $VERBOSITY ){ return 1 }
  warn( "[WARN] ".$msg."\n" );
  return 1;
}
#----------------------------------------------------------------------
