package EnsEMBL::Web::Document::Common;

use strict;
use EnsEMBL::Web::Document::Page;
use EnsEMBL::Web::SpeciesDefs;
our $SD = EnsEMBL::Web::SpeciesDefs->new();

our @ISA = qw(EnsEMBL::Web::Document::Page);

sub set_title {
  my $self  = shift;
  my $title = shift;
  $self->title->set( $SD->ENSEMBL_SITE_NAME.' v'.$SD->ENSEMBL_VERSION.': '.$SD->SPECIES_BIO_NAME.' '.$title );
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
  $self->stylesheet->add_sheet( 'all', $SD->ENSEMBL_TMPL_CSS );
  $self->stylesheet->add_sheet( 'all', $SD->ENSEMBL_PAGE_CSS );
  $self->stylesheet->add_sheet( 'print', '/css/printer-styles.css' );

## Set up the version information etc for the title of the page, masthead etc

#  --- The release bar...
  $self->release->site_name = $SD->ENSEMBL_SITE_NAME;
  $self->release->version   = $SD->ENSEMBL_VERSION;
  (my $DATE = $SD->ARCHIVE_VERSION ) =~ s/(\d+)/ \1/g;
  $self->release->date      = $DATE;
#  --- The masthead
  $self->masthead->site_name = $SD->ENSEMBL_SITE_NAME;
  $self->masthead->sp_bio    = $SD->SPECIES_BIO_NAME;
  $self->masthead->sp_common = $SD->SPECIES_COMMON_NAME;
  $self->masthead->logo_src  = $SD->SITE_LOGO;
  $self->masthead->logo_w    = $SD->SITE_LOGO_WIDTH;
  $self->masthead->logo_h    = $SD->SITE_LOGO_HEIGHT;

#  --- The sidebar
  $self->menu->site_name          = $SD->ENSEMBL_SITE_NAME;
  $self->menu->archive            = $SD->ARCHIVE_VERSION;
  $self->menu->inst_logo          = $SD->INSTITUTE_LOGO;
  $self->menu->inst_logo_href     = $SD->INSTITUTE_LOGO_HREF;
  $self->menu->inst_logo_alt      = $SD->INSTITUTE_LOGO_ALT;
  $self->menu->inst_logo_width    = $SD->INSTITUTE_LOGO_WIDTH;
  $self->menu->inst_logo_height   = $SD->INSTITUTE_LOGO_HEIGHT;
  $self->menu->collab_logo        = $SD->COLLABORATE_LOGO;
  $self->menu->collab_logo_href   = $SD->COLLABORATE_LOGO_HREF;
  $self->menu->collab_logo_alt    = $SD->COLLABORATE_LOGO_ALT;
  $self->menu->collab_logo_width  = $SD->COLLABORATE_LOGO_WIDTH;
  $self->menu->collab_logo_height = $SD->COLLABORATE_LOGO_HEIGHT;
}

sub _script_HTML {
  my( $self ) = @_;
  my $scriptname = $self->script_name;
     $self->masthead->sub_title = $scriptname;
  #  --- And the title!
  $self->title->set( $scriptname );

}
1;
