#!/usr/local/bin/perl

=head1 SYNOPSIS

update_static_content.pl [options]

Options:
  --help, --info, --species --update

B<-h,--help>
  Prints a brief help message and exits.

B<-i,--info>
  Prints man page and exits.

B<-s, --species>
  Species to dump

B<--site_type>
  Optional.  Default is main site.  Use this to set type to 'mirror' or 'archive' or 'pre'. 
 
B<--update>
  What to update

e.g.
   ./update_static_content.pl --species Tetraodon_nigroviridis --update new_release --site_type mirror

=head1 DESCRIPTION

B<This program:>

Updates the static content for the website

The current version  is specified in Ensembl web config file:
  ../conf/<SPECIES>.ini in the ENSEMBL_FTP_BASEDIR variable

=head1 OPTIONS

More on --update: Valid options are:

B< new_species:>
   Use the -site_type 'pre' flag if you are setting up pre.

   Runs generic_species_homepage, SSI (SSIabout, SSIexample, SSIentry),
   downloads, species_table


B<  generic_species_homepage:>;
    Creates a generic homepage as a first pass for the species.  
    This file needs /$species/ssi/stats.html too.  
    Run stats script separately.
    You need to create a file: htdocs/$species/ssi/karyotype.html 
    if the species has chromosomes

B<  downloads:>; 
    Creates a new FTP downloads section (htdocs/info/data/download_links.inc)
    If the site-type is archive, the links are to the versionned directories.
    If the site-type is main, the links are to current-species directories.

B<  SSI:>; 
    Creates a new ssi/about.html page template
    Creates a new ssi/examples.html page template
    Creates a new ssi/entry.html drop down form for entry points

B<  species_table:>; 
    Creates a first pass at the home page species table:
    htdocs/ssi/species_table.html


####### TO DO - CHECK ALL THESE AS MOSTLY UNNEEDED WITH NEW CODE #######
B<  new_release:>
   Runs versions, homepage_current_version, whatsnew, branch_versions
   archived_sites SSIdata_homepage assembly_table

B< new_mirror_release:>
   Runs homepage_current_version

B< new_mirror_species:>
   Runs generic_species_homepage, create_affili, species_table, SSIsearch, 
   homepage_current_version

B< branch_versions:>
   Creates a new page with updated versions for the current cvs branch
   (i.e. for the API, webcode etc)

B< assembly_table>;
    Updates htdocs/Docs/archive/homepage_SSI/assembly_table.html or 
    creates new one.  This file is included in htdocs/Docs/assemblies.html 
    and lists all the archived sites and which assemblies they show.

    Maintained by Fiona Cunningham <fc1@sanger.ac.uk>

=cut

use strict;
use warnings;
use Carp;
use Data::Dumper qw( Dumper );
use FindBin qw($Bin);
use File::Path;
use File::Basename qw( dirname );
use Pod::Usage;
use Getopt::Long;
use Time::localtime;

use vars qw( $SERVERROOT $help $info);
BEGIN{
  $SERVERROOT = dirname( $Bin );
  unshift @INC, "$SERVERROOT";
}


use utils::Tool;
use EnsEMBL::Web::DBSQL::NewsAdaptor;
use EnsEMBL::Web::SpeciesDefs;
my $SD = EnsEMBL::Web::SpeciesDefs->new;

# Connect to web database and get news adaptor
my $web_db = $SD->databases->{'ENSEMBL_WEBSITE'};
warning (1, "ENSEMBL_WEBSITE not defined in INI file") unless $web_db;
my $wa = EnsEMBL::Web::DBSQL::NewsAdaptor->new($web_db);

our $VERBOSITY = 1;
our $site_type = "main";
our $FIRST_ARCHIVE = 26;   # Release number for oldest archive site

my @species;
my @UPDATES;
&GetOptions( 
  'help'        => \$help,
  'info'        => \$info,
  'species=s'   => \@species,
  'update=s'    => \@UPDATES,
  'site_type=s' => \$site_type,
);

pod2usage(-verbose => 2) if $info;
pod2usage(1) if $help;

# Test validity of update requests ------------------------------------------
@UPDATES or  pod2usage("[*DIE] Need an update argument" );
my %updates = %{ check_types(\@UPDATES) };


