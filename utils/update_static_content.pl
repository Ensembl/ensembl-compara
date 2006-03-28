#!/usr/local/bin/perl

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
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::DBSQL::MetaContainer;
require SiteDefs;
my $SD = EnsEMBL::Web::SpeciesDefs->new;

our $VERBOSITY = 1;
our $site_type = "main";
our $FIRST_ARCHIVE = 25;   # Release number for oldest archive site
my $release;

my @species;
my @UPDATES;
&GetOptions( 
  'help'        => \$help,
  'info'        => \$info,
  'species=s'   => \@species,
  'update=s'    => \@UPDATES,
  'sitetype=s'  => \$site_type,
  'release=s'   => \$release,
);

pod2usage(-verbose => 2) if $info;
pod2usage(1) if $help;


# Test validity of update requests ------------------------------------------
@UPDATES or  pod2usage("[*DIE] Need an update argument" );
my %updates = %{ check_types(\@UPDATES) };

my $version =   $SiteDefs::ENSEMBL_VERSION;

# Only do once
if ($updates{species_table} ) {
  species_table($SERVERROOT, $release);
  delete $updates{species_table};
}
if ($updates{downloads} ) {
  downloads($SERVERROOT, $version);
  delete $updates{downloads};
}
if ( $updates{assembly_table} ) {
  assembly_table($SERVERROOT."/sanger-plugins/archive_central/htdocs/ssi");
  delete $updates{assembly_table};
}
if ( $updates{copy_species_table} ) {
  copy_species_table( $SERVERROOT );
  delete $updates{copy_species_table};
}
exit unless keys %updates;

# Test validity of species arg -----------------------------------------------
if (@species) {
  @species = @{ utils::Tool::check_species(\@species) };
} else {
  @species = @{ utils::Tool::all_species()};
}

utils::Tool::info ("Using Ensembl root $SERVERROOT");
utils::Tool::info ("Version from ini file is $version");

# Species specific ones
foreach my $sp (@species) {
  utils::Tool::info ("Using Ensembl species $sp");
  my $common_name = utils::Tool::get_config({species =>$sp, values => "SPECIES_COMMON_NAME"})|| $sp;
  my $chrs        = utils::Tool::get_config({species =>$sp, values => "ENSEMBL_CHROMOSOMES"});

  if ($updates{generic_species_homepage} ) { # KEEP!
    generic_species_homepage($SERVERROOT, $common_name, $sp, $chrs);
  }
  if ($updates{SSI} ) {
    SSI($SERVERROOT, $common_name, $sp, $chrs);
  }
  if ($updates{blast_db} ) {
    blast_db($SERVERROOT, $sp);
  }
  if ( $updates{gene_build } ) {
    gene_build( $sp );
  }
}

exit;


#-----------------------------------------------------------------------------
 sub check_types {
   my $types = shift;

   my %valid_types = map{ $_ => 1 }
     qw(
	new_species      generic_species_homepage downloads SSI 
                         gene_build species_table
	archive          assembly_table copy_species_table
        release          blast_db
       );

   my %compound_types = 
     ( new_species       => [ qw( generic_species_homepage downloads
				  SSI species_table gene_build
				 )],
      release            => [ qw ( blast_db gene_build ) ],
      archive            => [ qw ( assembly_table copy_species_table ) ],
     );

   # Validate types
   my $tmp = utils::Tool::validate_types(\%valid_types, \%compound_types, $types);
   my %return;
   map { $return{$_} = 1} @$tmp;
   return \%return;
 }


##############################################################################
sub gene_build {
  my $species = shift;
  my $db_adaptor = Bio::EnsEMBL::Registry->get_DBAdaptor($species, "core");
  my $meta_container = $db_adaptor->get_MetaContainer();
  my $gene_build =  $meta_container->get_genebuild();
  my ($highest_cs) = @{$db_adaptor->get_CoordSystemAdaptor->fetch_all()};
  my $assembly = $highest_cs->version();

  $gene_build =~ /(\d{2})(\d{2})(.*)/;
  my $date = "20".$1."-$2";
  my $builder = $3;
  my $ini_date = utils::Tool::get_config({species =>$species,
					  values => "GENEBUILD_DATE"});
  my $ini_builder = utils::Tool::get_config({species =>$species,
					     values => "GENEBUILD_BY"});
  my $ini_assembly = utils::Tool::get_config({species =>$species,
					     values => "ENSEMBL_GOLDEN_PATH"});
  utils::Tool::warning(1, "GENEBUILD_BY INI file: $ini_builder, db: $builder") if $builder ne $ini_builder;
  utils::Tool::warning(1, "GENEBUILD_DATE INI file: $ini_date, db: $date") if $date ne $ini_date;
  utils::Tool::warning(1, "GOLDEN PATH INI file: $ini_assembly, db: $assembly") if $assembly ne $ini_assembly;
}

