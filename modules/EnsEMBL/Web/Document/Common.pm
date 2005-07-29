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
  $scriptname =~ s/(slice)/ucfirst($1)/eg;
  $scriptname =~ s/(snp)/uc($1)/ieg;
  $scriptname =~ s/(Ld)/uc($1)/eg;
  $scriptname =~ s/(Gene|Multi)(.)/$1.uc($2)/eg;
  return $scriptname;
}

sub _common_HTML {
  my $self = shift;
## Main document attributes...
  $self->set_doc_type( 'XHTML', '1.0 Trans' );
  $self->_init();
  $self->add_body_attr( 'id' => 'ensembl-webpage' );
#  --- Stylesheets
  $self->stylesheet->add_sheet( 'all', $self->species_defs->ENSEMBL_TMPL_CSS );
  $self->stylesheet->add_sheet( 'all', $self->species_defs->ENSEMBL_PAGE_CSS );
  $self->stylesheet->add_sheet( 'print', '/css/printer-styles.css' );
  $self->stylesheet->add_sheet( 'screen', '/css/screen-styles.css' );

## Set up the version information etc for the title of the page, masthead etc

#  --- The release bar...
  $self->release->site_name = $self->species_defs->ENSEMBL_SITE_NAME;
  $self->release->version   = $self->species_defs->ENSEMBL_VERSION;
  (my $DATE = $self->species_defs->ARCHIVE_VERSION ) =~ s/(\d+)/ \1/g;
  $self->release->date      = $DATE;
#  --- The masthead
  $self->masthead->site_name = $self->species_defs->ENSEMBL_SITE_NAME;
  $self->masthead->sp_bio    = $self->species_defs->SPECIES_BIO_NAME;
  $self->masthead->sp_common = $self->species_defs->SPECIES_COMMON_NAME;
  $self->masthead->logo_src  = $self->species_defs->SITE_LOGO;
  $self->masthead->logo_w    = $self->species_defs->SITE_LOGO_WIDTH;
  $self->masthead->logo_h    = $self->species_defs->SITE_LOGO_HEIGHT;

#  --- The sidebar
  $self->menu->site_name          = $self->species_defs->ENSEMBL_SITE_NAME;
  $self->menu->archive            = $self->species_defs->ARCHIVE_VERSION;
  $self->menu->inst_logo          = $self->species_defs->INSTITUTE_LOGO;
  $self->menu->inst_logo_href     = $self->species_defs->INSTITUTE_LOGO_HREF;
  $self->menu->inst_logo_alt      = $self->species_defs->INSTITUTE_LOGO_ALT;
  $self->menu->inst_logo_width    = $self->species_defs->INSTITUTE_LOGO_WIDTH;
  $self->menu->inst_logo_height   = $self->species_defs->INSTITUTE_LOGO_HEIGHT;
  $self->menu->collab_logo        = $self->species_defs->COLLABORATE_LOGO;
  $self->menu->collab_logo_href   = $self->species_defs->COLLABORATE_LOGO_HREF;
  $self->menu->collab_logo_alt    = $self->species_defs->COLLABORATE_LOGO_ALT;
  $self->menu->collab_logo_width  = $self->species_defs->COLLABORATE_LOGO_WIDTH;
  $self->menu->collab_logo_height = $self->species_defs->COLLABORATE_LOGO_HEIGHT;
}

sub _script_HTML {
  my( $self ) = @_;
  my $scriptname = $self->script_name;
     $self->masthead->sub_title = $scriptname;
  #  --- And the title!
  $self->title->set( $scriptname );

}
1;