# Only do once
if ($updates{species_table} ) {
  species_table($SERVERROOT);
  delete $updates{species_table};
}
if ($updates{downloads} ) {
  downloads($SERVERROOT);
  delete $updates{downloads};
}
if ( $updates{assembly_table} ) {
  assembly_table($SERVERROOT."/sanger-plugins/archive_central/htdocs/ssi");
  delete $updates{assembly_table};
}

exit unless keys %updates;

# Test validity of species arg -----------------------------------------------
if (@species) {
  @species = @{ utils::Tool::check_species(\@species) };
} else {
  @species = @{ utils::Tool::all_species()};
}

# Species specific ones
foreach my $sp (@species) {
  my $version_ini = utils::Tool::get_config({species =>$sp, values => "ENSEMBL_FTP_BASEDIR"})|| $sp;
  my $common_name = utils::Tool::get_config({species =>$sp, values => "SPECIES_COMMON_NAME"})|| $sp;
  my $chrs        = utils::Tool::get_config({species =>$sp, values => "ENSEMBL_CHROMOSOMES"});

  my @search      = utils::Tool::get_config({species =>$sp, values => "ENSEMBL_SEARCH_IDXS"});
  $version_ini    =~ s/(\w+)-//;

  info ("Using Ensembl root $SERVERROOT");
  info ("Using Ensembl species $sp");
  info ("Version from ini file is $version_ini");

  if ($updates{generic_species_homepage} ) { # KEEP!
    generic_species_homepage($SERVERROOT, $common_name, $sp, $chrs);
  }
  if ($updates{SSI} ) {
    SSI($SERVERROOT, $common_name, $sp, $chrs);
  }
}

exit;


#-----------------------------------------------------------------------------
 sub check_types {
   my $types = shift;

   my %valid_types = map{ $_ => 1 }
     qw(
	new_species      generic_species_homepage downloads SSI
                         species_table assembly_table 
       );

   my %compound_types = 
     ( new_species        => [ qw(generic_species_homepage downloads
				  SSI species_table
				 )],
      new_release        => [ qw( versions homepage_current_version whatsnew 
                                  branch_versions archived_sites assembly_table
                                  SSIdata_homepage) ],
      new_mirror_release => [ qw (homepage_current_version ) ],
     );

   # Validate types
   return utils::Tool::validate_types(\%valid_types, \%compound_types, $types);
 }

#----------------------------------------------------------------------
sub get_date {
  my $month = localtime->mon;
  my @months = qw (January February March April May June July August September October November December);
  return localtime->mday ." $months[$month] ". (localtime->year+1900);
}

#---------------------------------------------------------------------
sub check_dir {
  my $dir = shift;
  if( ! -e $dir ){
    info(1, "Creating $dir" );
    eval { mkpath($dir) };
    if ($@) {
      print "Couldn't create $dir: $@";
    }
  }
  return;
}

#----------------------------------------------------------------------
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

##############################################################################

sub species_table {
  return unless $site_type eq 'pre';

  my $dir = shift;
  my $title;
  if ($site_type eq 'pre') {
    $dir .= "/sanger-plugins/pre/htdocs/ssi";
    $title = "Browse a genome";
    &check_dir($dir);
  }
  else {
    $dir .= "/htdocs/ssi";
    $title = "Species";
    &check_dir($dir);
  }

  my $file = $dir ."/species_table.html.new";
  open (my $fh, ">$file") or die "Cannot create $file: $!";

  my %vega_spp = ( Homo_sapiens     => 1,
		   Mus_musculus     => 1,
		   Canis_familiaris => 1,
		   Danio_rerio      => 1 );

  my @species = @{ utils::Tool::all_species() };

  print $fh qq(

   <h3 class="boxed">$title</h3>
    <dl class="species-list">

);

  foreach my $spp ( @species ) {
    my $bio_name = utils::Tool::get_config({species =>$spp,
					  values => "SPECIES_BIO_NAME"});
    my $assembly = utils::Tool::get_config({species =>$spp,
					  values => "ASSEMBLY_ID"});

    print $fh qq(
 <dt>
    <a href="/$spp">
    <img src="/img/species/thumb_$spp.png" width="40" height="40" alt="" style="float:left;padding-right:4px;" /></a>$bio_name 
 <span class="small normal">[$assembly]</span>
 </dt>
            <dd><a href="/$spp/">browse</a>
);

    if ( $vega_spp{$spp} ) {
      print $fh qq( 
          | <a href="http://vega.sanger.ac.uk/$spp/">Vega</a>
    );
    }
      print $fh "</dd>";
  }
  print $fh qq(
   </dl>

);

  if (-e "$dir/species_table.html") {
    system ("cp $dir/species_table.html $dir/species_table.html.bck")==0 or die "Couldn't copy files";
  }
  system ("mv $dir/species_table.html.new $dir/species_table.html") ==0 or die "Couldn't copy files";
  info (1, "Updated species table file $dir/species_table.html");
return;
}
#---------------------------------------------------------------------

