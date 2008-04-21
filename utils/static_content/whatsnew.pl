#!/usr/local/bin/perl

#####################################################################################
# Utility script to create sitemaps from static content and sample links in ini files
#####################################################################################

use strict;
use warnings;
use Carp;
use Data::Dumper qw( Dumper );

use FindBin qw($Bin);
use File::Basename qw( dirname );

use Pod::Usage;
use Getopt::Long;

use EnsEMBL::Web::Data::NewsItem;

our $SERVERROOT;
my ( $help, $info, @species);

BEGIN{
  &GetOptions( 
	      'help'      => \$help,
	      'info'      => \$info,
	      'species=s' => \@species,
	     );
  
  pod2usage(-verbose => 2) if $info;
  pod2usage(1) if $help;
  
  $SERVERROOT = dirname( $Bin );
  $SERVERROOT =~ s#/utils##;
  unshift @INC, "$SERVERROOT/conf";
  eval{ require SiteDefs };
  if ($@){ die "Can't use SiteDefs.pm - $@\n"; }
  map{ unshift @INC, $_ } @SiteDefs::ENSEMBL_LIB_DIRS;
}

# get info about release and output message to user
our $output_root = '/public-plugins/ensembl/htdocs/';
my $release_id = $SiteDefs::VERSION;
print "Outputting Release $release_id What's New to $output_root\n\n";

# Connect to web database and get news adaptor
use EnsEMBL::Web::DBSQL::NewsAdaptor;
use EnsEMBL::Web::RegObj;

$ENSEMBL_WEB_REGISTRY = EnsEMBL::Web::Registry->new();
my $SD = $ENSEMBL_WEB_REGISTRY->species_defs;
my $wa = $ENSEMBL_WEB_REGISTRY->newsAdaptor;


#---------------- DO APPROPRIATE QUERIES AND OUTPUT NEWS FILE ----------------#

# general query - will probably need it at least once

# get a list of valid species for this release
our $rel_spp = $wa->fetch_species($release_id);
# reverse it so we can look up species ID by name
our %rev_hash = reverse %$rel_spp;

# check validity of user-provided species
my @valid_spp;
if (@species && $species[0] ne 'none') {
  foreach my $sp (@species) {
    if ($rev_hash{$sp}) {
      push (@valid_spp, $sp);
    }
    else {
      carp "Species $sp is not listed in the news database for release $release_id - omitting!\n";
    }
  }
}
elsif (!@species) { ## defaults to all
  foreach my $sp (values %$rel_spp) {
    push (@valid_spp, $sp);
  }
}

my ($output_dir, $html, $title, $extra);

#### NEWS FOR INDIVIDUAL SPECIES ####
foreach my $sp (@valid_spp) {

        (my $pretty_sp = $sp) =~ s/_/ /;
                                                                                
        $html = qq(<h3 class="boxed">What's New in Ensembl $release_id</h3>\n);
        
        # get stories for this species
        my $species_id = $rev_hash{$sp};
        my @stories = EnsEMBL::Web::Data::NewsItem->search(
          {
            release => $release_id,
            status  => 'news_ok',
            species.species_id => {-or => [ {IS => 'NULL'}, $species_id ]},
          },
          {
            order_by => 'species_id, priority',
            rows     => 5,
          }
        );

        $html .= qq(<h4><i>$pretty_sp</i> News</h4>);

        if (@stories) {
          ## output species stories
          $html .= qq(<ul class="spaced">\n);
          $html .= &output_stories(\@stories, 'species');
          $html .= qq(</ul>);
        } else {
          $html .= qq(<p>There is no <i>$pretty_sp</i>-specific news this release.</p>\n\n);
        }
    
        print STDERR "\nINFO: Adding $total species stories for $sp\n";

        ## finish file and write it out
        $html .= qq(<p><a href="/$sp/newsview?rel=$release_id">More news...</a></p>\n\n);
        $output_dir =  $output_root.$sp.'/ssi/';
        &check_dir($output_dir);
        &output_news_file($output_dir, $html);
    }

}

#--------------------------------------------------------

sub output_stories {
    my ($stories, $style, $limit) = @_;

    my $html;
    my $prev_cat = 0;
    my $prev_sp = 0;

    foreach my $story (@$stories) {

        my $item_id = $story->id;
        my $title      = $story->title;
        my $content    = $story->content;
        my $release_id = $story->release_id;
        my @species    = $story->species;

        my $sp_dir = @species ? $species[0]->name : 'Multi';


        # truncate content if story is over nnn chars
        if ($style && $style eq 'species' && length($content) > 250) {
            my @story_lines = split(/[.:][ <]/, $content);
            $content = $story_lines[0];
            ## strip out list tags as they break the XHTML
            $content =~ s/(ul|ol|dl)>/div>/g;
            $content =~ s/(li|dt|dd)>/p>/g;
            $content .= qq(.<br /><a href="/$sp_dir/newsview?rel=$release_id#item$item_id">Read more</a>...\n);
        }

        $html .= qq(<li><strong>$title</strong><br />$content</li>\n);
    }
    return $html;
}

sub check_dir {
  my $dir = shift;
  my $full_dir = $SERVERROOT.$dir;
  if( ! -e $full_dir ){
    print STDERR ("Creating $full_dir\n" );
    system("mkdir -p $full_dir") == 0 or
      ( warn( "Cannot create $full_dir: $!" ) && next );
  }
  return;
}

sub output_news_file {

    my ($output_dir, $html, $title) = @_;

    my $output_html = $output_dir."whatsnew.html";
    my $full_path   = $SERVERROOT.$output_html;

    open (NEWS,    ">$full_path") or croak "Cannot write $full_path: $!";

    print NEWS $html;

    print STDERR "INFO: Writing news file \'$output_html\'\n";

    close(NEWS);
}


=head1 NAME

whatsnew.pl

=head1 SYNOPSIS

whatsnew.pl [options]

Options:
  --help, --info, --species

B<-h,--help>
  Prints a brief help message and exits.

B<-i,--info>
  Prints man page and exits.

B<-s, --species>
  Species to dump. If none, outputs general news pages only; if option passed
  is 'all', outputs pages for each configured species + general pages.


=head1 DESCRIPTION

B<This program:>

Creates a news section using data stored in an Ensembl database. 

The database location is specified in Ensembl web config file:
  ../conf/ini-files/DEFAULTS.ini

The news items are written as html to files:
  ../htdocs/ssi/whatsnew.html               - selection of headlines for home page
  ../htdocs/<SPECIES>/ssi/whatsnew.html     - selection of headlines for species home

Written by Anne Parker <ap5@sanger.ac.uk>

=cut
