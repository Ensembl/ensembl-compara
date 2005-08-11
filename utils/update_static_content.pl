#!/usr/local/bin/perl

=head1 NAME

update_static_content.pl

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

The output is written as html to files:
  ../htdocs/<SPECIES>/index.html
  ../htdocs/<SPECIES>/ssi/search.html

=head1 OPTIONS

More on --update: Valid options are:

B< new_species:> UPDATED
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

B< new_archive_site:>
   Runs create_affili, create_links, SSIsearch, htdocs_nav
   SSIdata_homepage, downloads, create_homepage_affili, 
   homepage_ensembl_start homepage_current_version,

B < archive.org: >
   Runs assembly_table, archived_sites

B< new_mirror_release:>
   Runs homepage_current_version

B< new_mirror_species:>
   Runs generic_species_homepage, create_affili, species_table, SSIsearch, 
   homepage_current_version

B<  versions:>; 
   Creates/updates the $species/whatsnew/versions.html file which explains 
   the versioning system used in Ensembl

B<  homepage_current_version:> 
   Creates a new server-side include file to include this text 
   'Current Version xx.x'  where xx is release version and x the assembly
   The version is retrieved from the conf/$species.ini file
   This file is included in the species specific homepage.

B< branch_versions:>
   Creates a new page with updated versions for the current cvs branch
   (i.e. for the API, webcode etc)

B<  stats_index:>; 
    Creates a new, generic htdocs/$species/stats/index.html file.
    This file needs /$species/stats/stats.html too.  
    Run stats script separately

B<  create_links:>;
    Creates a new page SSI_homepage/links.html with links to Blast, Help, EnsMart, SiteMap and Export.
    This is included in the species homepage (not mirror).  Excludes link
    to blast/ssaha.

B<  create_affili:>; 
    Creates a new affiliations.html file for the htdocs/$species/homepage_SSI 
    directory.  This makes sure the species homepage has the correct ebang
    logo (i.e. pre!, archive! or e!)

B<  create_homepage_affili:>;
    Creates a new affiliations.html file for the htdocs/homepage_SSI
    directory.  This makes sure the site homepage has the correct ebang
    logo (i.e. pre!, archive! or e!)

B<  htdocs_nav:>; 
    Creates a new def_nav.conf which is used for the static content directories. Links to Blast and ssaha are omitted if site_type is 'archive'

B<  SSIdata_homepage:>; 
    Creates a new htdocs/homepage_SSI/data.html page with out blast link
    and with white buttons for the archive site.

B< homepage_ensembl_start>;
    Creates a new file for htdocs/homepage_SSI/ensemblstart.html for the
    archive site.

B< archived_sites>;
    Updates htdocs/Docs/archive/homepage_SSI/sites.html or creates new one.
     This file is included in htdocs/Docs/index.html and lists all the
    archived site URLs.
    
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


# Test validity of species arg -----------------------------------------------
if (@species) {
  @species = @{ utils::Tool::check_species(\@species) };
} else {
  @species = @{ utils::Tool::all_species()};
}

# Loop through species given--------------------------------------------------

# Find ENSEMBL_VERSION
foreach my $sp (@species) {
  my $version_ini = utils::Tool::get_config({species =>$sp, values => "ENSEMBL_FTP_BASEDIR"})|| $sp;
  my $common_name = utils::Tool::get_config({species =>$sp, values => "SPECIES_COMMON_NAME"})|| $sp;
  my $chrs        = utils::Tool::get_config({species =>$sp, values => "ENSEMBL_CHROMOSOMES"});

  my @search      = utils::Tool::get_config({species =>$sp, values => "ENSEMBL_SEARCH_IDXS"});
  $version_ini    =~ s/(\w+)-//;

  info ("Using Ensembl root $SERVERROOT");
  info ("Using Ensembl species $sp");
  info ("Version from ini file is $version_ini");

  my $SPECIES_ROOT = $SERVERROOT ."/htdocs/$sp/";
  check_dir($SPECIES_ROOT);

  if ($updates{generic_species_homepage} ) { # KEEP!
    generic_species_homepage($SERVERROOT, $common_name, $sp, $chrs);
  }
  if ($updates{SSI} ) {
    SSI($SERVERROOT, $common_name, $sp, $chrs);
  }
 #  if ($updates{homepage_current_version} ) {
#     homepage_current_version($SERVERROOT, $version_ini, $sp);
#   }
#   if ($updates{whatsnew} ) {
#     whatsnew($SERVERROOT, $version_ini, $sp, $common_name);
#   }
#   if ($updates{branch_versions} ) { # PROBABLY KEEP
#     branch_versions($SPECIES_ROOT, $version_ini, $common_name, $sp);
#   }
#   if ($updates{versions} ) {
#     versions($SPECIES_ROOT."whatsnew/", $common_name, $sp, $version_ini);
#   }

#   if ($updates{SSIsearch} ) {
#     SSIsearch($SERVERROOT, $sp, $chrs, @search);
#   }
#   if ($updates{create_links} ) {
#     create_links($SPECIES_ROOT."homepage_SSI/", $common_name, $sp);
#   }
#   if ($updates{create_affili} ) {
#     create_affili($SPECIES_ROOT."/homepage_SSI/", $common_name, $sp);
#   }
#   if ($updates{stats_index} ) {
#     stats_index($SPECIES_ROOT."/stats/", $common_name, $sp, $version_ini);
#   }
#   if ($updates{htdocs_nav} ) {
#     htdocs_nav($SERVERROOT, $sp);
#   }
}