sub generic_species_homepage {
  my ($dir, $common_name, $species, $chrs) = @_;

  if ($site_type eq 'pre') {
    $dir .= "/sanger-plugins/pre/htdocs/$species";
    &check_dir($dir);
  }
  else {
    $dir .= "/public-plugins/ensembl/htdocs/$species";
    &check_dir($dir);
  }
  my $file = $dir ."/index.html";
  if (-e $file) {
    info (1, "File $file already exists");
    return;
  }
  open (my $fh, ">$file") or die "Cannot create $file: $!";

  # check for chromosomes
  my $explore = 'examples';
  if ( (scalar @$chrs) > 0 ) {
    $explore = 'karyomap';
  }

  my $bio_name = utils::Tool::get_config({species =>$species,
					  values => "SPECIES_BIO_NAME"});
  print $fh qq(
<html>
<head>
<title>$common_name ($bio_name)</title>
</head>
<body>
<h2>Explore the <i>$bio_name</i> genome</h2>);

print $fh qq(
<div class="col-wrapper">
    <div class="col2">
    [[INCLUDE::/$species/ssi/$explore.html]]
    [[INCLUDE::/$species/ssi/entry.html]]
    </div>
);

print $fh qq(
    <div class="col2">
    [[INCLUDE::/$species/ssi/search.html]]
    </div>
</div>
<div class="col-wrapper">
) unless $site_type eq 'pre';

print $fh qq(
    <div class="col2">
    [[INCLUDE::/$species/ssi/about.html]]
    </div>
);
print $fh qq(
    <div class="col2">
    [[INCLUDE::/$species/ssi/stats.html]]
    </div>
) unless $site_type eq 'pre';

print $fh qq(
</div>
</body>
</html>
  );
  info (1, "Created a generic $species homepage: $file");
  return;
}

##############################################################################
sub SSI {
  my ($dir, $common_name, $species, $chrs) = @_;

  if ($site_type eq 'pre') {
    $dir .= "/sanger-plugins/pre/htdocs/$species/ssi";
    &check_dir($dir);
  }
  else {
    $dir .= "/public-plugins/ensembl/htdocs/$species/ssi";
    &check_dir($dir);
  }
  &SSIabout($dir, $common_name, $species);

  if ( (scalar @$chrs) > 0 ) {
    &SSIentry($dir, $species, $chrs);
    &SSIkaryomap($dir, $species, $common_name);
  }
  else {
    &SSIexamples($dir, $species);
    &SSIentry($dir, $species, 0);
  }
  return;
}

#---------------------------------------------------------------------------
sub SSIentry {
  my ($dir, $species, $chrs) = @_;
  my $file = $dir ."/entry.html";
  
  if (-e $file) {

  }
  open (my $fh, ">$file") or die "Cannot create $file: $!";
  if ($chrs) {
    print $fh qq(
<form action="/$species/contigview">
<p>Jump directly to sequence position</p>
<table align="center">
<tr>
  <td style="text-align:right">Chromosome:</td>
  <td><select name="chr">
    <option value="">==</option>
);

    foreach my $chr (@$chrs) {
      print $fh qq(
    <option>$chr</option>
);
    }
    print $fh qq(
  </select> or region
  <input type="text" value="" class="small" name="region" /></td>
</tr>
<tr>
  <td style="text-align:right">From (bp):</td>
  <td><input type="text" value="" class="small" name="start" /></td>
</tr>
<tr>
  <td style="text-align:right">To (bp):</td>
  <td><input type="text" value="" class="small" name="end" />
      <input type="submit" value="Go" class="red-button" /></td>
</tr>
</table>
</form>
);
  }
  else {
  print $fh qq(
<form action="/$species/contigview">
<p>Jump directly to sequence position</p>
<table align="center">
<tr>
  <td style="text-align:right">Region:</td>
  <td><input type="text" value="" class="small" name="region" /></td>
</tr>
<tr>
  <td style="text-align:right">From (bp):</td>
  <td><input type="text" value="" class="small" name="start" /></td>
</tr>
<tr>
  <td style="text-align:right">To (bp):</td>
  <td><input type="text" value="" class="small" name="end" />
      <input type="submit" value="Go" class="red-button" /></td>
</tr>
</table>
</form>
);
}
  info (1, "Template for species entry page $file");
  return;
}

