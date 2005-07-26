package EnsEMBL::Web::Document::DropDown::Menu::SNPHelp;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub help_link {
  my $self = shift;
  my( $kw, $se ) = @_;
  my $LINK = (defined $se ? "se=$se&" : "")."kw=$kw";
  return qq(javascript:X=window.open('/$self->{'species'}/helpview?$LINK','helpview','height=400,width=500,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes');X.focus();void(0));
}

sub new {
  my $class  = shift;
  my $self = $class->SUPER::new( 
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-help',
    'image_width' => 48,
    'alt'         => 'Help'
  ); 
  $self->add_link( 'GeneSNPView', $self->help_link('genesnpview',1), '' );
  return $self;
}

1;