my $release = utils::Tool::get_config({species => "Multi", values => "ENSEMBL_FTP_BASEDIR"});
$release =~ s/\w+-\w*-(\d+).*/$1/;


# Only do once
if ($updates{species_table} ) {
  species_table($SERVERROOT);
}
if ($updates{downloads} ) {
  downloads($SERVERROOT);
}
if ( $updates{archived_sites} ) {
   archived_sites($SERVERROOT."/htdocs/Docs/", $release);
}
if ( $updates{assembly_table} ) {
  assembly_table($SERVERROOT."/htdocs/Docs/",  $release );
}

exit;


#-----------------------------------------------------------------------------
 sub check_types {
   my $types = shift;

   my %valid_types = map{ $_ => 1 }
     qw(
	new_species      generic_species_homepage downloads SSI
                         species_table
        new_archive_site archived_sites assembly_table 
       );

   my %compound_types = 
     ( new_species        => [ qw(generic_species_homepage downloads
				  SSI species_table
				 )],

      new_species_oldsite        => [ qw(stats_index generic_species_homepage 
				 create_links create_affili 
                                 homepage_current_version  
				 species_table SSIsearch  SSIhelp downloads)],
      new_mirror_species => [ qw( generic_species_homepage create_affili 
                                  homepage_current_version
		       	          species_table SSIsearch  ) ],
      new_release        => [ qw( versions homepage_current_version whatsnew 
                                  branch_versions archived_sites assembly_table
                                  SSIdata_homepage) ],
      new_mirror_release => [ qw (homepage_current_version ) ],
      new_archive_site   => [ qw (create_links create_affili SSIsearch 
				 htdocs_nav SSIhelp SSIdata_homepage
                                 downloads create_homepage_affili
                                 homepage_ensembl_start
                                 homepage_current_version) ],
      "archive.org"      => [ qw( archived_sites assembly_table) ],
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
    system("mkdir -p $dir") == 0 or
      ( warning( 1, "Cannot create $dir: $!" ) && next );
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
   </ul>

);

  if (-e "$dir/species_table.html") {
    system ("cp $dir/species_table.html $dir/species_table.html.bck")==0 or die "Couldn't copy files";
  }
  system ("mv $dir/species_table.html.new $dir/species_table.html") ==0 or die "Couldn't copy files";

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
  }
  else {
    &SSIexamples($dir);
    &SSIentry($dir, $species, 0);
  }
  return;
}

#---------------------------------------------------------------------------
sub SSIentry {
  my ($dir, $species, $chrs) = @_;
  my $file = $dir ."/entry.html";

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
      warn $chr;
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
  return;
}

#------------------------------------------------------------------------------

