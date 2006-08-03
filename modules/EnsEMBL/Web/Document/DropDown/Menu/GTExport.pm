package EnsEMBL::Web::Document::DropDown::Menu::GTExport;

use strict;
use EnsEMBL::Web::Document::DropDown::Menu;
our @ISA =qw( EnsEMBL::Web::Document::DropDown::Menu );

sub new {
  my $class = shift;
  my $self = $class->SUPER::new(
    @_, ## This contains the menu containers as the first element
    'image_name'  => 'y-exportas',
    'image_width' => 58,
    'alt'         => 'Export data'
  );

  my $object = $self->{'object'} or return;

  my $alignURL = sprintf ("/%s/alignview?class=GeneTree;gene=%s", $self->{species}, $object->stable_id);

  my $exports = { 
      clustal  => { text  => 'Alignment Dump',
		  url   => "$alignURL;format=clustalw",
		  avail => 1 },
  };

  foreach( qw(pdf svg postscript) ) {
      $self->add_checkbox( "format_$_", "Include @{[uc($_)]} links" );
  }
  foreach( keys %{$exports} ){
      if( $exports->{$_}->{avail} ){
	  $self->add_link( $exports->{$_}->{'text'}, $exports->{$_}->{'url'} );
      }
  }

  return $self;
}

1;