sub species_table {
  my ($dir, $release) = @_;
  $dir .= "/sanger-plugins/sanger/utils";
  my $release_text  = $release ? "--release $release" : "";
  system( "$dir/homepage.pl --sitetype pre $release_text");
  return;
}
#---------------------------------------------------------------------

sub generic_species_homepage {
  my ($dir, $common_name, $species, $chrs) = @_;

  if ($site_type eq 'pre') {
    system ("cp $dir/public-plugins/ensembl/htdocs/img/species/thumb_$species.png $dir/sanger-plugins/pre/htdocs/img/species/");
    system ("cp $dir/public-plugins/ensembl/htdocs/img/species/pic_$species.png $dir/sanger-plugins/pre/htdocs/img/species/");
    $dir .= "/sanger-plugins/pre/htdocs/$species";
    utils::Tool::check_dir($dir);
  }
  else {
    $dir .= "/public-plugins/ensembl/htdocs/$species";
    utils::Tool::check_dir($dir);
  }
  my $file = $dir ."/index.html";
  if (-e $file) {
    utils::Tool::info (1, "File $file already exists. Copying old file to $file.old");
    system ("cp $file $file.old");
    #return;
  }
  open (my $fh, ">$file") or die "Cannot create $file: $!";

  # check for chromosomes
  my $explore = 'examples';
  if ( (scalar @$chrs) > 0 ) {
    $explore = 'karyomap';
    SSIkaryomap("$dir/ssi", $species, $common_name, $dir) unless -e "$dir/$species/ssi/karyomap.html";
  }

  # check for extra links
  my $exists_file = $dir."/ssi/links.html";
  my $extra_links = (-e $exists_file) ? qq([[INCLUDE::/$species/ssi/links.html]]):"";

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

    <div class="col2">
    [[INCLUDE::/$species/ssi/about.html]]
    </div>
</div>

);

print $fh qq(
<div class="col-wrapper">
    <div class="col2">
    [[INCLUDE::/$species/ssi/whatsnew.html]]
    </div>

    <div class="col2">
    [[INCLUDE::/$species/ssi/stats.html]]
    $extra_links
 </div>
</div>
) unless $site_type eq 'pre';

print $fh qq(
</body>
</html>
  );
  utils::Tool::info (1, "Created a generic $species homepage: $file");
  return;
}

