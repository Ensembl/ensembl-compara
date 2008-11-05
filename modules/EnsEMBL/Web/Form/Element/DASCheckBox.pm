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
  my $self = $class->SUPER::new( %params );
  $self->checked = $params{'checked'};
  $self->{'class'} = $params{'long_label'} ? 'checkbox-long' : '';
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
  $self->{'notes'} = $desc;
}

sub render {
  my $self = shift;
  my $notes = '';
  if ($self->notes) {
    $notes = ' <div style="font-weight:normal">'.CGI::escapeHTML($self->notes);
    $notes .= sprintf(' (<span title="%s">Mouseover&#160;for&#160;full&#160;text</span>)', CGI::escapeHTML($self->comment)) if $self->comment;
    $notes .= '</div>';
  }
  else {
    $notes = ' <div style="font-weight:normal">&#160;</div>'; ## Empty div to avoid uneven rendering
  }
  return sprintf(
    qq(
  <dl>
    <dt%s>
      <label>%s%s</label>
    </dt>
    <dd%s>
      <input type="checkbox" name="%s" id="%s" value="%s" class="input-checkbox" %s/>
    </dd>
  </dl>),
    $self->{'class'} ? ' class="'.$self->{'class'}.'"' : '',
    $self->{'raw'} ? $self->label : CGI::escapeHTML( $self->label ),
    $notes,
    $self->{'class'} ? ' class="'.$self->{'class'}.'"' : '',
    CGI::escapeHTML( $self->name ),
    CGI::escapeHTML( $self->id ),
    $self->value || 'yes', $self->checked ? 'checked="checked" ' : '',
  );
}


1;
