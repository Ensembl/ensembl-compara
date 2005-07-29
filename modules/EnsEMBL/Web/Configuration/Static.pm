package EnsEMBL::Web::Configuration::Static;

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::SpeciesDefs;
                                                                                
our $SD = EnsEMBL::Web::SpeciesDefs->new();
our @ISA = qw( EnsEMBL::Web::Configuration );

sub links {
  my $self = shift;
  my $species = $ENV{'ENSEMBL_SPECIES'};
  my $species_2 = $species eq 'Multi' ? 'default' : $species;
  $self->add_block( 'whattodo', 'bulleted', 'Use Ensembl to...' );
 $self->add_entry( 'whattodo', 'href' => "/multi/blastview", 'text'=>'Run a BLAST search' );
  $self->add_entry( 'whattodo', 'href'=>"/default/textview", 'text'=>'Search Ensembl' );
  $self->add_entry( 'whattodo', 'href'=>"/multi/martview", 'text'=>'Data mining [BioMart]', 'icon' => '/img/biomarticon.gif' );
  $self->add_entry( 'whattodo', 'href'=>"javascript:void(window.open('/perl/helpview?se=1;kw=upload','helpview','width=700,height=550,resizable,scrollbars'))", 'text'=>'Upload your own data' );
  $self->add_entry( 'whattodo', 'href'=>"/info/data/download.html",
			'text' => 'Download data');
  $self->add_entry( 'whattodo', 'href'=>"/$species_2/exportview",
			'text' => 'Export data');

 # do species popups from config
 # $self->add_block( 'species', 'bulleted', 'Select a species' );
  my @group_order = ('Mammals', 'Chordates', 'Eukaryotes');
  my %spp_tree = ('Mammals'=>[{'label'=>'Mammals'}],
                  'Chordates'=>[{'label'=>'Other chordates'}],
                  'Eukaryotes'=>[{'label'=>'Other eukaryotes'}]
    );
  my @species_inconf = @{$SD->ENSEMBL_SPECIES};
  foreach my $sp (@species_inconf) {
    my $bio_name = $SD->other_species($sp, "SPECIES_BIO_NAME");
    my $group = $SD->other_species($sp, "SPECIES_GROUP");
    my $hash_ref = {'href'=>"/$sp/", 'text'=>"<i>$bio_name</i>", 'raw'=>1};
    push (@{$spp_tree{$group}}, $hash_ref);
  }
  foreach my $group (@group_order) {
    my $h_ref = shift(@{$spp_tree{$group}});
    my $text = $$h_ref{'label'};
    $self->add_entry('species', 'href'=>'/', 'text'=>$text, 'options'=>$spp_tree{$group});
  }

  $self->add_block( 'docs', 'bulleted', 'Docs and downloads' );
  $self->add_entry( 'docs', 'href' => '/info/', 
	'text' => 'Information',
        'title'=> 'Information homepage' );
  $self->add_entry( 'docs', 'href' => '/whatsnew.html', 
	'text' => "What's New",
        'title'=> 'Changes in Ensembl' );
  $self->add_entry( 'docs', 'href' => '/info/about/', 
	'text' => 'About Ensembl',
 	'title'=> 'Introduction, Goals, Commitments, Citing Ensembl, Archive sites' );
  $self->add_entry( 'docs', 'href' => '/info/data/', 
	'text' => 'Using Ensembl data',
	'title'=> 'Downloads, Data import/export, Data mining, Data searches' );
  $self->add_entry( 'docs', 'href' => '/info/software/', 
	'text' => 'Software',
	'title'=> 'API, Installation, Website, Versions, CVS' );
                                                                                
  $self->add_block( 'links', 'bulleted', 'Other links' );
  $self->add_entry( 'links', 'href' => '/', 'text' => 'Home' );
  my $map_link = '/sitemap.html';
  if (my $species = $ENV{'ENSEMBL_SPECIES'} && !$species =~ /multi/i) {
    $map_link = '/'.$species.$map_link;
  }
  $self->add_entry( 'links', 'href' => $map_link, 'text' => 'Sitemap' );
  $self->add_entry( 'links', 'href' => 'http://archive.ensembl.org', 'text' => "Archive! sites" );
  $self->add_entry( 'links', 'href' => 'http://vega.sanger.ac.uk/', 'text' => 'Vega', 'icon' => '/img/vegaicon.gif',
        'title' => "Vertebrate Genome Annotation" );
  $self->add_entry( 'links', 'href' => 'http://trace.ensembl.org/', 'text' => 'Trace server',
        'title' => "trace.ensembl.org - trace server" );

  if ($SD->ENSEMBL_SITE_NAME eq 'Ensembl') { # only want archive link on live Ensembl!
    my $URL = sprintf "http://%s.archive.ensembl.org%s",
             CGI::escapeHTML($SD->ARCHIVE_VERSION),
             CGI::escapeHTML($ENV{'REQUEST_URI'});
    $self->add_entry( 'links', 'href' => $URL, 'text' => "Stable (archive) link for this page" );
  }

}

1;
