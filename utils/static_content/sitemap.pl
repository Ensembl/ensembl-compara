#!/usr/local/bin/perl 

##############################################################################
#
#   SCRIPT TO GENERATE STATIC HTML SITEMAPS FOR ENSEMBL WEBSITES
#
##############################################################################

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
  $SERVERROOT =~ s#/utils##;
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

require EnsEMBL::Web::SpeciesDefs;                  # Loaded at run time
my $SPECIES_DEFS = EnsEMBL::Web::SpeciesDefs->new;
$SPECIES_DEFS || pod2usage("$0: SpeciesDefs config not found");
my @species_inconf = @{$SiteDefs::ENSEMBL_SPECIES};
warn "CONFIG: @species_inconf";

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

# General SiteMap HOME --------------------------------------------------------
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

my $top = $outdir.'sitemap.html';
open TOP, ">$top";

# Start page
my $html_header = do_header('Site Map', 'Ensembl Site Map');
 
print TOP $html_header;

# Begin species section
print TOP qq(
<table class="sitemap">
<tr>
<th colspan="2" style="width:66%">
<h3 class="boxed">Species Sub-sites</h3>
</th>
);

unless ($site_type eq 'pre') {
  print TOP qq(<th>
  <h3 class="boxed">Documentation</h3>
  </th>
  );
}

print TOP qq(</tr>
<tr>
<td style="width:33%">
<dl class="sitemap">
);

# loop through species in alphabetical order
my $sp_count = scalar(@species_inconf);
my $halfway = int($sp_count/2) + 1;

for (my $i = 0; $i < $sp_count; $i++) {
    my $spp_dir   = $species_inconf[$i];
    (my $spp_text = $spp_dir) =~ s/_/ /;

    if ($i == $halfway) {
      print TOP qq(</dl>
</td>
<td style="width:33%">
<dl class="sitemap">
);
    }

    my $spp_links = qq(
    <dt><img src="/img/species/thumb_$spp_dir.png" width="40" height="40" alt="$spp_text" style="float:left;padding-right:4px;" />$spp_text</dt>
    <dd><a href="/$spp_dir/">home page</a> | <a href="/$spp_dir/sitemap.html">site map</a></dd>);
    print TOP $spp_links;
}

# End species section
print TOP qq(
</dl>
</td>

);

unless ($site_type eq 'pre') {

  # Add static content sections
  print TOP qq(
  <td style="width:33%">


  <ul class="sitemap spaced">
  );

  # Go through info folder and pull out all document titles and URLs
  #my $tree = [];
  #read_web_tree($tree, 'info');
  print TOP write_web_tree($SPECIES_DEFS->ENSEMBL_WEB_TREE->{info});

  # End static section
  print TOP qq(
  </td>
  );
}

print TOP qq(</tr>
</table>
);

# End content
my $html_footer = do_footer();
print TOP $html_footer;

close TOP;
exit if $species[0] eq 'none';

## LIST DETAILS FOR ALL VIEWS

## NB: we have to create the multidimensional data structure *within* the
## species loop, otherwise when we delete a view for one species, it will
## remain deleted on subsequent iterations

## TO ADD A NEW VIEW:
## 1. Add an array of values in the format:
##    my @newview = ('newview', 'NewView', 'short description of my new view');
##
## 2. Add the name of your view to the appropriate section of %species_views
##    - see an existing site map for the full title of each section

