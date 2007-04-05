package EnsEMBL::Web::Commander::Node;

use strict;
use warnings;

use CGI qw(escapeHTML);;
use EnsEMBL::Web::Root;
use EnsEMBL::Web::Form::Element::RadioButton;

{

my %Title_of;
my %Name_of;
my %Object_of;
my %Elements_of;
my %TextAbove_of;
my %TextBelow_of;

sub new {
  ### c
  ### Creates a new inside-out Node object. These objects are linked
  ### togeter to form a wizard interface controlled by the 
  ### {{EnsEMBL::Web::Commander}} class.
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Title_of{$self} = defined $params{title} ? $params{title} : "Node";
  $Name_of{$self} = defined $params{name} ? $params{name} : "Node";
  $Object_of{$self} = defined $params{object} ? $params{object} : undef;
  $Elements_of{$self} = defined $params{elements} ? $params{elements} : [];
  $TextAbove_of{$self} = defined $params{text_above} ? $params{text_above} : '';
  $TextBelow_of{$self} = defined $params{text_below} ? $params{text_below} : '';
  return $self;
}

sub render {
  my ($self, %parameters) = @_;
  my $html = "";

  foreach my $element (@{ $self->elements }) {
    my ($output, $style);
    if ($element->type eq 'Hidden') {
      $element->render();
      next;
    }

    $style = 'formblock';
    if( $element->spanning eq 'yes' ) {
      $style = 'formwide';
    } elsif( $element->spanning eq 'center' ) {
      $style = 'formcenter';
    } elsif( $element->spanning eq 'inline' ) {
      $style = 'forminline';
    }
    if( $element->hidden_label ) {
      $output = sprintf qq(<div class="formpadding">
    <div class="hidden"><label for="%s">%s</label</div>
  </div>), $element->id, ( $element->label eq '' ? "&nbsp;" : CGI::escapeHTML($element->label) )
    } elsif( $element->label ne '' ) {
      if( $element->comment ) {
        $output = sprintf qq(
          <h6><label for="%s">%s<br><span style="color: #333; font-weight: normal;">%s<br /><br /></span></label></h6>),
          $element->id, CGI::escapeHTML($element->label), CGI::escapeHTML($element->comment);
      } else {
        $output = sprintf qq(
          <h6><label for="%s">%s</label></h6>),
          $element->id, CGI::escapeHTML($element->label);
      }
    } elsif( $style eq 'formblock' ) {
      $output = qq(
        <div class=\"formpadding\"></div>);;
    }
    $html .= qq(
      <div class="$style">$output
        <div class="formcontent">
        ).$element->render().qq(
        </div>
      </div>);
  }
  return $html;
}

sub add_option {
  my ($self, %params) = @_;
  my $element = EnsEMBL::Web::Form::Element::RadioButton->new();
  $element->value = $params{value};
  $element->name = $params{name};
  $element->id = $params{name} . "_" . $params{value};
  $element->introduction = $params{label};
  if ($params{selected}) {
    $element->checked = 1;
  }
  $self->add_element($element); 
}

sub add_element {
  my( $self, %options ) = @_;
  my $module = "EnsEMBL::Web::Form::Element::$options{'type'}";

  if( EnsEMBL::Web::Root::dynamic_use(undef, $module ) ) {
    push @{ $self->elements }, $module->new( 'form' => 'connection_form', %options );
  }
  else {
    warn "Unable to dynamically use module $module. Have you spelt the element type correctly?";
  }
}

## accessors

sub title {
  ### a
  my $self = shift;
  $Title_of{$self} = shift if @_;
  return $Title_of{$self};
}

sub name {
  ### a
  my $self = shift;
  $Name_of{$self} = shift if @_;
  return $Name_of{$self};
}

sub object {
  ### a
  my $self = shift;
  $Object_of{$self} = shift if @_;
  return $Object_of{$self};
}

sub elements {
  ### a
  my $self = shift;
  $Elements_of{$self} = shift if @_;
  return $Elements_of{$self};
}

sub text_above {
  ### a
  my $self = shift;
  $TextAbove_of{$self} = shift if @_;
  return $TextAbove_of{$self};
}

sub text_below {
  ### a
  my $self = shift;
  $TextBelow_of{$self} = shift if @_;
  return $TextBelow_of{$self};
}

sub is_final {
  return 0;
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Title_of{$self};
  delete $Elements_of{$self};
  delete $Name_of{$self};
  delete $Object_of{$self};
  delete $TextAbove_of{$self};
  delete $TextBelow_of{$self};
}

}

1;