#------------------------------------------------------------------------------
sub SSIabout {
  my ($dir, $common_name, $species) = @_;
  my $file = $dir ."/about.html";
  return if -e $file;
  open (my $fh, ">$file") or die "Cannot create $file: $!";
  print $fh qq(
  <h3 class="boxed">About the $common_name genome</h3>

<h4>Assembly</h4>

<p><img src="/img/species/pic_$species.png" height="100" width="100" class="float-left" alt="$common_name" title="">

</p>

<h4>Annotation</h4>
<p>

</p>
);
  info (1, "Template for about page $file");
  return;
}

#------------------------------------------------------------------------------

sub SSIexamples {
  my ($dir, $species) = @_;
  my $entry = $dir ."/examples.html";
  return if -e $entry;
  open (my $fh2, ">$entry") or die "Cannot create $entry: $!";
  print $fh2 qq(
<h3 class="boxed">Example Data Points</h3>

<p>
This release of <i>$species</i> data is assembled into scaffolds, so there are no chromosomes available to browse.
</p>

<p>A few example data points :</p>
<ul class="spaced">
    <li>
    </li>
    <li>
    </li>
    <li>
    </li>
</ul>
);  
  info (1, "Template for example page $entry ");
  return;
}
#---------------------------------------------------------------------------

sub SSIkaryomap {
  my ($dir, $species, $common_name) = @_;
  my $karyomap = $dir ."/karyomap.html";
  return if -e $karyomap;
  open (my $fh2, ">$karyomap") or die "Cannot create $karyomap: $!";
  print $fh2 qq(
<h3 class="boxed">Karyotype</h3>

<p>Click on a chromosome for a closer view</p>

<img src="/img/species/karyotype_$species.png" width="245" height="355" usemap="#karyotypes" alt="$common_name karyotype selector" />
);
  info (1, "Template for karyomap page $karyomap");
  return;
}

#############################################################################
sub downloads {
  my $dir = shift;
  return if $site_type eq 'pre';
  do_downloads("$dir/sanger-plugins/archive", "archive");
  do_downloads("$dir", 0);
  return;
}
#----------------------------------------------------------------------------
sub do_downloads {
  my $dir     = shift;
  my $archive = shift;
  &check_dir($dir);
  $dir .= "/htdocs/info/data";
  &check_dir($dir);

  my $new_file = "$dir/download_links.inc.new";
  open (NEW, ">",$new_file) or die "Couldn't open file $new_file: $!";
  print NEW qq(
<table class="spreadsheet" cellpadding="4">

<tr>
<th>Species</th>
<th>DNA</th>
<th>cDNA</th>
<th>Peptides</th>
<th>EMBL</th>
<th>GenBank</th>
<th>MySQL</th>
</tr>

);

  foreach my $spp (@{[@{ utils::Tool::all_species()}] }) {
    my $version_ini = utils::Tool::get_config({species =>$spp, values => "ENSEMBL_FTP_BASEDIR" });
    my $description = utils::Tool::get_config({species =>$spp, values => "SPECIES_DESCRIPTION" });   
    my $common = lc(utils::Tool::get_config({species =>$spp, values => "SPECIES_COMMON_NAME" }));
    $common = 'mosquito' if $common eq 'anopheles';
    $common = 'bee' if $common eq 'honeybee';
    $common = 'yeast' if $common eq 's.cerevisiae';
    $common = 'ciona' if $common eq 'c.intestinalis';
    $common =~ s/\.//;
    $common =~ s/fruit//;
    my $url = $archive ? $version_ini : "current_".$common;
    $spp =~ s/_/ /;
    print NEW qq(
<tr>
<td>
<a target="ftp" href="ftp://ftp.ensembl.org/pub/$url/"><i>$spp</i></a> ($description)</td>
<td><a target="ftp" href="ftp://ftp.ensembl.org/pub/$url/data/fasta/dna/">FTP</a></td>
<td><a target="ftp" href="ftp://ftp.ensembl.org/pub/$url/data/fasta/cdna/">FTP</a></td>
<td><a target="ftp" href="ftp://ftp.ensembl.org/pub/$url/data/fasta/pep/">FTP</a></td>
<td><a target="ftp" href="ftp://ftp.ensembl.org/pub/$url/data/flatfiles/embl/">FTP</a></td>
<td><a target="ftp" href="ftp://ftp.ensembl.org/pub/$url/data/flatfiles/genbank/">FTP</a></td>
<td><a target="ftp" href="ftp://ftp.ensembl.org/pub/$url/data/mysql/">FTP</a></td>
</tr>
	    );

}
  print NEW qq(</table>);
  close NEW;
  if (-e "$dir/download_links.inc") {
    system ("cp $dir/download_links.inc $dir/download_links.inc.bck")==0 or die "Couldn't copy files";
  }
  system ("mv $dir/download_links.inc.new $dir/download_links.inc") ==0 or die "Couldn't copy files";
  info (1, "Created downloads pages $dir ");
  return;
}