#            ['alignview', 'AlignContigView', 'Compare sequences from any genomes'],
my @contigview      = ('contigview', 'ContigView', 'Small-scale Sequence display');
my @cytoview        = ('cytoview', 'CytoView', 'Large-scale Sequence display');
my @domainview      = ('domainview', 'DomainView', 'Protein Domain report');
my @exonview        = ('exonview', 'ExonView', 'Exon report');
my @familyview      = ('familyview', 'FamilyView', 'Protein Family report');
my @featureview     = ('featureview', 'FeatureView', 'Display Ensembl features (on a karyotype if available)');
my @geneview        = ('geneview', 'GeneView', 'Gene report');
my @geneseqview     = ('geneseqview', 'GeneSeqView', 'Displays the sequence section from GeneView');
my @geneseqalignview    = ('geneseqalignview', 'GeneSeqAlignView', 'Compare the DNA sequence of orthologues');
my @genesnpview     = ('genesnpview', 'GeneSNPView', 'Lists all SNPs for a gene');
my @genespliceview  = ('genespliceview', 'GeneSpliceView', 'Alternative splicing for a given gene');
my @generegulationview  = ('generegulationview', 'GeneRegulationView', 'Regulatory factors for a given gene');
my @genetreeview    = ('genetreeview', 'GeneTreeView', 'Tree of orthologues for a gene');
my @goview          = ('goview', 'GOView', 'Gene Ontology hierarchy');
my @historyview     = ('historyview', 'HistoryView', 'Convert a list of old Ensembl stable IDs');
my @idhistoryview   = ('idhistoryview', 'IDHistoryView', 'Track the history of an Ensembl stable ID');
my @karyoview       = ('karyoview', 'KaryoView', 'Map your own data onto a karyotype');
my @ldview          = ('ldview', 'LDView', 'Diagram of LD values for a SNP');
my @ldtableview     = ('ldtableview', 'LDTableView', 'Table of LD values for a SNP');
my @mapview         = ('mapview', 'MapView', 'Explore a chromosome');
my @markerview      = ('markerview', 'MarkerView', 'Information about a chromosome marker');
my @multicontigview = ('multicontigview', 'MultiContigView', 'Compare syntenous sequences (assembled genomes only) - accessible through SyntenyView');
my @protview        = ('protview', 'ProtView', 'Protein Report');
my @sequencealignview = ('sequencealignview', 'SequenceAlignView', 'Compare the DNA sequence between strains or individuals');
my @snpview         = ('snpview', 'SNPView', 'SNP report');
my @syntenyview     = ('syntenyview', 'SyntenyView', 'Compare syntenous regions');
my @transview       = ('transview', 'TransView', 'Transcript report');
my @transcriptsnpview = ('transcriptsnpview', 'TranscriptSNPView', "Compare a transcript's SNPs in individuals / strains / populations");
       
 
foreach my $spp (@species) {
    my %conf_views = %{$SPECIES_DEFS->get_config($spp, 'SEARCH_LINKS')};
    my %display_views = ();
    my $do_entries;

    my $spdir = $outdir.'/'.$spp;

    # rebuild view hierarchy each time
    my %species_views = (
        'gene'      => [\@geneview, \@geneseqview, \@genespliceview, \@generegulationview, \@exonview, \@transview, \@contigview, \@cytoview, \@markerview, \@goview],
        'compgen'   => [\@syntenyview, \@multicontigview, \@sequencealignview, \@genetreeview, \@geneseqalignview],
        'protein'   => [\@protview, \@domainview, \@familyview],
        'variation' => [\@genesnpview, \@transcriptsnpview, \@snpview, \@ldview, \@ldtableview],
        'find'      => [\@mapview, \@idhistoryview, \@historyview],
        'karyotype' => [\@featureview, \@karyoview],
        );

    # Clean up configured views
    foreach my $view (keys %conf_views) {
        if (($view =~ /^DEFAULT/) or ($view =~ /_TEXT\w*$/)or($view =~/2_URL$/)){
            delete($conf_views{$view});
            next;
        }
        (my $key = $view) =~ s/\d*_URL//;
        $key = lc($key);
        $display_views{$key} = "/$spp/".$conf_views{$view};
    }

    # loop through all possible views
    foreach my $group (keys %species_views) {

        my $array_ref = $species_views{$group};
        for (my $i = 0; $i < scalar(@$array_ref); $i++) {
            my @subarray = @{$$array_ref[$i]};
            my $script_name = $subarray[0];
            my $view_name = $subarray[1];
            # delete absent views
            if (!$display_views{$script_name}) {
                splice(@{$species_views{$group}}, $i, 1);
                $i--; # have to reset the index after removing an element
            }
        }

    }

    if( ! -e $spdir ){
      warn "[INFO]: Creating species directory $spdir\n";
      eval { mkpath($spdir) };
      if ($@) {
        print "Couldn't create $spdir: $@";
      }
    }
    open SUBMAP, ">$spdir/sitemap.html";

    # Output page
    (my $spp_text = $spp) =~ s/_/ /;

    # Start page 
    my $html_header = do_header("$spp_text site map", "<i>$spp_text</i> site map");

    my $entries;
 
    print SUBMAP $html_header;

    # Start column #1
    print SUBMAP qq(
    <div class="col-wrapper">
    <div class="col3">
    );

    # Search options
    $entries = do_entries('Find a sequence or feature', 'find', \%species_views, \%display_views);
    print SUBMAP $entries;

    # Sequence data
    $entries = do_entries('Genes and Sequences', 'gene', \%species_views, \%display_views);
    print SUBMAP $entries;
    
    # End column #1 and start column #2
    print SUBMAP qq(</div>

    <div class="col3">
    );
    
    # Import/export links
    
    print SUBMAP qq(

    <h3 class="boxed">Import/Export data</h3>
    
    <dl class="species-map">
<dt><a href="/info/using/external_data/index.html">DAS</a> (Distributed Annotation Server)</dt>

    <dd>Import your data into Ensembl</dd>
    <dt><a href="/$spp/exportview">ExportView</a></dt>
    <dd>Export sequence data to file</dd>
    </dl>
    );

    # Proteins
    $entries = do_entries('Proteins', 'protein', \%species_views, \%display_views);
    print SUBMAP $entries;

    # Karyotypes
    $entries = do_entries('Feature displays', 'karyotype', \%species_views, \%display_views);
    print SUBMAP $entries;

    # End column #2 and start column #3
    print SUBMAP qq(</div>

    <div class="col3">
    );

    # Variation
    $entries = do_entries('Variation', 'variation', \%species_views, \%display_views);
    print SUBMAP $entries;

    # Comparative genomics
    $entries = do_entries('Comparative genomics', 'compgen', \%species_views, \%display_views);
    print SUBMAP $entries;

    # End column #3
    print SUBMAP "</div>\n\n";

    # End content
    print SUBMAP qq(
    </div>
    );

    my $html_footer = do_footer();

    print SUBMAP $html_footer;

    close SUBMAP;
}

