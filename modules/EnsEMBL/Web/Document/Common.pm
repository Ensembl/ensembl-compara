package EnsEMBL::Web::Document::Common;

use strict;
use EnsEMBL::Web::Document::Page;

our @ISA = qw(EnsEMBL::Web::Document::Page);

sub set_title {
  my $self  = shift;
  my $title = shift;
  $self->title->set(
    $self->species_defs->ENSEMBL_SITE_NAME.' v'.
    $self->species_defs->ENSEMBL_VERSION.': '.
    $self->species_defs->SPECIES_BIO_NAME.' '.$title );
}

sub script_name {
  my( $self, $scriptname ) = @_;
  $scriptname ||= $ENV{'ENSEMBL_SCRIPT'};
  $scriptname = ucfirst( $scriptname );
  $scriptname =~ s/view/View/g;
  ## SequenceAlignView GeneSeqAlignView
  $scriptname =~ s/(align)/ucfirst($1)/eg;
  ## GeneSeqView AlignSliceView
  $scriptname =~ s/(slice)/ucfirst($1)/eg;
  ## SNPView GeneSNPView
  $scriptname =~ s/(snp)/uc($1)/ieg;
  ## LDView LDTableVies
  $scriptname =~ s/(Ld.|Id.)/uc($1)/eg;
  ## MultiContigView, GeneSpliceView
  $scriptname =~ s/(Gene|Multi|Transcript)(.)/$1.uc($2)/eg;
  return $scriptname;
}

sub _basic_HTML {
  my $self = shift;
## Main document attributes...

  $self->set_doc_type( 'XHTML', '1.0 Trans' );
# $self->set_doc_type( 'XHTML', '1.0 Strict' );
  $self->_init();
  $self->add_body_attr( 'id' => 'ensembl-webpage' );
  $self->body_javascript->add_source(  sprintf( '/%s/%s.js',  $self->species_defs->ENSEMBL_JSCSS_TYPE, $self->species_defs->ENSEMBL_JS_NAME ));
  $self->stylesheet->add_sheet( 'all', sprintf( '/%s/%s.css', $self->species_defs->ENSEMBL_JSCSS_TYPE, $self->species_defs->ENSEMBL_CSS_NAME ));
}
 
sub _common_HTML {
  my $self = shift;
## Main document attributes...
  $self->_basic_HTML;

  my $style = $self->species_defs->ENSEMBL_STYLE;
 
  if( $self->can('links') ) {
    $self->links->add_link({ 
      'rel'   => 'icon',
      'type'  => 'image/png',
      'href'  => $self->species_defs->ENSEMBL_IMAGE_ROOT.$style->{'SITE_ICON'}
    });
    $self->links->add_link({
      'rel'   => 'search',
      'type'  => 'application/opensearchdescription+xml',
      'href'  => $self->species_defs->ENSEMBL_BASE_URL.'/opensearchdescription.xml',
      'title' => 'Ensembl'
    });
    if( $ENV{'ENSEMBL_SPECIES'} ) {
      $self->links->add_link({
        'rel'   => 'search',
        'type'  => 'application/opensearchdescription+xml',
        'href'  => $self->species_defs->ENSEMBL_BASE_URL.'/opensearch_'.$ENV{'ENSEMBL_SPECIES'}.'.xml',
       'title' => 'Ensembl '.$self->species_defs->SPECIES_COMMON_NAME
      });
    }
    $self->links->add_link({
      'rel'   => 'alternate',
      'type'  => 'application/rss+xml',
      'href'  => '/common/rss.xml',
      'title' => 'Ensembl website news feed'
    });
  }
  $self->logo->image              = $style->{'SITE_LOGO'};             
  $self->logo->width              = $style->{'SITE_LOGO_WIDTH'};             
  $self->logo->height             = $style->{'SITE_LOGO_HEIGHT'};             
  $self->logo->alt                = $style->{'SITE_LOGO_ALT'};             
  $self->logo->href               = $style->{'SITE_LOGO_HREF'};             

  $self->tools->logins            = $self->species_defs->ENSEMBL_LOGINS;
  $self->tools->blast             = $self->species_defs->ENSEMBL_BLAST_ENABLED;
  $self->tools->biomart           = $self->species_defs->ENSEMBL_MART_ENABLED;
  if ($self->{'input'}) {
    $self->tools->referer           = $self->{'input'}->param('_referer');
   # warn "REFERER ".$self->{'input'}->param('_referer');
  }
  else {
    $self->tools->referer = undef;
  }
  $self->copyright->sitename     = $self->species_defs->ENSEMBL_SITETYPE;
}

sub _script_HTML {
  my( $self ) = @_;
  my $scriptname = $self->script_name;
#     $self->masthead->sub_title = $scriptname;
  #  --- And the title!
  $self->title->set( $scriptname );
}

sub wrap_ad {
  my ($self, $miniad) = @_;
  my $html = '';
                                                                                
  if( $miniad ) {
    my $image  = $$miniad{'image'};
    my $url    = $$miniad{'url'};
    my $alt    = $$miniad{'alt'};

    ## sanity check - does the image file exist?
    my $ad_dir = $self->species_defs->ENSEMBL_MINIAD_DIR;
    my $file = $ad_dir.$image;
    if (-e $file && -f $file) {
      $html = qq(\n<a href="$url"><img style="padding:15px 0px 0px 15px" src="/img/mini-ads/$image" alt="$alt" title="$alt" /></a>);
    }
  }
  return $html;
}


1;
