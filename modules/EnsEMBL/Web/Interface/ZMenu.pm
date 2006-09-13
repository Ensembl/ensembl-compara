package EnsEMBL::Web::Interface::ZMenu;

use strict;
use warnings;

use EnsEMBL::Web::Interface::ZMenuView;

{

my %Title_of;
my %Type_of;
my %Ident_of;
my %Content_of;
my %View_of;

sub new {
  ### c
  ### Inside-out class for z-menus.
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Title_of{$self}   = defined $params{title} ? $params{title} : "";
  $Type_of{$self}    = defined $params{type} ? $params{type} : "";
  $Ident_of{$self}   = defined $params{ident} ? $params{ident} : "";
  $Content_of{$self} = defined $params{content} ? $params{conent} : [];
  $View_of{$self} = defined $params{view} ? $params{view} : new EnsEMBL::Web::Interface::ZMenuView->new( ( zmenu => $self ) );
  return $self; 
} 

sub linkage {
  ### Returns the linkage view of the zmenu. In essence, this sends a linkage method request to the zmenu view object, which by default is an instance of {{EnsEMBL::Web::Interface::ZmenuView}}. You can replace this if you want to change the output behaviour of the zmenu.
  my $self = shift;
  return $self->view->linkage;
}

sub overview {
  ### Returns a simple string overview of the text menu, useful for debugging. The string format is controlled by the zmenu's view object, which be default is an instance of {{EnsEMBL::Web::Inferface::ZmenuView}}.
  my $self = shift;
  return $self->view->text;
}

sub add_content {
  ### Adds a new content row to the zmenu. Accepts a hash ref.
  my ($self, $content) = @_;
  push @{ $self->content }, $content;
}

sub add_text {
  ### Adds a new text row to the zmenu.
  my ($self, $content) = @_;
  $content->{type} = 'text';
  $self->add_content($content);
}

sub size {
  ### Returns the number of content rows. 
  my $self = shift;
  my @array = @{ $self->content };
  return ($#array + 1); 
}

sub title {
  ### a
  my $self = shift;
  $Title_of{$self} = shift if @_;
  return $Title_of{$self};
}

sub view {
  ### a
  my $self = shift;
  $View_of{$self} = shift if @_;
  return $View_of{$self};
}

sub type {
  ### a
  my $self = shift;
  $Type_of{$self} = shift if @_;
  return $Type_of{$self};
}

sub ident {
  ### a
  my $self = shift;
  $Ident_of{$self} = shift if @_;
  return $Ident_of{$self};
}

sub content_with_name {
  ### Retrieves a slice of the content hash by name.
  my ($self, $name) = @_;
  my $hash;
  foreach my $content (@{ $self->content }) {
    if ($content->{name} && $content->{name} eq $name) {
      $hash = $content;
    } 
  }
  return $hash;
}

sub content {
  ### a
  my $self = shift;
  $Content_of{$self} = shift if @_;
  return $Content_of{$self};
}

sub DESTROY {
  ### d
  my ($self) = shift;
  delete $Title_of{$self};
  delete $Type_of{$self};
  delete $Ident_of{$self};
  delete $Content_of{$self};
  delete $View_of{$self};
}

}

1
