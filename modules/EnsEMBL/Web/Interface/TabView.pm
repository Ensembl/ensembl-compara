package EnsEMBL::Web::Interface::TabView;

use strict;
use warnings;
use CGI;

{

my %Tabs_of;
my %Name_of;
my %Width_of;

sub new {
  ### c
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  if (defined $params{tabs}) {
    $self->tabs($params{tabs});
  } else {
    $Tabs_of{$self} = [];
  }
  $Name_of{$self}   = defined $params{name} ? $params{name} : "";
  $Width_of{$self}   = defined $params{width} ? $params{width} : 0;
  return $self;
}

sub tabs {
  ### a
  my $self = shift;
  if (@_) {
    my $tabs = shift;
    foreach my $tab (@{ $tabs }) {
      if ($tab) {
        push @{ $Tabs_of{$self} }, $tab;
      }
    }
  }
  return $Tabs_of{$self};
}

sub name {
  ### a
  my $self = shift;
  $Name_of{$self} = shift if @_;
  return $Name_of{$self};
}

sub width {
  ### a
  my $self = shift;
  $Width_of{$self} = shift if @_;
  return $Width_of{$self};
}

sub render {
  my ($self) = @_;
  my $cgi = new CGI;

  my @tabs = @{ $self->tabs };

  my $open = $tabs[0]->name;

  if ($cgi->param('tab')) {
    $open = $cgi->param('tab');
  }

  my $name = $self->name;
  my $fixed_width = $self->width;
  my $full_width = 80;
  my $tab_width = int(80 / ($#tabs + 1));
  my $html = $self->render_javascript;
  $html .= '<div class="box_tabs"';
  if ($fixed_width) {
    $html .= 'style="width:' . $fixed_width . 'px;"';
  }
  $html .= ">\n";
  foreach my $tab (@tabs) {
    my $class = "tab";
    if ($tab->name eq $open) {
      $class = 'tab selected';
    }
    $html .= "<div class='$class' id='" . $tab->name . "_tab' style='width: $tab_width%;'><a href='javascript:void(0);' onClick='" . $name . "_switch_tab(\"" . $tab->name . "\");'>" . $tab->label . "</a></div>";
  }

  $html .= "<br clear='all' />\n";
  $html .= "<div class='tab_content'>\n";
  
  foreach my $tab (@tabs) {
    my $style = "style='display: none;'";
    if ($tab->name eq $open) {
      $style = "";
    } 
    $html .= "<div class='tab_content_panel' " . $style . " id='" . $tab->name . "'>\n";
    $html .= $tab->content;
    $html .= "</div>\n";
  }

  $html .= "</div>\n";
  $html .= "</div>\n";
} 

sub render_javascript {
  my ($self) = @_;
  my $html = "";
  my $list = "'";
  my $name = $self->name;
  foreach my $tab (@{ $self->tabs }) {
    $list .= $tab->name . "','";
  }
  $list =~ s/,'$//;
  $html .= "<script type='text/javascript'>\n\n";

  $html .= "var " . $name . "_tabs = [ $list ]\n";

  $html .= "function " . $name . "_switch_tab(element) {\n";
  $html .= $name . "_reset_tabs();\n";
  $html .= "document.getElementById(element + \"_tab\").className = \"tab selected\";\n";
  $html .= "document.getElementById(element).style.display = \"block\";\n";
  $html .= "}\n";

  $html .= "function " . $name . "_reset_tabs() {\n";
  $html .= "for (var n = 0; n < " . $name . "_tabs.length; n++) {\n";
  $html .= "  document.getElementById(" . $name . "_tabs[n] + \"_tab\").className = \"tab\";\n";
  $html .= "document.getElementById(" . $name . "_tabs[n]).style.display = \"none\"\n";
  $html .= "}\n";
  $html .= "}\n";

  $html .= "</script>\n\n";

}

sub DESTROY {
  ### d
  my ($self) = shift;
  delete $Tabs_of{$self};
  delete $Name_of{$self};
  delete $Width_of{$self};
}

}

1;
