package EnsEMBL::Web::Document::DropDown::Menu::Help;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );


sub help_link {
  my $self = shift;
  my( $kw, $se ) = @_;
  my $LINK = (defined $se ? "se=$se&" : "")."kw=$kw";
  return qq(javascript:X=window.open('/$self->{'species'}/helpview?$LINK','helpview','height=500,width=770,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes');X.focus();void(0));
}

sub new {
  my $class  = shift;
  my $self = $class->SUPER::new( 
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-help',
    'image_width' => 48,
    'alt'         => 'Help'
  ); 
  $self->add_link( 'Configuring', $self->help_link('contigview#pull_down',1), '' );
  $self->add_link( 'DAS sources', $self->help_link('dassources',1),           '' );
  $self->add_link( 'General',     $self->help_link($self->{'script'},1),      '' );
  $self->add_link( 'Helpdesk',    "javascript:void(window.open('/$self->{'species'}/helpview?kw=contigview;se=1','helpview','width=700,height=550,resizable,scrollbars'))", '' );
  return $self;
}

1;
