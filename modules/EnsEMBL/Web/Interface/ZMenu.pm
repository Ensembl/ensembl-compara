package EnsEMBL::Web::Interface::ZMenu;

use strict;
use warnings;

use EnsEMBL::Web::Interface::ZMenuView;
use EnsEMBL::Web::Interface::ZMenuItem::Placeholder;
use EnsEMBL::Web::Interface::ZMenuItem::Text;

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
  $self->add_content(EnsEMBL::Web::Interface::ZMenuItem::Placeholder->new( ( name => 'placeholder', text => 'Loading...' ) ));
  return $self; 
} 

sub populate {
  ### Default population method. Each menu type is initialised by a call to {{populate}} in the appropriate ZMenu subclass (for example {{EnsEMBL::Web::Interface::ZMenu::ensembl_transcript::populate}}. Subclasses should implement this method to appropriately setup the menu for display. This empty method is in place for safe failover.
  my $self = shift;
  $self->remove_placeholder;
}

sub linkage {
  ### Returns the linkage view of the zmenu. In essence, this sends a linkage method request to the zmenu view object, which by default is an instance of {{EnsEMBL::Web::Interface::ZmenuView}}. You can replace this if you want to change the output behaviour of the zmenu.
  my $self = shift;
  return $self->view->ajax_linkage;
}

sub overview {
  ### Returns a simple string overview of the text menu, useful for debugging. The string format is controlled by the zmenu's view object, which be default is an instance of {{EnsEMBL::Web::Inferface::ZmenuView}}.
  my $self = shift;
  return $self->view->text;
}

sub json {
  ### Returns a representation of the ZMenu as a JSON string. Used for asynchronous calls. This method returns the same as {{EnsEMBL::Web::Interface::ZMenuView::json}, but without the escaped quotes. 
  my $self = shift;
  my $json = $self->view->json;
  $json =~ s/\\'/"/g;
  return $json;
}

sub add_content {
  ### Adds a new content row to the zmenu. Accepts an object of the {{EnsEMBL::Web::Interface::ZMenuItem}} family. 
  my ($self, $content) = @_;
  push @{ $self->content }, $content;
}

sub remove_content_with_name {
  my ($self, $name) = @_;
  my @removal = ();
  my $count = 0;
  foreach my $content (@{ $self->content }) {
    if ($content->name eq $name) {
      push @removal, $count;
    }
    $count++; 
  }

  foreach my $index (@removal) {
    my $rem = splice(@{ $self->content }, $index, 1);
  }
}

sub remove_placeholder {
  my $self = shift;
  $self->remove_content_with_name('placeholder');
}

sub add_text {
  ### Adds a new text row to the zmenu.
  my ($self, $name, $text) = @_;
  $self->add_content(EnsEMBL::Web::Interface::ZMenuItem::Text->new( (text => $text, name => $name)) );
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
