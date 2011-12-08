package EnsEMBL::Web::Tools::RobotsTxt;

use strict;

sub create {
  ### This is to try and stop search engines killing e! - it gets created each
  ### time on server startup and gets placed in the first directory in the htdocs
  ### tree.
  ### Returns: none
  my $species = shift;
  my $sd      = shift;
  my $root    = $sd->ENSEMBL_HTDOCS_DIRS->[0];
  my @allowed = @{$sd->ENSEMBL_EXTERNAL_SEARCHABLE||[]};
  
  #check if directory for creating .cvsignore and robots.txt exist
  my $root_exist = `ls $root 2>&1`;
  `mkdir -p $root` if($root_exist =~ /No such file or directory/);

  my %ignore = qw(robots.txt 1 .cvsignore 1);
  if( -e "$root/.cvsignore" ) {
    open I, "$root/.cvsignore";
    while(<I>) {
      $ignore{$1}=1 if/(\S+)/;
    }
    close I;
  }
warn "------------------------------------------------------------------------------
 Placing .cvsignore and robots.txt into  $root 
------------------------------------------------------------------------------
";

  open O, ">$root/.cvsignore";
  print O join "\n", sort keys %ignore;
  close O;

 #Create a different Robots.txt for google sitemap
  my $server_root = $sd->ENSEMBL_SERVERROOT;  
  my $sitemap = `ls $server_root/htdocs/sitemaps/sitemap-index.xml 2>&1`;  
  if($sitemap !~ /No such file or directory/)
  {
warn "---------------------------------------------------------------
  Creating robots.txt for google sitemap
---------------------------------------------------------------
";
    my @letters = ('A'..'Z');    
    open FH, ">$root/robots.txt";
    
    print FH qq(User-agent: *
Disallow: /Multi/
Disallow: /biomart/
Disallow: /Account/
Disallow: /ExternalData/
Disallow: /UserAnnotation/
Disallow: */Ajax/
Disallow: */Config/
Disallow: */blastview/
Disallow: */Export/
Disallow: */Experiment/
Disallow: */Location/
Disallow: */LRG/
Disallow: */Phenotype/
Disallow: */Regulation/
Disallow: */Search/
Disallow: */UserConfig/
Disallow: */UserData/
Disallow: */Variation/);

    foreach my $row(@letters){
      if($row ne 'S')
      {
        my $row_lowercase = lc($row);
        print FH qq(
Disallow:*/Gene/$row_lowercase*
Disallow:*/Gene/$row*
Disallow:*/Transcript/$row_lowercase*
Disallow:*/Transcript/$row*);      
      }
    }
    
    print FH qq(
Sitemap: http://www.ensembl.org/sitemap-index.xml);

    close FH;
  }
  elsif ( open FH, ">$root/robots.txt" ) {
## Allowed list is empty so we only allow access to the main
## index page... /index.html...

    if( @allowed ) {      
        print FH qq(
User-agent: *
Disallow:   /Multi/
Disallow:   /biomart/);
        foreach( @{$species||[]} ) {
          print FH qq(

Disallow:   /$_/);
          foreach my $view ( @allowed ) {
            print FH qq(
Allow:      /$_/$view);
          }
        }
    } else {
      print FH qq(
User-agent: *
Disallow:   /);
    }
    print FH qq(

User-Agent: W3C-checklink
Allow: /info

User-Agent: Sanger Search Bot/Nutch-1.1 (Nutch Spider; http://www.sanger.ac.uk; webmaster at sanger dot ac dot uk)
Allow: /info/*
Allow: /index.html

);
    close FH;
  } else {
    warn "\n*********************************** UNABLE TO CREATES ROBOTS.TXT FILE IN $root/ ****************************************************";
  }
  return;
}

1;
