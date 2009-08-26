#!/usr/local/bin/perl 

## Script to output "psychic search" inserts for all species' home pages

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
  $SERVERROOT = dirname( $Bin );
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

require EnsEMBL::Web::SpeciesDefs;                  # Loaded at run time
my $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new;
$SPECIES_DEFS || pod2usage("$0: SpeciesDefs config not found");
my @species_inconf = @{$SiteDefs::ENSEMBL_DATASETS};

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
my $outdir = "/$SERVERROOT";
if ( $site_type eq 'pre') {
  $outdir .= "/sanger-plugins/pre/htdocs/";
 }
elsif ( $site_type eq 'mirror') {
  $outdir .= $mirror ? $mirror : 'public-plugins/mirror';
  $outdir .= '/htdocs/';
}
else {
  $outdir .= "/public-plugins/ensembl/htdocs/";
}

foreach my $spp (@species) {

    my $spdir = $outdir.'/'.$spp.'/ssi';

    if( ! -e $spdir ){
      warn "[INFO]: Creating species directory $spdir\n";
      eval { mkpath($spdir) };
      if ($@) {
        print "Couldn't create $spdir: $@";
      }
    }
    open SEARCH, ">$spdir/search.html";

    # Output page
    (my $spp_text = $spp) =~ s/_/ /;

    ## Get examples
    my @egs;

    my $chr_ref = $SPECIES_DEFS->get_config($spp, 'ENSEMBL_CHROMOSOMES') || [];
    my @chrs = @$chr_ref;
    if ($#chrs > 0) {
      srand;
      my $rand = int(rand($#chrs));
      my $chr1 = $chrs[$rand];
      $rand = int(rand($#chrs));
      my $chr2 = $chrs[$rand];
      push @egs, "chromosome $chr1", "$chr2:10000..200000";
    }
    else {
    
      my $T = $SPECIES_DEFS->get_config($spp, 'SEARCH_LINKS') || {};
      ## Now grab the default search links for the species
      foreach my $K ( sort keys %$T ) {
        if( $K =~ /DEFAULT(\d)_URL/ ) {
          push @egs, $T->{"DEFAULT$1"."_TEXT"};
        }
      }
    }

    my %good_example = (
      'Homo_sapiens' => 'BRCA2',
      'Mus_musculus' => 'Cat',
      'Danio_rerio'  => 'dbx1a',
    );

    if (my $feature = $good_example{$spp}) {
      push @egs, $feature;
    }
    else {
      push @egs, 'Q59FM4.1';
    }

    # Start column #1
    print SEARCH qq(
<div class="boxed pale" style="margin:10px 25px 0px 7px">
<div style="margin:auto; text-align:center">
  <h3>Search Ensembl <i>$spp_text</i></h3>

  <form action="/default/psychic" method="get" style="font-size: 0.9em"><div>

    Search:
    <input name="query" size="50" value="" />
    <input type="hidden" name="species" value="$spp" />
    <input type="submit" value="Go" class="red-button" /></div>
<p>
);
    if (my $eg1 = $egs[0]) {
      print SEARCH "e.g. ";
      my @strings;
      foreach my $eg (@egs) {
        push @strings, "<strong>$eg</strong>";
      }
      print SEARCH join(' or ', @strings);
    }

    print SEARCH qq(</p>
    </form>

</div>
</div>

    );

    close SEARCH;
}

exit;