##############################--  ARCHIVE --################################

sub assembly_table {
  my ( $dir ) = @_;
  &check_dir($dir);
  my $file  = $dir."/assembly_table.inc";
  my $this_release = utils::Tool::species_defs("ENSEMBL_VERSION");

  my $header_row = qq(<th>Species</th>\n);
  my %info;

  foreach my $data ( @{$wa->fetch_releases()} ) {
    my $release_id = $data->{release_id};
    last if $release_id == 25;
   (my $link = $data->{short_date}) =~ s/\s+//;

    $header_row .=qq(<th><a href="http://$link.archive.ensembl.org">$data->{short_date}</a><br />v$release_id</th>);


    # If the assembly name spans several releases,%info stores its first release only
    # %info{species}{assembly name} = release num

    foreach my $assembly_info ( @{ $wa->fetch_assemblies($release_id)  }  ) {
      $info{ $assembly_info->{species} }{ $assembly_info->{assembly_name} } = $release_id;
    }
  }

  my $table;
  my @tint = qw(class="bg4" class="bg2");
  foreach my $species (sort keys %info) {
    (my $display_spp = $species) =~ s/_/ /;
    $table .=qq(<tr>\n   <th><a href="http://www.ensembl.org/$species">$display_spp</a></th>\n);

    my %assemblies = reverse %{ $info{$species} };

    my $release_counter = $this_release;
    foreach my $release (sort {$b <=> $a} keys %assemblies  ) {

      my $colspan = $release_counter - $release;
      $colspan++;# if $release_counter == $this_release;
      $release_counter -= $colspan;
      $table .= qq(   <td $tint[0] colspan="$colspan">$assemblies{$release}</td>\n);
      push ( @tint, shift @tint );
    }
    $table .= "</tr>\n\n";
  }

  # Update the file ..
  open (my $fh, ">$file") or die "Cannot create $file: $!";
  print $fh qq(\n<table style="margin:auto; width:95%" border="1" class="spreadsheet archive">\n<tr>$header_row</tr>\n);
  print $fh qq($table</table>\n);
  return;
}

#############################################################################
sub branch_versions {
  my ($dir, $version_ini, $common_name,$species) = @_;

  $dir .= "whatsnew/";
  &check_dir($dir);

  (my $api = $version_ini) =~ s/(\d+)\.(.*)/$1/;
  my $date = &get_date;

  my $file = $dir."current.html";
  open (CURR, ">$file") or die "Cannot create $file: $! ";

  print CURR qq(
<html>
<head>
<meta name="navigation" content="Ensembl" />
<title>Ensembl $common_name Current Version</title>
</head>
<body>

<h2 class="boxed">Current Status</h2>

<h3>Versions in Ensembl $common_name v$version_ini</h3>

<ul>
    <li><p><strong>Ensembl Release version&nbsp;-&nbsp;v$api</strong><br />
        cvs tag : branch-ensembl-$api</p></li>

    <li><p><strong>Data&nbsp;-&nbsp;v$version_ini </strong></p></li>

    <li><p><strong>BioPerl&nbsp;-&nbsp;v1.2.3</strong></p></li>
    <li><p><strong>BioMart&nbsp;-&nbsp;v0.2</strong><br />
        cvs tag : release-0_2</p></li>
</ul>

<p><a href="/$species/whatsnew/versions.html">Further information about Ensembl versioning</a>.

</body>
</html> 
		);
  close CURR;
  return;
}