##############################################################################
sub SSI {
  my ($dir, $common_name, $species, $chrs) = @_;
  my $ssi_dir = $dir;

  if ($site_type eq 'pre') {
    $ssi_dir .= "/sanger-plugins/pre/htdocs/$species/ssi";
  }
  else {
    $ssi_dir .= "/public-plugins/ensembl/htdocs/$species/ssi";
  }
  utils::Tool::check_dir($ssi_dir);
  &SSIabout($ssi_dir, $common_name, $species);

  if ( (scalar @$chrs) > 0 ) {
    &SSIentry($ssi_dir, $species, $chrs);
    &SSIkaryomap($ssi_dir, $species, $common_name, $dir);
  }
  else {
    &SSIexamples($ssi_dir, $species);
    &SSIentry($ssi_dir, $species, 0);
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
  utils::Tool::info (1, "Template for species entry page $file");
  return;
}

#------------------------------------------------------------------------------
sub SSIabout {
  my ($dir, $common_name, $species) = @_;
  my $file = $dir ."/about.html";
  return if -e $file;
  open (my $fh, ">$file") or die "Cannot create $file: $!";
  (my $nice_species = $species) =~ s/_/ /;

  print $fh qq(
  <h3 class="boxed">About the <i>$nice_species</i> genome</h3>

<h4>Assembly</h4>

<p><img src="/img/species/pic_$species.png" height="100" width="100" class="float-left" alt="$common_name" title="" />

</p>

<h4>Annotation</h4>
<p>

</p>

<h4>Full gene build</h4>
<p>The release date for a full Ensembl gene build on this assembly is estimated for [DATE!!!].  The gene build for <i>$nice_species</i> [VERSION!!!!] is available on the main <a href="http://www.ensembl.org/$species">Ensembl <i>$nice_species</i></a> site.</p>
);
  utils::Tool::info (1, "Template for about page $file");
  return;
}

#------------------------------------------------------------------------------

sub SSIexamples {
  my ($dir, $species) = @_;
  my $entry = $dir ."/examples.html";
  return if -e $entry;
  open (my $fh2, ">$entry") or die "Cannot create $entry: $!";
  (my $nice_species = $species) =~ s/_/ /;
  print $fh2 qq(
<h3 class="boxed">Example Data Points</h3>

<p>
This release of <i>$nice_species</i> data is assembled into scaffolds, so there are no chromosomes available to browse.
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
  utils::Tool::info (1, "Template for example page $entry ");
  return;
}
#---------------------------------------------------------------------------

sub SSIkaryomap {
  my ( $ssi_dir, $species, $common_name, $dir ) = @_;
  my $karyomap = $ssi_dir ."/karyomap.html";
  return if -e $karyomap;

  utils::Tool::info (1, "Template for karyomap page $karyomap");

  if ( $site_type eq 'pre' ) { # check to see if already karyotype for this sp
    my $exists_karyomap = "$dir/public-plugins/ensembl/htdocs/$species/ssi/karyomap.html";
    if ( -e $exists_karyomap ) {
      utils::Tool::info (1, "Copying existing karyomap from public-plugins file");
      system ("cp $dir/public-plugins/ensembl/htdocs/img/species/karyotype_$species.png $dir/sanger-plugins/pre/htdocs/img/species/");
      system ("cp $exists_karyomap $karyomap");
      return;
    }
    else {
      utils::Tool::warning (1, "Need to create a karyomap for the karyotype image");
    }
  }
  open (my $fh2, ">$karyomap") or die "Cannot create $karyomap: $!";
  print $fh2 qq(
<h3 class="boxed">Karyotype</h3>

<p>Click on a chromosome for a closer view</p>

<img src="/img/species/karyotype_$species.png" width="245" height="355" usemap="#karyotypes" alt="$common_name karyotype selector" />
);
  return;
}

#############################################################################
sub downloads {
  my $dir = shift;
  my $version = shift;
  return if $site_type eq 'pre';
  do_downloads("$dir/sanger-plugins/archive", $version, "archive");
  do_downloads("$dir/sanger-plugins/pre", $version);
  do_downloads("$dir", $version, 0);
  return;
}
#----------------------------------------------------------------------------
sub do_downloads {
  my $dir     = shift;
  my $version = shift;
  my $archive = shift;
  utils::Tool::check_dir($dir);
  $dir .= "/htdocs/info/data";
  utils::Tool::check_dir($dir);

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
    my $sp_release = utils::Tool::get_config( { species=>$spp, values => "SPECIES_RELEASE_VERSION" });
    $sp_release =~ s/\.//g;
    my $sp_dir = join "_", ( lc($spp), $version, $sp_release);
    my $description = utils::Tool::get_config({species =>$spp, values => "SPECIES_DESCRIPTION" });   

    my $url = $archive ? "release-$version/".$sp_dir : "current_".lc($spp);
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
  utils::Tool::info (1, "Created downloads pages $dir ");
  return;
}

#---------------------------------------------------------------------------
sub blast_db {
  my ($serverroot, $spp) = @_;
  utils::Tool::info(1, "Updating BLAST_DATASOURCES");
  my $location =  $site_type eq 'live' ? "/sanger-plugins/sanger/" : "/public-plugins/ensembl/";
  my $spp_type = $spp eq 'Multi' ? 'MULTI' : $spp;
  my $ini_file = sprintf ("$SERVERROOT/%s./conf/ini-files/%s.ini", $location, $spp_type);

  open (INI, "<",$ini_file) or die "Couldn't open ini file $ini_file: $!";
  my $contents = [<INI>];
  close INI;

  my $out_ini = $ini_file . ".out";
  open (my $fh_out, ">",$out_ini) or die "Couldn't open ini file $out_ini: $!";

  my $month = utils::Tool::release_month();
  my $golden_path = utils::Tool::get_config( {species => $spp, values => "ENSEMBL_GOLDEN_PATH"});

  # Continue until blast databases section
  utils::Tool::print_next($contents, "BLAST\\w_DATASOURCES\\]", $fh_out) ;

  foreach my $line (@$contents) {
    if ($line =~ /
		  ([^\#].*\w+)        # source
		  (\s+=        # whitespace =
		  \s+)
		  $spp\.\d*\.*  # species. (optional number .)
		  (\w+\.?\d?)\. # golden_path
		  \w{3}\.       # month
		  (.*)/x ) {   # type of file
     my $source = $1;
     my $new_file =  $1.$2.$spp. ".$golden_path.$month.$4";
     die "False positive in pattern match (source:$source): $line" unless $source =~ /^CDNA|^PEP|^RNA|^LATE/;
     print $fh_out "$new_file\n";
    }
    else {
      print $fh_out $line;
    }
  }
  system ("mv $ini_file $ini_file.bck") && die "Couldn't backup original file";
  system ("mv $out_ini $ini_file") && die "Couldn't move new file to $ini_file";
  return 1;
}

##############################--  ARCHIVE --################################

sub assembly_table {
  my ( $dir ) = @_;
  utils::Tool::check_dir($dir);

  # Connect to web database and get news adaptor
  my $web_db = $SD->databases->{'ENSEMBL_WEBSITE'};
  utils::Tool::warning (1, "ENSEMBL_WEBSITE not defined in INI file") unless $web_db;
  my $wa = EnsEMBL::Web::DBSQL::NewsAdaptor->new($web_db);

  my $file  = $dir."/assembly_table.inc";
  my $this_release = $SD->ENSEMBL_VERSION;

  my $header_row = qq(<th>Species</th>\n);
  my %info;

  foreach my $data ( @{$wa->fetch_releases()} ) {
    my $release_id = $data->{release_id};
    last if $release_id == ($FIRST_ARCHIVE - 1 );
   (my $link = $data->{short_date}) =~ s/\s+//;

    $header_row .=qq(<th><a href="http://$link.archive.ensembl.org">$data->{short_date}</a><br />v$release_id</th>);


    # If the assembly name spans several releases,%info stores its first release only
    # %info{species}{assembly name} = release num

    foreach my $assembly_info ( @{ $wa->fetch_assemblies($release_id)  }  ) {
      $info{ $assembly_info->{species} }{ $assembly_info->{assembly_name} } = $release_id;
    }
  }

  my $table;
  foreach my $species (sort keys %info) {
    my @tint = qw(class="bg4" class="bg2");
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
  print $fh qq(\n<table style="margin:auto; width:95%" border="1" class="spreadsheet">\n<tr>$header_row</tr>\n);
  print $fh qq($table</table>\n);
  return;
}


#---------------------------------------------------------------------
sub copy_species_table {
  my ( $dir ) = @_;
  my $dir2 = $dir."/sanger-plugins/archive/htdocs/ssi/";
  utils::Tool::check_dir($dir2);
  system("cp $dir/public-plugins/ensembl/htdocs/ssi/species_table.html $dir2");
  return;
}
#############################################################################



__END__

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

=head1 OPTIONS

More on --update: Valid options are:

B< new_species:>
   Use the -site_type 'pre' flag if you are setting up pre.

   Runs generic_species_homepage, SSI (SSIabout, SSIexample, SSIentry),
   downloads, species_table

B< archive: >
    Runs copy_species_table and assembly_table

B< release: >
    Runs blast_db

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
    Creates a homepage species table using sanger-plugins/sanger/utils/homepage.pl. Requires the release number for pre if this is different to the pre version.
    htdocs/ssi/species_table.html

B<  blast_db:>; 
    Updates public-plugins/ensembl/conf/ini-files so the blast
    database names match the month of release (default main site or use '--site_type main").  
    If flag "--site_type live" is used, it updates sanger-plugins/sanger/conf/ini-file files

B< copy_species_table:>
   simply copies: $SERVERROOT/public-plugins/ensembl/htdocs/ssi/species_table.html to $SERVERROOT/sanger-plugins/archive/htdocs/ssi/species_table.html

B< assembly_table>;
    Updates htdocs/Docs/archive/homepage_SSI/assembly_table.html or 
    creates new one.  This file is included in htdocs/Docs/assemblies.html 
    and lists all the archived sites and which assemblies they show.

B< branch_versions:>
   Creates a new page with updated versions for the current cvs branch
   (i.e. for the API, webcode etc)

B< gene_build:>
   Just checks the database meta table v.s. the ini file to see if the Genebuild date, assembly name and author match. Prints out warning message if these are out of sync.

    Maintained by Fiona Cunningham <fc1@sanger.ac.uk>

=cut