sub SSIexamples {
  my ($dir) = @_;
  my $entry = $dir ."/examples.html";
  return if -e $entry;
  open (my $fh2, ">$entry") or die "Cannot create $entry: $!";
  print $fh2 qq(
<h3 class="boxed">Example Data Points</h3>

<p>

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

  foreach my $spp (@{ utils::Tool::all_species()}) {
    my $version_ini = utils::Tool::get_config({species =>$spp, values => "ENSEMBL_FTP_BASEDIR" });
    my $description = utils::Tool::get_config({species =>$spp, values => "SPECIES_DESCRIPTION" });   
    my $common = utils::Tool::get_config({species =>$spp, values => "SPECIES_COMMON_NAME" });
    $common = 'mosquito' if $common eq 'Anopheles';
    $common = 'bee' if $common eq 'Honeybee';
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
  return;
}

##############################--  ARCHIVE --################################
sub homepage_ensembl_start {
 my ($dir) = @_;
  &check_dir($dir);

  my $file = $dir."ensemblstart.html";
  open (ABOUT, ">$file") or die "Cannot create $file: $!";

  my $date_nospace = utils::Tool::species_defs->ARCHIVE_VERSION;
  (my $date = $date_nospace) =~ s/(\d+)/ $1/;;
  
  print ABOUT qq(

<table align="center" cellpadding="0" cellspacing="0" border="0" width="300">
 <tr class="background2">
  <td align="center" class="h5" >Archive Ensembl: $date</td>
 </tr>

 <tr valign="top">
  <td class="background1" ><img src="/gfx/blank.gif" height="5" width="300" alt=""></td>
 </tr>

 <tr class="background1" valign="top">
  <td class="small"><img src="/gfx/header/archive/roundel$date_nospace.gif" width="120" height="120" align="left" vspace="5" hspace="10"  alt="Free Unrestricted Genome Access For All">

   The $date Ensembl Archive site is a freeze of the live site 
   (<a href="http://www.ensembl.org">www.ensembl.org</a>) from $date.
   The links to this site will be stable for at two years making 
   them suitable for use in publications.  More information about archive
   sites is available <a href="http://archive.ensembl.org">here</a>.
  <br><br>

   The latest data will always be available at 
   <a href="http://www.ensembl.org">www.ensembl.org</a>.  There are 
   links at the bottom of each page in the 
   Ensembl Archive site to the equivalent page in the Ensembl main 
   site (and vice-versa).

  <br><br> 

   Please note BLAST is not available in the Ensembl Archive site.  

 </tr>
</table>
  );
  close ABOUT;
  return;
}

#----------------------------------------------------------------------------
sub archived_sites {
  my ($root_dir, $release) = @_;
  my $dir = $root_dir."archive/";
  &check_dir($dir);
  $dir .= "homepage_SSI";
  &check_dir($dir);

  &create_homepage_affili("$dir/", 1 );

  # Read the old file
  my %versions;
  my $file  = $dir."/sites.html";
  if ( -e $file) {
    open (SITES, "$file") or die "Cannot open $file: $!";
    while (my $line = <SITES>) {
        next if ($line =~/<!-- VERSION LIST _ DO NOT MODIFY -->/);
        last if  ($line =~/<!-- END VERSION LIST-->/);

      # Format of version lines
      #<!--\tVERSION\t27.1\tDec2004\t-->
      my @tmp = split /\s+/, $line;
      $versions{ $tmp[2] } = $tmp[3]; 
    }
  }
  close SITES;

  # Update the file
  my $date = utils::Tool::species_defs->ARCHIVE_VERSION;
  warn $date;
   $versions{$release} = $date unless $versions{$release};
  open (my $fh, ">$file") or die "Cannot create $file: $!";
  print $fh qq(<!-- VERSION LIST _ DO NOT MODIFY -->\n);

  foreach my $api_num (sort {$b <=> $a} keys %versions ) {
   print $fh qq(<!--\tVERSION\t$api_num\t$versions{$api_num}\t-->\n);
  }
  print $fh qq(<!-- END VERSION LIST-->\n);

  foreach my $api (sort {$b <=> $a} keys %versions ) {
    if ($api eq $release) {
      print $fh qq(

  <tr class="background1">
   <td valign="center" align="center" class="h6" nowrap>
     Ensembl version $api   
   </td>
   <td valign="center" align="center">
       $versions{$api}
   </td>   
    <td colspan="2" valign="center" align="left" nowrap> 
    <a href="http://$versions{$api}.archive.ensembl.org">http://$versions{$api}.archive.ensembl.org</a>
    </td>
<td>&nbsp;Currently <a href="http://www.ensembl.org">www.ensembl.org</a></td>
  </tr>\n);
    }
    else {
  print $fh qq(

  <tr class="background1">
   <td valign="center" align="center" class="h6" nowrap>
     Ensembl version $api
   </td>
   <td valign="center" align="center">
       $versions{$api}
   </td>   
    <td colspan="3" valign="center" align="left" nowrap>
    <a href="http://$versions{$api}.archive.ensembl.org">http://$versions{$api}.archive.ensembl.org</a>
    </td>
  </tr>\n);
}
  }
  print $fh qq( <tr><td align="center" colspan="5"><br />
                 <img width="8" height="8" src="/gfx/bullet.blue.gif" alt="o">
                 <b>Assemblies</b>: 
                 &nbsp;<a href="http://archive.ensembl.org/assembly.html">Here</a> 
                 is a table listing the assemblies in each archive site 
                 for each species.</td></tr>
   );
  return;
}

#-----------------------------------------------------------------------------
sub assembly_table {
  my ( $root_dir, $release ) = @_;
  my $dir = $root_dir."archive/";
  &check_dir($dir);
  $dir .= "homepage_SSI";
  &check_dir($dir);
  &create_homepage_affili("$dir/", 1 );
  my $file  = $dir."/assembly_table.html";

  # Read the old file
  my %assemblies;
  if ( -e $file) {
    open (IN, "$file") or die "Cannot open $file: $!";
    while (my $line = <IN>) {
      next if ($line =~/<!-- DO NOT MODIFY -->/);
      last if  ($line =~/<!-- END DO NOT MODIFY -->/);

      # Format of version lines
      #<!--UPDATED\t$species\tfirst_release\t$assembly\t$date-->
      #<!--UPDATED   Homo_sapiens   23   NCBI35  Oct2004-->
      my @tmp = split /\s+/, $line;
      $assemblies{ $tmp[1] }{ $tmp[2] } = [ $tmp[3], $tmp[4] ];
    }
  }
  close IN;

  # Update the file ..
  open (my $fh, ">$file") or die "Cannot create $file: $!";
  print $fh qq(<!-- DO NOT MODIFY -->\n);
  my @rows;
  my %header;
  foreach my $species ( sort @{ utils::Tool::all_species()}  ) {
    my $golden_path = utils::Tool::get_config({species =>$species,
				       values => "ENSEMBL_GOLDEN_PATH"});
    my $spp_name = utils::Tool::get_config({species =>$species,
				       values => "SPECIES_COMMON_NAME"});

    my @sorted_releases =  (sort {$b <=> $a} keys %{ $assemblies{$species} } );
    # If this is a new golden path, updated the hash with this release number
    my $last_update    = $sorted_releases[0];

   if ( !$last_update or  $assemblies{$species}{$last_update}->[0] ne $golden_path ) {
      my $archive_date = utils::Tool::species_defs->ARCHIVE_VERSION;
      $assemblies{$species}{$release} = [$golden_path, $archive_date];	
    }
    # HTML stuff
    my $row = qq(<tr><td class="h5" align="center"><a href="http://www.ensembl.org/$species"><i>$spp_name</i></a></td> );
    my $release_counter = $release;
    my @background = qw(class="background1" class="background3");
    my $flag_first_time = 0;
   foreach my $old_release ( sort {$b <=> $a} keys  %{ $assemblies{$species} } ) {
     my ($assembly, $date ) = @{ $assemblies{$species}{$old_release} };

     # For easy parsing print this at the start of the file
     print $fh qq(<!--UPDATED\t$species\t$old_release\t$assembly\t$date\t-->\n);

     # Prepare this for the HTML table
     $header{$old_release} = $date;
     my $colspan = $release_counter - $old_release;
     $release_counter = $old_release - $colspan;
     $colspan++ unless $flag_first_time;
     $row .= qq(<td $background[0] colspan="$colspan" align="center"> $assembly</td>);
     push ( @background, shift @background );
     $flag_first_time++;
   }
    $row .= "</tr>";
    push (@rows, $row );
  }
  print $fh qq(<!-- END DO NOT MODIFY -->\n);
  print $fh qq(<table align="center" border="1" cellpadding="0" cellspacing="0" width="90%">\n);
  $release++;
  my $header = qq(<tr class="background2"><td class="h6" align="center">
                      Latest species<br />assembly (v.$release)</td>);
  foreach my $release_num (sort {$b <=> $a } keys %header ) {
    $header .= qq(<td class="h6" align="center" ><a href="http://$header{$release_num}.archive.ensembl.org">$header{$release_num}<br /></a>v. $release_num</td>\n );
  }

  print $fh $header, "</tr>\n";
  print $fh join "\n", @rows;
  print $fh qq(</table>);
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
#-----------------------------------------------------------------------------
sub create_links {

  info('Skipping - create_links not needed by new template');
	    
  return;
}
#----------------------------------------------------------------------------
sub create_affili {

  info('Skipping - create_affili not needed by new template');
	    
  return;
}
#--------------------------------------------------------------------
sub create_homepage_affili {

  info('Skipping - create_homepage_affili not needed by new template');
	    
 return;
}
#----------------------------------------------------------------------------  
sub institute_collaborate_logos {

  info('Skipping - institute_collaborate_logos not needed by new template');
	    
}

#---------------------------------------------------------------------
sub stats_index {
  info('Skipping - stats_index not needed by new template');
  return;
}

#----------------------------------------------------------------------------
sub versions {
  info('Skipping - species specific version page not needed by new template');
}
#-----------------------------------------------------------------------------
sub SSIsearch {

  info('Skipping - SSIsearch not needed by new template');
	    
return;
}

#----------------------------------------------------------------------------
sub htdocs_nav {

  info('Skipping - htdocs_nav not needed by new template');
	    
return;
}

#----------------------------------------------------------------------------
sub SSIdata_homepage {

  info('Skipping - SSIdata_homepage not needed by new template');
	    
return;
}
#-------------------------------------------------------------------------
sub homepage_current_version {

  info('Skipping - homepage_current_version not needed by new template');

return;

}
#---------------------------------------------------------------------------

sub whatsnew {

  info('Skipping - whatsnew not needed by new template');

  return 1;
}
#----------------------------------------------------------------------
sub whatsnew_index {


  info('Skipping - whatsnew_index not needed by new template');

  return;
}