#---------------------------------------------------------------------------

sub do_entries {

    my ($title, $group, $s_ref, $d_ref) = @_;
    my %s_views = %$s_ref;
    my %d_views = %$d_ref;

    my $ref = $s_views{$group};    
    my @inc_views = @$ref;

    my $html = '';

    if (scalar(@inc_views) > 0) { # only output section if we have entries!
        $html .= qq(
            <h3 class="boxed">$title</h3>
        
            <dl class="species-map">
            );

        foreach my $key (@inc_views) {
            my @view_array = @$key;
            my $script_name = $view_array[0];
            my $view_name = $view_array[1];
            my $view_text = $view_array[2];
            my $url = $d_views{$script_name};
            my $view_title;

            if ($url) {
                $view_title = qq(<a href="$url">$view_name</a>);
            }
            else {
                $view_title = "$view_name";
            }
            $html .= qq(<dt>$view_title</dt>
                <dd>$view_text</dd>
                );
        }
        $html .= "</dl>\n";
    }
    return $html;

}

sub do_header {
    my ($title, $h1) = @_;

    my $html = qq(<html>
<head>
<title>$title</title>
</head>

<body>

<h2>$h1</h2>
);

    return $html;

}

sub do_footer {

    my $html = qq(

</body>
</html>
);

    return $html;

}

#--------------------------------------------------------------------------

# Outputs the info tree structure as a nested bulleted list

# N.B. The initial <ul> and </ul> should be generated outside this
# recursive function so that the nesting works properly!

sub write_web_tree {
  my ($node, $level) = @_;
  my $html = '';
  $level = 0 unless $level;
  
  my $section_url   = $node->{_path};
  my $section_title = $node->{_title};
  my @pages = grep { /\.html/ } keys %$node;
  my @dirs  = grep { $_ !~ /(:?\.html|^_)/ } keys %$node;

  if ($section_url && $section_title) {
    ## Do home page for this section
    $id_count++;
    my ($image, $display);
    if ($level > 0) {
      if ($level > 1) { ## hide lower levels
        $image = 'plus.gif';
        $display = 'none';
      } else {
        $image = 'minus.gif';
        $display = 'block';
      }
      if (@pages || @dirs) { ## directory contains HTML pages and/or subdirectories
        $html .= qq(<li class="toggle"><strong><img src="/img/$image" width="11" height="11" alt="toggle" id="im_$id_count" class="toggle-box" onclick="javascript:exp_coll($id_count);" /><a href="$section_url">$section_title</a></strong>\n<ul id="sp_$id_count" style="display:$display;">\n);
      } else { ## directory contains only an index page
        $html .= qq(<li><a href="$section_url">$section_title</a></li>\n);
      }
    }

    ## Do other pages
    foreach my $page (sort { $node->{$a}->{_title} cmp $node->{$b}->{_title} } @pages) {
      my $url   = $node->{_path} . $page;
      my $title = $node->{$page}->{_title};
      $html .= qq(<li><a href="$url">$title</a></li>\n)
        if $url && $title;
    }
  
    ## Do sub directories
    $html .= write_web_tree($node->{$_}, $level + 1)
      for (sort { $node->{$a} cmp $node->{$b} } @dirs);
  
    $html .= qq(\n</ul>)
      if @pages || @dirs;
  }

  return $html;
}

# Does a case-insensitive sort of a list of file names
# and separates them into two lists - directories and non-directories

sub sortnames {
    my @namelist = @_;
    my @sorted = sort {lc $a cmp lc $b} @namelist;

    my (@file_list, @dir_list);
   
    foreach my $item (@sorted) {
        if (-d $item) {
            push (@dir_list, $item);
        }
        else {
            push (@file_list, $item);
        }
    }

    return (\@file_list, \@dir_list);
}

# Parses an HTML file and returns the contents of the <title> tag

sub get_title {

    my $file = shift;
    my $title;

    open IN, "< $file" or die "Couldn't open input file $file :(\n";
    while (<IN>) {
        if (/<title/) {
            $title = $_;
            chomp($title);
            $title =~ s/^(\s+)//;
            $title =~ s/(\s+)$//;
            $title =~ s/<title>//;
            $title =~ s/<\/title>//;
            last;
        }
    }
    return $title;
}

__END__

=head1 NAME

sitemap.pl

=head1 SYNOPSIS

sitemap.pl  [options]

Using the default settings or information given when the script is run, this 
program creates an html sitemap file.

Options:
   --help --species <species_name>

B<-h,--help>
   Prints a brief help message and exits.

B<--species>
   Optional: if no species is specified, all species will be done

 B<--site_type>
    Defaults to main.  Use 'pre' for the pre Ensembl site

=head1 DESCRIPTION

B<This program:>
Creates the site map for EnsEMBL
Maintained by Fiona Cunningham <fc1@sanger.ac.uk>
and Anne Parker (ap5@sanger.ac.uk)

=cut
