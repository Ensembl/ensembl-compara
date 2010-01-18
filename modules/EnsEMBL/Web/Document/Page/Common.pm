package EnsEMBL::Web::Document::Page::Common;

use strict;

use base qw(EnsEMBL::Web::Document::Page);

sub set_title {
  my $self  = shift;
  my $title = shift;
  return unless $self->can('title');
  return unless $self->title;
  $self->title->set(sprintf '%s %s: %s %s', $self->species_defs->ENSEMBL_SITE_NAME, $self->species_defs->ENSEMBL_VERSION, $self->species_defs->SPECIES_BIO_NAME, $title);
}

sub _basic_HTML {
  my $self = shift;
  
  $self->set_doc_type('XHTML', '1.0 Trans');
  $self->_init;
  $self->add_body_attr('id' => 'ensembl-webpage');
  
  if ($self->{'input'} && $self->{'input'}->param('debug') eq 'js') {
    foreach my $root (reverse @SiteDefs::ENSEMBL_HTDOCS_DIRS) {
      my $dir = "$root/components";

      if (-e $dir && -d $dir) {
        opendir DH, $dir;
        my @files = readdir DH;
        closedir DH;

        $self->body_javascript->add_source("/components/$_") for sort grep { /^\d/ && -f "$dir/$_" && /\.js$/ } @files;
      }
    }
  } else {
    $self->body_javascript->add_source(sprintf '/%s/%s.js', $self->species_defs->ENSEMBL_JSCSS_TYPE, $self->species_defs->ENSEMBL_JS_NAME)
  }

  $self->stylesheet->add_sheet('all', sprintf '/%s/%s.css', $self->species_defs->ENSEMBL_JSCSS_TYPE, $self->species_defs->ENSEMBL_CSS_NAME);
}
 
sub _common_HTML {
  my $self = shift;
  
  $self->_basic_HTML; # Main document attributes

  my $style = $self->species_defs->ENSEMBL_STYLE;
 
  if ($self->can('links')) {
    $self->links->add_link({ 
      rel  => 'icon',
      type => 'image/png',
      href => $self->species_defs->ENSEMBL_IMAGE_ROOT . $style->{'SITE_ICON'}
    });
    
    $self->links->add_link({
      rel   => 'search',
      type  => 'application/opensearchdescription+xml',
      href  => $self->species_defs->ENSEMBL_BASE_URL . '/opensearch/all.xml',
      title => $self->species_defs->ENSEMBL_SITE_NAME_SHORT . ' (All)'
    });
    
    if ($ENV{'ENSEMBL_SPECIES'}) {
      $self->links->add_link({
        rel   => 'search',
        type  => 'application/opensearchdescription+xml',
        href  => $self->species_defs->ENSEMBL_BASE_URL . "/opensearch/$ENV{'ENSEMBL_SPECIES'}.xml",
        title => sprintf('%s (%s)', $self->species_defs->ENSEMBL_SITE_NAME_SHORT, substr($self->species_defs->SPECIES_BIO_SHORT, 0, 5))
      });
    }
    
    $self->links->add_link({
      rel   => 'alternate',
      type  => 'application/rss+xml',
      href  => '/common/rss.xml',
      title => 'Ensembl website news feed'
    });
  }
  
  $self->logo->image         = $style->{'SITE_LOGO'};
  $self->logo->width         = $style->{'SITE_LOGO_WIDTH'};
  $self->logo->height        = $style->{'SITE_LOGO_HEIGHT'};
  $self->logo->alt           = $style->{'SITE_LOGO_ALT'};
  $self->logo->href          = $style->{'SITE_LOGO_HREF'};
  $self->logo->print_image   = $style->{'PRINT_LOGO'};
  
  $self->copyright->sitename = $self->species_defs->ENSEMBL_SITETYPE;
  
  if ($self->can('tools')) {
    $self->tools->logins      = $self->species_defs->ENSEMBL_LOGINS;
    $self->tools->blast       = $self->species_defs->ENSEMBL_BLAST_ENABLED;
    $self->tools->biomart     = $self->species_defs->ENSEMBL_MART_ENABLED;
    $self->tools->mirror_icon = $style->{'MIRROR_ICON'};
  }
  
  if ($self->{'input'}) {
    $self->content->filter_module = $self->{'input'}->param('filter_module');
    $self->content->filter_code   = $self->{'input'}->param('filter_code');
  } else {
    $self->content->filter_module = undef;
    $self->content->filter_code   = undef;
  }
}

1;
