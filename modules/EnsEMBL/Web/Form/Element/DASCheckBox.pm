package EnsEMBL::Web::Form::Element::DASCheckBox;

use strict;

use base qw( EnsEMBL::Web::Form::Element::CheckBox);

my $DAS_DESC_WIDTH = 120;

sub new {
  my $class = shift;
  my %params = @_;
  $params{'long_label'} ||= 1;
  $params{'name'}       ||= 'dsn';
  $params{'value'}      ||= $params{'das'}->logic_name;
  $params{'label'}      ||= $params{'das'}->label;
  $params{'bg'}         ||= 'bg1';
  my $self = $class->SUPER::new( %params );
  $self->checked  = $params{'checked'};
  $self->disabled = $params{'disabled'};
  $self->_short_das_desc( $params{'das'} );
  return $self;
}

sub _short_das_desc {
  my ($self, $source ) = @_;
  my $desc = $source->description;
  if (length $desc > $DAS_DESC_WIDTH) {
    $self->{'comment'} = $desc;
    $desc = substr $desc, 0, $DAS_DESC_WIDTH;
    $desc =~ s/\s[a-zA-Z0-9]+$/ \.\.\./; # replace final space with " ..."
  }
  $self->{'notes'} = CGI::escapeHTML($desc);
  $self->{'notes'} .= sprintf ' [<a href="%s">Homepage</a>]', $source->homepage if $source->homepage;
}

sub render {
  my $self   = shift;
  my $layout = shift;
  $layout eq 'table' || die 'DASCheckbox can only be rendered in table layout';
  
  my $notes = $self->notes;
  $notes .= sprintf(' (<span title="%s">Mouseover&#160;for&#160;full&#160;text</span>)', CGI::escapeHTML($self->comment)) if $self->comment;
  
  ## This assumes that DASCheckBox layout uses the 'table' option!
  my $label = $self->{'raw'} ? $self->label : '<strong>'.CGI::escapeHTML( $self->label ).'</strong>';
  $label .= '<br />'.$notes if $notes;
  my $widget = sprintf('<input type="checkbox" name="%s" id="%s" value="%s" class="input-checkbox"%s%s/>',
      CGI::escapeHTML( $self->name ), 
      CGI::escapeHTML( $self->id ),
      $self->value || 'yes',
      $self->checked ? ' checked="checked" ' : '',
      $self->disabled ? ' disabled="disabled" ' : '',
  );
  return {'label' => $label, 'widget' => $widget};
}


1;
