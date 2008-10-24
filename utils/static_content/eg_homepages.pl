#!/usr/local/bin/perl 

## Script to generate species' home pages

use strict;
use FindBin qw($Bin);
use File::Path;
use File::Basename qw( dirname );
use File::Find;
use Data::Dumper;
use Getopt::Long qw(:config no_ignore_case);
use CGI qw(:standard *table);

# --- load libraries needed for reading config --------------------------------
use vars qw( $SERVERROOT );
BEGIN{
#  $SERVERROOT = dirname( $Bin );
  $SERVERROOT = `pwd`; #dirname(  );
  chop $SERVERROOT;
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

require EnsEMBL::Web::SpeciesDefs;                  # Loaded at run time
my $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new;
$SPECIES_DEFS || pod2usage("$0: SpeciesDefs config not found");

my $species_defs = $SPECIES_DEFS;
#warn Dumper $species_defs;
#my $h = $species_defs->{_storage}->{Escherichia_Shigella};
#foreach my $k (sort keys %$h) {
#    warn "$k => $h->{$k} \n";
#}
#warn Dumper $h->{SPECIES_LIST};

#exit;
my @valid_species = $species_defs->valid_species;

#warn Dumper \@valid_species;
my %species_info;

my %group_info;
foreach my $species (@valid_species) {
    my $info = {};
    my $a = $species_defs->get_config($species, "SPECIES_COMMON_NAME");
    $info->{'common'}     = $species_defs->get_config($species, "SPECIES_COMMON_NAME");
    $info->{'assembly'}   = $species_defs->get_config($species, "ASSEMBLY_NAME");
    $info->{'genebuild'}  = $species_defs->get_config($species, "GENEBUILD_DATE");
    $info->{'species_dbid'}  = $species_defs->get_config($species, "SPECIES_DBID");
    $info->{'filename'} = $species_defs->get_config($species, "FILENAME");


    if (my $group = $info->{'group'}  = $species_defs->get_config($species, "SPECIES_GROUP")) {
	push @{$group_info{$group}->{'species'}}, $species;
	
    }

    my $h = $species_defs->get_config($species, "databases");
    $info->{'db'} = $h->{DATABASE_CORE};
    $species_info{$species} = $info;

}

#  warn Dumper \%species_info;
#  warn Dumper \%group_info;
#exit 0;
my @species_inconf = @{$SiteDefs::ENSEMBL_SPECIES};

my ($help, @species, $site_type, $mirror);
our $id_count = 0;

&GetOptions(
            "help"        => \$help,
            "species:s"   => \@species,
            "site_type:s" => \$site_type,
            'mirror:s'    => \$mirror,
            );


# Select current list of all species
if (!@species) {  @species = @species_inconf; }

# General Static content HOME --------------------------------------------------------
#my $outdir = "/$SERVERROOT";
my $outdir = "$SERVERROOT";
if ( $site_type eq 'pre') {
  $outdir .= "/sanger-plugins/pre/htdocs/";
 }
elsif ( $site_type eq 'mirror') {
  $outdir .= $mirror ? $mirror : 'public-plugins/mirror';
  $outdir .= '/htdocs/';
}
else {
#  $outdir .= "/public-plugins/ensemblbacteria/htdocs/";
  $outdir .= "/sanger-plugins/ek-eb/htdocs/";
}

warn "Output to $outdir ... ";



generate_index_pages($outdir);
generate_about_pages($outdir);
generate_entry_points($outdir);
generate_karyomaps($outdir);
generate_species_stats($outdir);


sub generate_about_pages{
    my ($outdir) = @_;

    foreach my $sp_group (sort keys %group_info) {
	my $spgdir = $outdir.$sp_group."/ssi";

	if( ! -e $spgdir ){
	    warn "[INFO]: Creating species directory $spgdir\n";
	    eval { mkpath($spgdir) };
	    if ($@) {
		print "Couldn't create $spgdir: $@";
	    }
	}
	
	open FH, ">$spgdir/about.html" or die "ERROR: $!";
	
	print FH qq{
<h2 class="first">About the $sp_group genomes</h2>

<h3>Assembly</h3>

<p><img src="/img/species/pic_$sp_group.png" style="width:100px;height:97px" class="float-left" alt="$sp_group" title="doh!"/>This release is based on the NCBI 36 assembly of the <a href="http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?db=genomeprj&amp;cmd=Retrieve&amp;dopt=Overview&amp;list_uids=9558">human genome</a> [November 2005]. The data consists of a reference assembly of the complete genome plus the Celera WGS and a number of alternative assemblies of individual haplotypic chromosomes or regions.</p>


<h3>Annotation</h3>

<p>Since release 38 (April 2006) the gene annotation presented has 
been a combined Ensembl-Havana geneset, which incorporates more 
than 18,000 full-length protein-coding transcripts annotated by the 
Havana team with the Ensembl automatic gene build. The human genome 
sequence is now considered sufficiently stable that since 2004 the 
major genome browsers have come together to produce a common set of 
identifiers where CDS annotations of transcripts can be agreed and 
these identifiers are also shown.</p>

};
    }

    
}

sub generate_index_pages {
    my ($outdir) = @_;
    foreach my $sp_group (sort keys %group_info) {
	my $spgdir = $outdir.$sp_group;

	if( ! -e $spgdir ){
	    warn "[INFO]: Creating species directory $spgdir\n";
	    eval { mkpath($spgdir) };
	    if ($@) {
		print "Couldn't create $spgdir: $@";
	    }
	}
	
	open FH, ">$spgdir/index.html" or die "ERROR: $!";
	
	print FH qq{
<html>
<head>
<title>Ensembl Genomes: $sp_group</title>
</head>
<body>
<div class="onecol tinted-box">
  [[SCRIPT::EnsEMBL::Web::Document::HTML::HomeSearch]] 
</div>

<div class="twocol-left">
  [[SCRIPT::EnsEMBL::Web::Document::HTML::SpeciesList]]
</div>

<div class="twocol-right">
  [[INCLUDE::/$sp_group/ssi/about.html]]
</div>

<div class="twocol-left">
  [[INCLUDE::/$sp_group/ssi/whatsnew.html]]
</div>
</body>
</html>
};
	close FH;

	my @sp_list = @{$group_info{$sp_group}->{'species'}||[]};

	foreach my $spp (@sp_list) {
	    $species_info{$spp}->{'filename'} or (warn "NO FN for $spp" && next);
	    my $spdir = "$spgdir/".$species_info{$spp}->{'filename'};

	    if( ! -e $spdir ){
		warn "[INFO]: Creating species directory $spdir\n";
		eval { mkpath($spdir) };
		if ($@) {
		    print "Couldn't create $spdir: $@";
		}
	    }

	    open FH, ">$spdir/index.html" or die "ERROR: $!";
	    print FH qq{
<html>
<head>
<title>Ensembl Genomes: $spp</title>
</head>
<body>
<div class="onecol tinted-box">
  [[SCRIPT::EnsEMBL::Web::Document::HTML::HomeSearch]] 
</div>

<div class="twocol-left">
  [[INCLUDE::/$sp_group/$spp/ssi/karyomap.html]]
  [[INCLUDE::/$sp_group/$spp/ssi/entry.html]]
</div>
<div class="twocol-right">
  [[INCLUDE::/$sp_group/ssi/about.html]]
</div>
</div>
<div class="twocol-right">
  [[INCLUDE::/$sp_group/$spp/ssi/stats.html]]
</div>

</body>
</html>
};
	    close FH;
	}
    }
}

sub generate_entry_points {
    my ($outdir) = @_;

    my $sql = qq{SELECT cs.species_id, cs.name, r.name, r.length FROM seq_region r join coord_system cs on r.coord_system_id = cs.coord_system_id where seq_region_id in  (SELECT seq_region_id FROM seq_region_attrib where attrib_type_id = (SELECT attrib_type_id FROM attrib_type where name = 'Top Level'))};


    my %entry_info;

    foreach my $sp_group (sort keys %group_info) {

	my $spgdir = $outdir.$sp_group;

	my @sp_list = @{$group_info{$sp_group}->{'species'}||[]};
	foreach my $spp (@sp_list) {
	    if ( ! $species_info{$spp}->{'filename'}) {
		warn "NO FN for $spp";
		next;
	    }
#	    my $spdir = "$spgdir/".$species_info{$spp}->{'filename'};

	    my $dbname = $species_info{$spp}->{db}->{NAME};
	    if (! exists $entry_info{$dbname}) {
		my $dbh = db_connect($species_info{$spp}->{db});
		if (!$dbh) {warn "NO DB for $spp"; exit}
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		my $sinfo;
		while (my @row = $sth->fetchrow_array) {
		    push @{$sinfo->{$row[0]}->{entries}}, join ':', $row[1], $row[2];
		}
		$sth->finish;
		$dbh->disconnect;
		$entry_info{$dbname} = $sinfo;
	    }

	    my $sp_index = $species_info{$spp}->{species_dbid};
	    my @entries = @{$entry_info{$dbname}->{$sp_index}->{entries}||[]};
	    push @{$species_info{$spp}->{toplevel}}, @entries;
#	    warn Dumper \%entry_info;
#	    warn "$spp : $sp_index : $dbname : @entries \n";

	    my $sp_path = "$sp_group/$spp";
	    my $spdir = sprintf("%s/%s/ssi", $spgdir, $species_info{$spp}->{'filename'});
	    warn "$spp ENTRIES to $spdir";
	    if( ! -e $spdir ){
		warn "[INFO]: Creating species directory $spdir\n";
		eval { mkpath($spdir) };
		if ($@) {
		    print "Couldn't create $spdir: $@";
		}
	    }
	    open SEARCH, ">$spdir/entry.html";

	    # Output page
	    (my $spp_text = $spp) =~ s/_/ /;

	    my @options;
	    foreach my $e (@entries) {
		my ($region_name, $region_id) = split ':', $e , 2;
		(my $region_label = $e) =~ s/\:/ /;
		push @options, qq{<option value="$region_id">$region_label</option>};
	    }

 my $select = @options ? qq{
  <td style="text-align:right">Toplevel Region:</td>
  <td>
<select name="chr">
    <option value="">==</option>
    @options
  </select> or 
} : qq{
  <td style="text-align:right" colspan="2">
  };


    # Start column #1
# should be $sp_path
    print SEARCH qq(
<form action="/$sp_group/jump_to_location_view">
<p>Jump directly to sequence position</p>
<table align="center">
<tr>
		    $select region
  <input type="text" value="" class="small" name="region" /></td>
</tr>
<tr>
  <td style="text-align:right">From (bp):</td>
  <td><input type="text" value="" class="small" name="start" /></td>
</tr>
<tr>
  <td style="text-align:right">To (bp):</td>
  <td><input type="text" value="" class="small" name="end" /><input type="hidden" name="entry" value="yes" />
      <input type="submit" value="Go" class="red-button" /></td>
</tr>
</table>
</form>
    );

    close SEARCH;
	}
    }

}

sub generate_karyomaps {
    my ($outdir) = @_;
    foreach my $sp_group (sort keys %group_info) {
	my $spgdir = $outdir.$sp_group;

	my @sp_list = @{$group_info{$sp_group}->{'species'}||[]};
	foreach my $spp (@sp_list) {
	    my $sp_path = "$spgdir/$spp";
	    my $spdir = sprintf("$spgdir/%s/ssi", $spp); #$species_info{$spp}->{'filename'};
#	    my $spdir = "$spgdir/$spp/ssi";

	    if( ! -e $spdir ){
		warn "[INFO]: Creating species directory $spdir\n";
		eval { mkpath($spdir) };
		if ($@) {
		    print "Couldn't create $spdir: $@";
		}
	    }

	    warn "$spp OUT to $spdir/karyomap.html";

	    open SEARCH, ">$spdir/karyomap.html";

	    # Output page
	    (my $spp_text = $spp) =~ s/_/ /;


    # Start column #1
    print SEARCH qq(
<h2 class="first">Genomic structure</h2>

<p>Click on a chromosome for a closer view</p>


<div class="karyomap">
<map id="karyotypes" name="karyotypes">
   <area shape="circle" coords="150, 150, 150" href="/$sp_group/$spp/Location/View?r=Chromosome:180000-200000"  alt="chromosome"  title="chromosome" /> 
</map>
		    );
	
	    my @toplevel_entries = @{$species_info{$spp}->{toplevel} || []};

	    warn "$spp => @toplevel_entries";

	    foreach my $e (@toplevel_entries) {
		my ($t, $n) = split /:/, $e;

		my $fname = "karyotype_${spp}_${n}";
		$fname =~ s/[^\w]/_/g;

warn "image : $fname";
		print SEARCH qq{
<table style="display:inline">
<tr><td><b>$e</b></td></tr>
<tr><td><img src="/img/species/${fname}.png" usemap="#karyotypes" alt="$spp - $t - $n" /></td></tr>
</table>
		};
		if ($t eq 'chromosome') {
		    print SEARCH qq{ <br/> <br/>};
		}
	    }
#	    warn $spp;
	
#	    warn Dumper \@toplevel_entries;
	    print SEARCH qq{
</div>
};
	    close SEARCH;
	}
    }

}

sub generate_species_stats {
    my ($outdir) = @_;

    my $release_id = $species_defs->ENSEMBL_VERSION;

    my $sql = qq{SELECT cs.species_id, g.biotype, g.status, count(*) FROM seq_region r join coord_system cs on r.coord_system_id = cs.coord_system_id join gene g on r.seq_region_id = g.seq_region_id group by cs.species_id, g.biotype, g.status};


    my $bpsql = qq{SELECT cs.species_id, sum(length(d.sequence)) FROM seq_region r join coord_system cs on r.coord_system_id = cs.coord_system_id join dna d on r.seq_region_id = d.seq_region_id group by cs.species_id};

    my %gene_info;
    
    foreach my $sp_group (sort keys %group_info) {

	my $spgdir = $outdir.$sp_group;

	my @sp_list = @{$group_info{$sp_group}->{'species'}||[]};
	foreach my $spp (@sp_list) {
	    my $dbname = $species_info{$spp}->{db}->{NAME};
	    if (! exists $gene_info{$dbname}) {
		my $dbh = db_connect($species_info{$spp}->{db});
		my $sth = $dbh->prepare($sql);
		$sth->execute();
		my $sinfo;
		while (my @row = $sth->fetchrow_array) {
		    push @{$sinfo->{$row[0]}->{entries}}, [ "$row[2] $row[1]", $row[3]];
		}
		$sth->finish;


		my $sth2 = $dbh->prepare($bpsql);
		$sth2->execute();
		while (my @row = $sth2->fetchrow_array) {
		    $sinfo->{$row[0]}->{bpcount} = $row[1];
		}
		$sth2->finish;

		$dbh->disconnect;
		$gene_info{$dbname} = $sinfo;
	    }

	    my $sp_index = $species_info{$spp}->{species_dbid};
	    my @entries = @{$gene_info{$dbname}->{$sp_index}->{entries}||[]};
	    my $bplength = $gene_info{$dbname}->{$sp_index}->{bpcount};

#	    warn Dumper \%entry_info;
#	    warn "$spp : @entries \n";

	    my $sp_path = "$sp_group/$spp";
	    my $spdir = sprintf("$spgdir/%s/ssi"), $species_info{$spp}->{'filename'};
#	    my $spdir = "$spgdir/$spp/ssi";

	    if( ! -e $spdir ){
		warn "[INFO]: Creating species directory $spdir\n";
		eval { mkpath($spdir) };
		if ($@) {
		    print "Couldn't create $spdir: $@";
		}
	    }
	    open STATS, ">$spdir/stats.html";


	    
	    my  $a_id = $species_defs->get_config($spp, 'ASSEMBLY_NAME'); 

	    warn "[ERROR] $spp missing both assembly.name and assembly.default" unless( $a_id );

	    my $a_date  = $species_defs->get_config($spp, 'ASSEMBLY_DATE') || '';
	    $a_date || warn "[ERROR] $spp missing SpeciesDefs->ASSEMBLY_DATE!";
	    my $b_date  = $species_defs->get_config($spp, 'GENEBUILD_DATE') || '';
	    $b_date || warn "[ERROR] $spp missing SpeciesDefs->GENEBUILD_DATE!";
	    my $b_id    = $species_defs->get_config($spp, 'GENEBUILD_BY') || '';
	    $b_id   || warn "[ERROR] $spp missing SpeciesDefs->GENEBUILD_BY!";

	    my $data_version = $species_defs->get_config($spp, 'SPECIES_RELEASE_VERSION');
	    my $db_id = $release_id.'.'.$data_version;


	    print STATS qq(<h3 class="boxed">Statistics</h3>

  <table id="species-stats" class="ss tint">
      <tr class="bg2">
          <td class="data" style="font-size:115%">Assembly:</td>
          <td class="value" style="font-size:115%">$a_id, $a_date</td>
      </tr>
      <tr>
          <td class="data" style="font-size:115%">Genebuild:</td>
          <td class="value" style="font-size:115%">$b_id, $b_date</td>
      </tr>
      <tr class="bg2">
          <td class="data" style="font-size:115%">Database version:</td>
          <td class="value" style="font-size:115%">$db_id</td>
      </tr>
  );


	    my $rid = 1;
	    foreach my $e (@entries) {
		my ($ename, $ecount) = @$e;
		print STATS sprintf qq(
<tr %s>
   <td class="data">%s:</td>
   <td class="value">%s</td>
</tr>), ($rid++ % 2 == 0) ? 'class="bg2"' : '', $ename, $ecount;
	    }


		print STATS sprintf qq(
<tr %s>
   <td class="data">%s:</td>
   <td class="value">%s</td>
				       </tr>), ($rid++ % 2 == 0) ? 'class="bg2"' : '', 'Basepairs', $bplength;


	    print STATS '</table>';

	    print STATS qq(<p class="small"><a href="/info/about/docs/stats.html">How the statistics are calculated</a></p>);

	    close STATS;
	}
    }

}

sub db_connect {
  my $chash    = shift;
  my $dbname  = $chash->{'NAME'};
  return unless $dbname;

  warn "Connecting to $dbname";
  my $dbhost  = $chash->{'HOST'};
  my $dbport  = $chash->{'PORT'};
  my $dbuser  = $chash->{'USER'};
  my $dbpass  = $chash->{'PASS'};
  my $dbdriver= $chash->{'DRIVER'};
  my ($dsn, $dbh);
  eval {
    if( $dbdriver eq "mysql" ) {
      $dsn = "DBI:$dbdriver:database=$dbname;host=$dbhost;port=$dbport";
      $dbh = DBI->connect(
        $dsn,$dbuser,$dbpass, { 'RaiseError' => 1, 'PrintError' => 0 }
      );
    } elsif ( $dbdriver eq "Oracle") {
      $dsn = "DBI:$dbdriver:";
      my  $userstring = $dbuser . "\@" . $dbname;
      $dbh = DBI->connect(
        $dsn,$userstring,$dbpass, { 'RaiseError' => 1, 'PrintError' => 0 }
      );
    } elsif ( $dbdriver eq "ODBC") {
      $dsn = "DBI:$dbdriver:$dbname";
      $dbh = DBI->connect(
        $dsn, $dbuser, $dbpass,
        {'LongTruncOk' => 1,
         'LongReadLen' => 2**16 - 8,
         'RaiseError' => 1,
         'PrintError' => 0,
         'odbc_cursortype' => 2}
      );
    } else {
      print STDERR "\t  [WARN] Can't connect using unsupported DBI driver type: $dbdriver\n";
    }
  };

  if( $@ ) {
    print STDERR "\t  [WARN] Can't connect to $dbname\n", "\t  [WARN] $@";
    return undef();
  } elsif( !$dbh ) {
    print STDERR ( "\t  [WARN] $dbname database handle undefined\n" );
    return undef();
  }
  return $dbh;
}


sub dump_keys {
    my ($hash) = @_;
    foreach my $key (sort keys %$hash) {
	warn "$key => $hash->{$key} \n";
    }
    warn '-' x 50;
}

exit;
