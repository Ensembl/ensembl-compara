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
  if ($SD->ENSEMBL_SITETYPE ne 'Archive EnsEMBL') {
    $self->add_entry( 'whattodo', 'href' => "/multi/blastview", 'text'=>'Run a BLAST search' );
  }
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
		    'icon' => '/img/infoicon.gif', 
		    'title'=> 'Information homepage' );
  $self->add_entry( 'docs', 'href' => '/whatsnew.html', 
	'text' => "What's New",
		    'icon' => '/img/infoicon.gif', 
        'title'=> 'Changes in Ensembl' );
  $self->add_entry( 'docs', 'href' => '/info/about/', 
		    'icon' => '/img/infoicon.gif', 
		    'text' => 'About Ensembl',
		    'title'=> 'Introduction, Goals, Commitments, Citing Ensembl, Archive sites' );
  $self->add_entry( 'docs', 'href' => '/info/data/', 
		    'text' => 'Using Ensembl data',
		    'icon' => '/img/infoicon.gif', 
		    'title'=> 'Downloads, Data import/export, Data mining, Data searches' );
  $self->add_entry( 'docs', 'href' => '/info/software/', 
		    'text' => 'Software',
		    'icon' => '/img/infoicon.gif', 
		    'title'=> 'API, Installation, Website, Versions, CVS' );
                                                                                
  $self->add_block( 'links', 'bulleted', 'Other links' );
  $self->add_entry( 'links', 'href' => '/', 'text' => 'Home' );
  my $map_link = '/sitemap.html';
  if (my $species = $ENV{'ENSEMBL_SPECIES'} && !$species =~ /multi/i) {
    $map_link = '/'.$species.$map_link;
  }
  $self->add_entry( 'links', 'href' => $map_link, 'text' => 'Sitemap' );
  $self->menu->add_entry( 'links', 
			  'href' => 'http://pre.ensembl.org/', 
			  'text' => 'Pre! Ensembl', 
			  'icon' => '/img/ensemblicon.gif', 
	'title' => "Ensembl Pre! sites (species in progress)" )

  $self->add_entry( 'links', 'href' => 'http://vega.sanger.ac.uk/', 'text' => 'Vega', 'icon' => '/img/vegaicon.gif',
        'title' => "Vertebrate Genome Annotation" );
  $self->add_entry( 'links', 'href' => 'http://archive.ensembl.org', 'text' => "Archive! sites" );
  $self->add_entry( 'links', 'href' => 'http://trace.ensembl.org/', 'text' => 'Trace server',
        'title' => "trace.ensembl.org - trace server" );

  if ($SD->ENSEMBL_SITETYPE eq 'EnsEMBL') { # only want archive link on e!
    my $URL = sprintf "http://%s.archive.ensembl.org%s",
      CGI::escapeHTML($SD->ARCHIVE_VERSION),
	  CGI::escapeHTML($ENV{'REQUEST_URI'});
    $self->add_entry( 'links', 
		      'href' => $URL, 
		      'text' => "Stable (archive) link for this page" );
  }
  elsif ($SD->ENSEMBL_SITETYPE eq 'Archive EnsEMBL') {
    $self->add_entry( 'links', 
		      'icon' => '/img/ensemblicon.gif', 
		      'href' => "http://www.ensembl.org", 
		      'text' => "Ensembl" );
    my $URL = sprintf "http://www.ensembl.org%s",
      CGI::escapeHTML($ENV{'REQUEST_URI'});
    $self->add_entry( 'links', 
		      'href' => $URL, 
		      'icon' => '/img/ensemblicon.gif', 
		      'title'=> "Link to newest Ensembl data",
			    'text' => 'View page in current e! release' );
  }
  else {
    $self->add_entry( 'links', 
		      'href' => "http://www.ensembl.org", 
		      'icon' => '/img/ensemblicon.gif', 
		      'text' => "Ensembl" );
  
    $self->add_entry ('links', 
		      'href' => "/info/about/ensembl_powered.html", 
		      'icon' => '/img/ensemblicon.gif', 
		      'text'=>'Ensembl Empowered');
  }
}

1;
