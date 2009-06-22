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
  warn $sd->ENSEMBL_EXTERNAL_SEARCHABLE;
  my @allowed = @{$sd->ENSEMBL_EXTERNAL_SEARCHABLE||[]};

  my %ignore = qw(robots.txt 1 .cvsignore 1);
  if( -e "$root/.cvsignore" ) {
    open I, "$root/.cvsignore";
    while(<I>) {
      $ignore{$1}=1 if/(\S+)/;
    }
    close I;
  }
warn "------------------------------------------------------------------------------
 Placing .cvsignore and robots.txt into $root
------------------------------------------------------------------------------
";

  open O, ">$root/.cvsignore";
  print O join "\n", sort keys %ignore;
  close O;

  if( open FH, ">$root/robots.txt" ) {
## Allowed list is empty so we only allow access to the main
## index page... /index.html...

    if( @allowed ) {
      print FH qq(
User-agent: *
Disallow:   /Multi/
Disallow:   /BioMart/);
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
Disallow:   /
Allow:      /index.html);
    }
    print FH qq(

User-Agent: W3C-checklink
Disallow:
);
    close FH;
  } else {
    warn "Unable to creates robots.txt file in $root-robots";
  }
  return;
}

1;
