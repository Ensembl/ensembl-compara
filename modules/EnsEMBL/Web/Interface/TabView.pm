package EnsEMBL::Web::Interface::TabView;

use strict;
use warnings;

{

my %Tabs_of;

sub new {
  ### c
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Tabs_of{$self}   = defined $params{tabs} ? $params{tabs} : [];
  return $self;
}

sub tabs {
  ### a
  my $self = shift;
  $Tabs_of{$self} = shift if @_;
  return $Tabs_of{$self};
}

sub render {
  my ($self, $user) = @_;

  my @tabs = @{ $self->tabs };

  my $full_width = 80;
  my $tab_width = 80 / ($#tabs + 1);
  my $html = $self->render_javascript;
  $html .= "<div class='box_tabs'>\n";
  my $class = "tab selected"; 
  foreach my $tab (@tabs) {
    $html .= "<div class='$class' id='" . $tab->name . "_tab' style='width: $tab_width%;'><a href='javascript:void(0);' onClick='switch_tab(\"" . $tab->name . "\");'>" . $tab->label . "</a></div>";
    $class = "tab";
  }

  $html .= "<br clear='all' />\n";
  $html .= "<div class='tab_content'>\n";
  
  my $style = "";
  foreach my $tab (@tabs) {
    $html .= "<div class='tab_content_panel' " . $style . " id='" . $tab->name . "'>\n";
    $html .= $tab->content;
    $html .= "</div>\n";
    $style = "style='display: none;'";
  }

  $html .= "</div>\n";
  $html .= "</div>\n";
} 

sub render_javascript {
  my ($self) = @_;
  my $html = "";
  my $list = "'";
  foreach my $tab (@{ $self->tabs }) {
    $list .= $tab->name . "','";
  }
  $list =~ s/,'$//;
  $html .= "<script type='text/javascript'>\n\n";

  $html .= "var tabs = [ $list ]\n";

  $html .= "function switch_tab(element) {\n";
  $html .= "reset_tabs();\n";
  $html .= "document.getElementById(element + \"_tab\").className = \"tab selected\";\n";
  $html .= "document.getElementById(element).style.display = \"block\";\n";
  $html .= "}\n";

  $html .= "function reset_tabs() {\n";
  $html .= "for (var n = 0; n < tabs.length; n++) {\n";
  $html .= "  document.getElementById(tabs[n] + \"_tab\").className = \"tab\";\n";
  $html .= "document.getElementById(tabs[n]).style.display = \"none\"\n";
  $html .= "}\n";
  $html .= "}\n";

  $html .= "</script>\n\n";

}

sub DESTROY {
  ### d
  my ($self) = shift;
  delete $Tabs_of{$self};
}

}

1;
