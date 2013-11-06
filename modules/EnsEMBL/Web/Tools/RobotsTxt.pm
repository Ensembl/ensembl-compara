package EnsEMBL::Web::Tools::RobotsTxt;

use strict;

use File::Path qw(make_path);

sub _lines { # utility
  my $type = shift;
  my $lines = join("\n",map { "$type: $_" } @_);
  return sprintf("%s%s\n",($type eq 'User-agent')?"\n":'',$lines);
}

sub _box {
  my $text = shift;
  return join("\n",'-' x length $text,$text,'-' x length $text,'');
}

sub create {
  ### This is to try and stop search engines killing e! - it gets created each
  ### time on server startup and gets placed in the first directory in the htdocs
  ### tree.
  ### Returns: none
  my $species = shift;
  my $sd      = shift;
  my $root    = $sd->ENSEMBL_SERVERROOT . '/htdocs';
  my @allowed = @{$sd->ENSEMBL_EXTERNAL_SEARCHABLE||[]};

  #check if directory for creating .cvsignore and robots.txt exist
  make_path($root) unless(-e $root);

  my %ignore = qw(robots.txt 1 .cvsignore 1);
  if( -e "$root/.cvsignore" ) {
    open I, "$root/.cvsignore";
    while(<I>) {
      $ignore{$1}=1 if/(\S+)/;
    }
    close I;
  }
  warn _box("Placing .cvsignore and robots.txt into $root");

  open O, ">$root/.cvsignore";
  print O join "\n", sort keys %ignore;
  close O;

  my $server_root = $sd->ENSEMBL_SERVERROOT;
  unless(open FH, ">$root/robots.txt") {
    warn _box("UNABLE TO CREATE ROBOTS.TXT FILE IN $root/");
    return;
  }

  print FH _lines("User-agent","*");
  print FH _lines("Disallow",qw(
				 /Multi/  /biomart/  /Account/  /ExternalData/  /UserAnnotation/
				 */Ajax/  */Config/  */blastview/  */Export/  */Experiment/ */Experiment*
				 */Location/  */LRG/  */Phenotype/  */Regulation/  */Search/ */Share
				 */UserConfig/  */UserData/  */Variation/
			      ));

  #old views
  print FH _lines("Disallow",qw(*/*view));

  #other misc views google bot hits
  print FH _lines("Disallow",qw(/id/));
  print FH _lines("Disallow",qw(/*/psychic));

  foreach my $row (('A'..'Z','a'..'z')){
    next if lc $row eq 's';
    print FH _lines("Disallow","*/Gene/$row*","*/Transcript/$row*");
  }

  # a bunch of others that are being bypassed
  foreach my $row (qw(SpeciesTree Similarity SupportingEvidence Sequence_Protein Sequence_cDNA Sequence StructuralVariation_Gene Splice)) {
    print FH _lines("Disallow","*/Gene/$row*","*/Transcript/$row*");
  }

  # links from ChEMBL
  print FH _lines("Disallow","/Gene/Summary");
  print FH _lines("Disallow"," /Transcript/Summary");

  # Doxygen
  print FH _lines("Disallow","/info/docs/Doxygen");

  if (-e "$server_root/htdocs/sitemaps/sitemap-index.xml") {
    print FH _lines("Sitemap","http://www.ensembl.org/sitemap-index.xml");
  }

  print FH _lines("User-agent","W3C-checklink");
  print FH _lines("Allow","/info");

  # Limit Blekkobot's crawl rate to only one page every 20 seconds.
  print FH _lines("User-agent","Blekkobot");
  print FH _lines("Crawl-delay","20");

  # stop AhrefsBot indexing us (https://ahrefs.com/robot/)
  print FH _lines("User-agent","AhrefsBot");
  print FH _lines("Disallow","/");

  if(-e "$server_root/htdocs/sitemaps/sitemap-index.xml") {
    # If we have a sitemap let google know about it.
    warn _box("Creating robots.txt for google sitemap");
    print FH _lines("Sitemap","http://www.ensembl.org/sitemap-index.xml");
  }

  close FH;
  return;
}

1;
