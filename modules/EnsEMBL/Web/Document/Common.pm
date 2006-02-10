package EnsEMBL::Web::Document::Common;

use strict;
use EnsEMBL::Web::Document::Page;
use EnsEMBL::Web::DBSQL::NewsAdaptor;

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
  ## GeneSliceView AlignSliceView
  $scriptname =~ s/(slice)/ucfirst($1)/eg;
  ## SNPView GeneSNPView
  $scriptname =~ s/(snp)/uc($1)/ieg;
  ## LDView LDTableVies
  $scriptname =~ s/(Ld.)/uc($1)/eg;
  ## MultiContigView, GeneSpliceView
  $scriptname =~ s/(Gene|Multi|Transcript)(.)/$1.uc($2)/eg;
  return $scriptname;
}

sub _basic_HTML {
  my $self = shift;
## Main document attributes...
  $self->set_doc_type( 'XHTML', '1.0 Trans' );
  $self->_init();
  $self->add_body_attr();
#  --- Stylesheets
  $self->stylesheet->add_sheet( 'all',    $self->species_defs->ENSEMBL_TMPL_CSS );
  $self->stylesheet->add_sheet( 'all',    $self->species_defs->ENSEMBL_PAGE_CSS );
  $self->stylesheet->add_sheet( 'print', '/css/printer-styles.css' );
  $self->stylesheet->add_sheet( 'screen', '/css/screen-styles.css' );
}

sub _common_HTML {
  my $self = shift;
## Main document attributes...
  $self->set_doc_type( 'XHTML', '1.0 Trans' );
  $self->_init();
  $self->add_body_attr( 'id' => 'ensembl-webpage' );
#  --- Stylesheets
  $self->stylesheet->add_sheet( 'all',    $self->species_defs->ENSEMBL_TMPL_CSS );
  $self->stylesheet->add_sheet( 'all',    $self->species_defs->ENSEMBL_PAGE_CSS );
  $self->stylesheet->add_sheet( 'print', '/css/printer-styles.css' );
  $self->stylesheet->add_sheet( 'screen', '/css/screen-styles.css' );

## Set up the version information etc for the title of the page, masthead etc

#  --- The release bar...
  $self->release->site_name       = $self->species_defs->ENSEMBL_SITE_NAME;
  $self->release->version         = $self->species_defs->ENSEMBL_VERSION;
  (my $DATE = $self->species_defs->ARCHIVE_VERSION ) =~ s/(\d+)/ \1/g;
  $self->release->date            = $DATE;
#  --- The masthead
  my $style = $self->species_defs->ENSEMBL_STYLE;
  $self->masthead->site_name      = $self->species_defs->ENSEMBL_SITE_NAME;
  $self->masthead->sp_bio         = $self->species_defs->SPECIES_BIO_NAME;
  $self->masthead->sp_common      = $self->species_defs->SPECIES_COMMON_NAME;
  $self->masthead->logo_src       = $style->{'SITE_LOGO'};
  $self->masthead->logo_w         = $style->{'SITE_LOGO_WIDTH'};
  $self->masthead->logo_h         = $style->{'SITE_LOGO_HEIGHT'};

#  --- The sidebar
  $self->menu->site_name          = $self->species_defs->ENSEMBL_SITE_NAME;
  $self->menu->archive            = $self->species_defs->ARCHIVE_VERSION;
  foreach my $key ( @{$style->{'ADDITIONAL_LOGOS'}||[]} ) {
    $self->menu->push_logo(
      map { $_ => $style->{$key.uc("_$_")}||'' } qw(src href width height alt href)
    );
  }
}

sub _script_HTML {
  my( $self ) = @_;
  my $scriptname = $self->script_name;
     $self->masthead->sub_title = $scriptname;
  #  --- And the title!
  $self->title->set( $scriptname );
}

sub mini_ad {
  my $self = shift;
                                                                                
  my $db = $self->species_defs->databases->{'ENSEMBL_WEBSITE'};
  my $wa = EnsEMBL::Web::DBSQL::NewsAdaptor->new($db);
  my $miniad = $wa->fetch_random_ad;
                                                                                
  my $html = '';
                                                                                
  if( $miniad ) {
    my $image  = $$miniad{'image'};
    my $url    = $$miniad{'url'};
    my $alt    = $$miniad{'alt'};
    $html = qq(\n<a href="$url"><img style="padding:15px 0px 0px 15px" src="/img/mini-ads/$image" alt="$alt" title="$alt" /></a>);
  }
  return $html;
}


1;
