package EnsEMBL::Web::Document::HTML::View;

use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

{

my %InForm_of;

sub new    { 
  my ($class, %params) = @_;
  my $self = shift->SUPER::new( 'html' => '' );
  $InForm_of{$self}          = defined $params{in_form} ? $params{in_form} : 0;
  return $self;
}

sub render { 
  my ($self, $page) = @_;
  $self->render_html_header;
  if (!$page) {
    $self->render_error_page;
  } else {
    $self->render_page($page);
  }
  $self->render_html_footer;
}

sub render_page {
  my ($self, $page) = @_;
  $self->print_title($page->title);
  foreach my $element (@{ $page->page_elements }) {
    my $type = "render_" . $element->{type};
    $self->$type($element);
    $self->print_linebreak;
  }

  my @form_elements = @{ $page->form_elements };

  $self->print_form_header($page);

  foreach my $field (@form_elements) {
    $self->render_field( $page->definition_for_data_field($field->{name}), $page );
    $self->print_linebreak;
  }

  $self->render_submit_button;
}

sub render_field {
  my ($self, $field, $page) = @_;
  my $type = $field->{'Type'};
  if ($type =~ /varchar/) {
    $self->render_textfield($field, $page);
  } elsif ($type =~ /text/) {
    $self->render_textarea($field, $page);
  } elsif ($type =~ /enum/) {
    $self->render_options($field, $page);
  }
}

sub render_textfield {
  my ($self, $field, $page) = @_;
  my $field_name = $field->{'Field'};
  my ($field_size) = $field->{'Type'} =~ m/\((.*)\)/;
  my $value = "";
  $self->print($page->label_for_form_element($field_name) . ":\n<br />\n");
  if ($page->value_for_form_element($field_name)) {
    $value = "value='" . $page->value_for_form_element($field_name) . "'";
  }
  $self->print('<input type="text" name="' . $field_name . '" ' . $value . ' maxlength="' . $field_size . '"/>' . "\n");
}

sub render_options {
  my ($self, $field, $page) = @_;
  my $field_name = $field->{'Field'};
  my $option_string = $field->{'Type'};
  $option_string =~ s/enum|\(|\)|'//g;
  $self->print($page->label_for_form_element($field_name) . ":\n<br /><br />\n");
  my %settings = %{ $page->options_for_form_element($field_name) };
  my @options = split(/,/, $option_string); 
  foreach my $option (@options) {
    my $selected = "";
    my $value = $option;
    if ($settings{values}->{$option}) {
      $value = $settings{values}->{$option};
    }
    $self->print("<input type='radio' name='" . $field_name. "' value='" . $value. "'");
    if ($page->value_for_form_element($field_name)) {
      if ($page->value_for_form_element($field_name) eq $option) {
        $self->print(" checked='yes' ");
      }
    } else {
      if ($option eq $field->{'Default'} ) {
        $self->print(" checked='yes' ");
      }
    }
    $self->print(" /> ");
    if ($settings{labels}->{$option}) {
      $self->print(ucfirst($settings{labels}->{$option}));
    } else {
      $self->print(ucfirst($option));
    }
    $self->print("<br />");
  }
}

sub render_textarea {
  my ($self, $field, $page) = @_;
  my $field_name = $field->{'Field'};
  $self->print($page->label_for_form_element($field_name) . ":\n<br />\n");
  $self->print('<textarea name="' . $field_name .'">');
  if ($page->value_for_form_element($field_name)) {
    $self->print($page->value_for_form_element($field_name));
  }
  $self->print('</textarea>');
}

sub render_text {
  my ($self, $element) = @_;
  $self->print($element->{label});
}

sub render_submit_button {
  my $self = shift;
  $self->print('<input type="submit" value="Submit" class="red-button" />' . "\n");
}

sub render_error_page {
  my $self = shift;
  $self->print('<h2>Error rendering DataView</h2>Missing definitions'); 
}

sub render_html_header {
  my $self = shift;
  $self->print('<div id="page"><div id="i1"><div id="i2"><div class="sptop">&nbsp;</div>' . "\n");
}

sub render_html_footer {
  my $self = shift;
  $self->print_form_footer;
  $self->print('<hr /><div id="popups"></div>' . "\n"); 
  $self->print('<div class="sp">&nbsp;</div></div></div></div>');
}

sub print_title {
  my ($self, $title) = @_;
  $self->print('<h2>' . $title . '</h2>');
}

sub print_linebreak {
  my $self = shift;
  $self->print('<br /><br />');
}

sub print_form_header {
  my ($self, $page) = @_;
  my $user_id = $ENV{'ENSEMBL_USER_ID'};
  my $id = CGI->new()->param('id');
  $self->print('<form method="POST"><ul>' . "\n");
  $self->print('<input type="hidden" name="action" value="' . $page->action . '" />'. "\n");

  if ($id) {
    $self->print('<input type="hidden" name="id" value="' . $id . '" />'. "\n");
  }

  if ($user_id) {
    $self->print('<input type="hidden" name="user_id" value="' . $user_id . '" />'. "\n");
  }

  if ($page->configuration_elements) {
    foreach my $element (@{ $page->configuration_elements }) {
      $self->print('<input type="hidden" name="' . $element->{key} . '" value="' . $element->{value} . '" />'. "\n");
    }
  }
}

sub print_form_footer {
  my $self = shift;
  $self->print('</ul></form>' . "\n");
}

sub in_form {
  ### a
  my $self = shift;
  $InForm_of{$self} = shift if @_;
  return $InForm_of{$self};
}

sub DESTROY {
  my $self = shift;
  delete $InForm_of{$self};
}

}

1;
